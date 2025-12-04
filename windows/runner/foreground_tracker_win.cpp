#include <windows.h>
#include <cstdint>

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

}  // extern "C"

