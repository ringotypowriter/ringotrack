#include <atomic>
#include <cstdint>
#include <windows.h>
#include <dwmapi.h>

// 简单的前台窗口信息结构，用于 Dart FFI 映射。
struct RtForegroundAppInfo {
  std::uint64_t timestamp_millis;  // 自 Unix epoch 起的毫秒数（本机时间）
  std::uint32_t pid;               // 进程 ID
  std::int32_t is_error;           // 1 表示存在错误信息
  std::int32_t error_code;         // 具体错误码，含义见下方常量
  wchar_t exe_path[260];           // 可执行文件完整路径
  wchar_t window_title[260];       // 窗口标题
};

// 错误码约定，仅用于诊断日志，不影响基础功能
constexpr std::int32_t RT_ERR_NONE = 0;
constexpr std::int32_t RT_ERR_NO_FOREGROUND_WINDOW = 1;
constexpr std::int32_t RT_ERR_OPEN_PROCESS_FAILED = 2;
constexpr std::int32_t RT_ERR_QUERY_PATH_FAILED = 3;
constexpr std::int32_t RT_ERR_GET_WINDOW_TITLE_FAILED = 4;

namespace {

// 计算当前时间的 Unix epoch 毫秒数（本地时间）
std::uint64_t GetCurrentUnixMillis() {
  FILETIME ft;
  ::GetSystemTimeAsFileTime(&ft);

  ULARGE_INTEGER uli;
  uli.LowPart = ft.dwLowDateTime;
  uli.HighPart = ft.dwHighDateTime;

  // FILETIME: 1601-01-01 起每 100ns 一个 tick
  constexpr std::uint64_t EPOCH_DIFFERENCE = 116444736000000000ULL;
  if (uli.QuadPart < EPOCH_DIFFERENCE) {
    return 0;
  }

  const std::uint64_t ticks_since_unix_epoch = uli.QuadPart - EPOCH_DIFFERENCE;
  const std::uint64_t millis = ticks_since_unix_epoch / 10000ULL;
  return millis;
}

}  // namespace

// ------------------- 全局左键/落笔（AFK）检测 -------------------

namespace {

std::atomic<std::uint64_t> g_last_left_click_millis{0};
HHOOK g_mouse_hook = nullptr;
std::atomic<bool> g_left_button_down{false};

LRESULT CALLBACK LowLevelMouseProc(int nCode, WPARAM wParam, LPARAM lParam) {
  if (nCode == HC_ACTION) {
    if (wParam == WM_LBUTTONDOWN) {
      g_last_left_click_millis.store(GetCurrentUnixMillis(), std::memory_order_relaxed);
      g_left_button_down.store(true, std::memory_order_relaxed);
    } else if (wParam == WM_LBUTTONUP) {
      g_last_left_click_millis.store(GetCurrentUnixMillis(), std::memory_order_relaxed);
      g_left_button_down.store(false, std::memory_order_relaxed);
    }
  }
  return ::CallNextHookEx(g_mouse_hook, nCode, wParam, lParam);
}

void InstallMouseHookIfNeeded() {
  if (g_mouse_hook != nullptr) {
    return;
  }

  const HINSTANCE module_handle = ::GetModuleHandleW(nullptr);
  g_mouse_hook = ::SetWindowsHookExW(WH_MOUSE_LL, LowLevelMouseProc, module_handle, 0);

  // 初始化一次，避免 Dart 侧立即判定为 Idle
  g_last_left_click_millis.store(GetCurrentUnixMillis(), std::memory_order_relaxed);
  g_left_button_down.store(false, std::memory_order_relaxed);
}

void UninstallMouseHook() {
  if (g_mouse_hook != nullptr) {
    ::UnhookWindowsHookEx(g_mouse_hook);
    g_mouse_hook = nullptr;
  }
}

}  // namespace

extern "C" {

// 返回指向静态结构体的指针，避免 Dart 侧分配 / 释放内存的复杂度。
// 每次调用都会覆盖内部缓存的内容。
__declspec(dllexport) RtForegroundAppInfo* rt_get_foreground_app() {
  static RtForegroundAppInfo info;

  ::ZeroMemory(&info, sizeof(info));
  info.timestamp_millis = GetCurrentUnixMillis();
  info.is_error = RT_ERR_NONE;
  info.error_code = RT_ERR_NONE;

  const HWND hwnd = ::GetForegroundWindow();
  if (hwnd == nullptr) {
    info.is_error = 1;
    info.error_code = RT_ERR_NO_FOREGROUND_WINDOW;
    return &info;
  }

  DWORD pid = 0;
  ::GetWindowThreadProcessId(hwnd, &pid);
  info.pid = static_cast<std::uint32_t>(pid);

  HANDLE process = ::OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, FALSE, pid);
  if (process == nullptr) {
    info.is_error = 1;
    info.error_code = RT_ERR_OPEN_PROCESS_FAILED;
  } else {
    DWORD buffer_len = static_cast<DWORD>(sizeof(info.exe_path) / sizeof(wchar_t));
    DWORD copied_len = buffer_len;
    if (!::QueryFullProcessImageNameW(process, 0, info.exe_path, &copied_len)) {
      info.exe_path[0] = L'\0';
      info.is_error = 1;
      info.error_code = RT_ERR_QUERY_PATH_FAILED;
    }

    ::CloseHandle(process);
    process = nullptr;
  }

  // 获取窗口标题（不论是否获取到路径，都尝试）
  info.window_title[0] = L'\0';
  const int title_capacity = static_cast<int>(sizeof(info.window_title) / sizeof(wchar_t));
  const int title_len = ::GetWindowTextW(hwnd, info.window_title, title_capacity);
  if (title_len <= 0) {
    info.window_title[0] = L'\0';
    if (info.error_code == RT_ERR_NONE) {
      info.is_error = 1;
      info.error_code = RT_ERR_GET_WINDOW_TITLE_FAILED;
    }
  }

  return &info;
}

// 初始化全局鼠标钩子，用于 AFK 检测。
__declspec(dllexport) void rt_init_stroke_hook() { InstallMouseHookIfNeeded(); }

// 获取最近一次左键按下的时间（Unix 毫秒，若未初始化则返回 0）。
__declspec(dllexport) std::uint64_t rt_get_last_left_click_millis() {
  return g_last_left_click_millis.load(std::memory_order_relaxed);
}

// 左键是否按下
__declspec(dllexport) std::uint32_t rt_is_left_button_down() {
  return g_left_button_down.load(std::memory_order_relaxed) ? 1u : 0u;
}

// 可选的清理函数，当前未在 Dart 侧调用。
__declspec(dllexport) void rt_shutdown_stroke_hook() { UninstallMouseHook(); }

// ------------------- 窗口置顶 / 固定大小控制 -------------------

namespace {

std::atomic<bool> g_is_pinned{false};
HWND g_pinned_hwnd = nullptr;
WINDOWPLACEMENT g_prev_placement{};
LONG g_prev_style = 0;
LONG g_prev_ex_style = 0;

// Window attribute for controlling rounded-corner behavior on Windows 11。
#ifndef DWMWA_WINDOW_CORNER_PREFERENCE
#define DWMWA_WINDOW_CORNER_PREFERENCE 33
#endif

enum DwmWindowCornerPreference {
  DWMWCP_DEFAULT = 0,
  DWMWCP_DONOTROUND = 1,
  DWMWCP_ROUND = 2,
  DWMWCP_ROUNDSMALL = 3,
};

RECT GetWorkAreaForWindow(HWND hwnd) {
  RECT work_area{};

  // 首选系统工作区（考虑任务栏等保留区域）。
  if (SystemParametersInfoW(SPI_GETWORKAREA, 0, &work_area, 0)) {
    return work_area;
  }

  // 回退到窗口所在的监视器工作区。
  HMONITOR monitor = MonitorFromWindow(hwnd, MONITOR_DEFAULTTONEAREST);
  MONITORINFO info{};
  info.cbSize = sizeof(info);
  if (GetMonitorInfoW(monitor, &info)) {
    return info.rcWork;
  }

  // 如果连监视器信息都拿不到，就退回到当前窗口区域，
  // 让 pinned 小窗仍然相对当前窗口位置调整，而不是假设一个固定屏幕分辨率。
  if (GetWindowRect(hwnd, &work_area)) {
    return work_area;
  }

  // 最后的兜底：使用与应用默认窗口一致的区域大小（1280x720）。
  work_area.left = 0;
  work_area.top = 0;
  work_area.right = 1280;
  work_area.bottom = 720;
  return work_area;
}

bool EnsureWindowHandle() {
  if (g_pinned_hwnd != nullptr) {
    return true;
  }

  HWND hwnd = ::GetActiveWindow();
  if (hwnd == nullptr) {
    hwnd = ::GetForegroundWindow();
  }

  if (hwnd == nullptr) {
    return false;
  }

  g_pinned_hwnd = hwnd;
  return true;
}

// ------------------- 毛玻璃 / Acrylic 背景控制 -------------------

// 和 win32_window.cpp 中注册的窗口类名保持一致，用于定位 Flutter 主窗口。
constexpr const wchar_t kFlutterWindowClassName[] = L"FLUTTER_RUNNER_WIN32_WINDOW";

// 非官方的 Window composition 定义，来自社区约定：
// - WCA_ACCENT_POLICY = 19
// - AccentState 里包含 BLUR / ACRYLIC / HOSTBACKDROP 等状态。
enum AccentState {
  ACCENT_DISABLED = 0,
  ACCENT_ENABLE_GRADIENT = 1,
  ACCENT_ENABLE_TRANSPARENTGRADIENT = 2,
  ACCENT_ENABLE_BLURBEHIND = 3,
  ACCENT_ENABLE_ACRYLICBLURBEHIND = 4,
  ACCENT_ENABLE_HOSTBACKDROP = 5,
  ACCENT_INVALID_STATE = 6,
};

struct AccentPolicy {
  int AccentState;
  int AccentFlags;
  unsigned int GradientColor;
  int AnimationId;
};

enum WindowCompositionAttribute {
  WCA_UNDEFINED = 0,
  WCA_NCRENDERING_ENABLED = 1,
  WCA_NCRENDERING_POLICY = 2,
  WCA_TRANSITIONS_FORCEDISABLED = 3,
  WCA_ALLOW_NCPAINT = 4,
  WCA_CAPTION_BUTTON_BOUNDS = 5,
  WCA_NONCLIENT_RTL_LAYOUT = 6,
  WCA_FORCE_ICONIC_REPRESENTATION = 7,
  WCA_EXTENDED_FRAME_BOUNDS = 8,
  WCA_HAS_ICONIC_BITMAP = 9,
  WCA_THEME_ATTRIBUTES = 10,
  WCA_NCRENDERING_EXILED = 11,
  WCA_NCADORNMENTINFO = 12,
  WCA_EXCLUDED_FROM_LIVEPREVIEW = 13,
  WCA_VIDEO_OVERLAY_ACTIVE = 14,
  WCA_FORCE_ACTIVEWINDOW_APPEARANCE = 15,
  WCA_DISALLOW_PEEK = 16,
  WCA_CLOAK = 17,
  WCA_CLOAKED = 18,
  WCA_ACCENT_POLICY = 19,
};

struct WindowCompositionAttributeData {
  WindowCompositionAttribute Attribute;
  PVOID Data;
  SIZE_T SizeOfData;
};

using SetWindowCompositionAttributeFn =
    BOOL(WINAPI*)(HWND, WindowCompositionAttributeData*);

// 尝试找到当前 Flutter 主窗口。
HWND GetFlutterMainWindow() {
  static HWND cached = nullptr;
  if (cached != nullptr && ::IsWindow(cached)) {
    return cached;
  }
  cached = ::FindWindowW(kFlutterWindowClassName, nullptr);
  return cached;
}

bool ApplyAccentPolicy(HWND hwnd,
                       AccentState state,
                       unsigned int gradient_color) {
  HMODULE user32 = ::GetModuleHandleW(L"user32.dll");
  if (!user32) {
    return false;
  }

  const auto set_wca =
      reinterpret_cast<SetWindowCompositionAttributeFn>(
          ::GetProcAddress(user32, "SetWindowCompositionAttribute"));
  if (!set_wca) {
    return false;
  }

  AccentPolicy policy{};
  policy.AccentState = state;
  // Flag = 2 让模糊覆盖边框 / 客户区，社区使用最广。
  policy.AccentFlags = 2;
  policy.GradientColor = gradient_color;
  policy.AnimationId = 0;

  WindowCompositionAttributeData data{};
  data.Attribute = WCA_ACCENT_POLICY;
  data.Data = &policy;
  data.SizeOfData = sizeof(policy);

  const BOOL ok = set_wca(hwnd, &data);
  return ok == TRUE;
}

// 使用给定 RGB 颜色启动毛玻璃效果。
bool EnableGlassWithColor(COLORREF rgb, BYTE alpha) {
  HWND hwnd = GetFlutterMainWindow();
  if (!hwnd) {
    return false;
  }

  const BYTE r = GetRValue(rgb);
  const BYTE g = GetGValue(rgb);
  const BYTE b = GetBValue(rgb);

  // GradientColor: AARRGGBB，但 AccentPolicy 通常以 ABGR 形式解析。
  const unsigned int gradient_color =
      (static_cast<unsigned int>(alpha) << 24) |
      (static_cast<unsigned int>(b) << 16) |
      (static_cast<unsigned int>(g) << 8) |
      static_cast<unsigned int>(r);

  // 优先尝试 Acrylic，失败则回退到普通 BlurBehind，兼容 Win10 早期版本。
  if (ApplyAccentPolicy(hwnd, ACCENT_ENABLE_ACRYLICBLURBEHIND,
                        gradient_color)) {
    return true;
  }
  return ApplyAccentPolicy(hwnd, ACCENT_ENABLE_BLURBEHIND, gradient_color);
}

// 将窗口恢复为默认（关闭毛玻璃）。
bool DisableGlass() {
  HWND hwnd = GetFlutterMainWindow();
  if (!hwnd) {
    return false;
  }
  return ApplyAccentPolicy(hwnd, ACCENT_DISABLED, 0);
}

}  // namespace

// 将当前窗口缩放到较小尺寸并置顶，便于作为「时钟挂件」悬浮。
// 返回值：非 0 表示成功，0 表示失败（例如无法获取窗口句柄）。
__declspec(dllexport) std::int32_t rt_enter_pinned_mode() {
  if (g_is_pinned.load(std::memory_order_acquire)) {
    return 1;
  }

  if (!EnsureWindowHandle()) {
    return 0;
  }

  HWND hwnd = g_pinned_hwnd;

  WINDOWPLACEMENT placement{};
  placement.length = sizeof(placement);
  if (!::GetWindowPlacement(hwnd, &placement)) {
    return 0;
  }

  g_prev_placement = placement;
  g_prev_style = static_cast<LONG>(::GetWindowLongPtrW(hwnd, GWL_STYLE));
  g_prev_ex_style = static_cast<LONG>(::GetWindowLongPtrW(hwnd, GWL_EXSTYLE));

  RECT work_area = GetWorkAreaForWindow(hwnd);

  const int target_width = 360;
  const int target_height = 220;
  const int margin = 16;

  int x = work_area.right - target_width - margin;
  int y = work_area.top + margin;

  ::SetWindowPos(
      hwnd,
      HWND_TOPMOST,
      x,
      y,
      target_width,
      target_height,
      SWP_SHOWWINDOW | SWP_NOACTIVATE);

  // 在 pinned 小窗模式下，隐藏标题栏和边框，避免多余的窗口控件干扰。
  // - 去掉标题栏与粗边框（WS_CAPTION / WS_THICKFRAME）
  // - 去掉最小化 / 最大化按钮（WS_MINIMIZEBOX / WS_MAXIMIZEBOX）
  LONG new_style = g_prev_style;
  new_style &= ~WS_CAPTION;
  new_style &= ~WS_THICKFRAME;
  new_style &= ~WS_MINIMIZEBOX;
  new_style &= ~WS_MAXIMIZEBOX;
  ::SetWindowLongPtrW(hwnd, GWL_STYLE, new_style);
  ::SetWindowPos(hwnd,
                 nullptr,
                 0,
                 0,
                 0,
                 0,
                 SWP_NOMOVE | SWP_NOSIZE | SWP_NOZORDER | SWP_FRAMECHANGED);

  // 为 pinned 小窗显式启用圆角（在支持该属性的系统上，例如 Windows 11），
  // 避免无边框样式退化为完全矩形窗口。
  const auto corner_pref =
      static_cast<UINT>(DwmWindowCornerPreference::DWMWCP_ROUNDSMALL);
  DwmSetWindowAttribute(hwnd, DWMWA_WINDOW_CORNER_PREFERENCE, &corner_pref,
                        sizeof(corner_pref));

  g_is_pinned.store(true, std::memory_order_release);
  return 1;
}

// 退出置顶小窗模式，恢复窗口原有位置和大小。
// 返回值：非 0 表示成功，0 表示失败。
__declspec(dllexport) std::int32_t rt_exit_pinned_mode() {
  if (!g_is_pinned.load(std::memory_order_acquire)) {
    return 1;
  }

  if (g_pinned_hwnd == nullptr) {
    g_is_pinned.store(false, std::memory_order_release);
    return 0;
  }

  HWND hwnd = g_pinned_hwnd;

  const RECT& rect = g_prev_placement.rcNormalPosition;
  int width = rect.right - rect.left;
  int height = rect.bottom - rect.top;

  ::SetWindowPos(
      hwnd,
      HWND_NOTOPMOST,
      rect.left,
      rect.top,
      width,
      height,
      SWP_SHOWWINDOW);

  if (g_prev_style != 0) {
    ::SetWindowLongPtrW(hwnd, GWL_STYLE, g_prev_style);
  }
  if (g_prev_ex_style != 0) {
    ::SetWindowLongPtrW(hwnd, GWL_EXSTYLE, g_prev_ex_style);
  }
  ::SetWindowPos(hwnd,
                 nullptr,
                 0,
                 0,
                 0,
                 0,
                 SWP_NOMOVE | SWP_NOSIZE | SWP_NOZORDER | SWP_FRAMECHANGED);

  // 恢复为系统默认的圆角策略，避免对普通窗口产生意外影响。
  const auto corner_pref_reset =
      static_cast<UINT>(DwmWindowCornerPreference::DWMWCP_DEFAULT);
  DwmSetWindowAttribute(hwnd, DWMWA_WINDOW_CORNER_PREFERENCE,
                        &corner_pref_reset, sizeof(corner_pref_reset));

  g_is_pinned.store(false, std::memory_order_release);
  g_pinned_hwnd = nullptr;
  ::ZeroMemory(&g_prev_placement, sizeof(g_prev_placement));
  g_prev_style = 0;
  g_prev_ex_style = 0;

  return 1;
}

// ------------------- 毛玻璃 tint 控制导出（Windows FFI） -------------------

// 根据给定的 RGB 值，为主窗口应用带毛玻璃的背景颜色。
// 返回值：非 0 表示成功，0 表示失败。
__declspec(dllexport) std::int32_t rt_set_glass_tint(std::uint8_t r,
                                                     std::uint8_t g,
                                                     std::uint8_t b) {
  const COLORREF rgb = RGB(r, g, b);
  // 适中的透明度，避免过分刺眼。
  constexpr BYTE kAlpha = 0x99;
  return EnableGlassWithColor(rgb, kAlpha) ? 1 : 0;
}

// 重置为默认的白色毛玻璃背景。
__declspec(dllexport) std::int32_t rt_reset_glass_tint() {
  const COLORREF rgb = RGB(255, 255, 255);
  constexpr BYTE kAlpha = 0xC0;
  return EnableGlassWithColor(rgb, kAlpha) ? 1 : 0;
}

}  // extern "C"
