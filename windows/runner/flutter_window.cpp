#include "flutter_window.h"

#include <flutter_windows.h>
#include <optional>
#include <windowsx.h>

#include "flutter/generated_plugin_registrant.h"

// 来自 foreground_tracker_win.cpp：查询当前是否处于 pinned 模式。
extern "C" int rt_is_pinned();
// 查询当前是否处于锁定状态（lock 模式）。
extern "C" int rt_is_locked();

namespace {

double GetFlutterWindowScaleFactor(HWND hwnd) {
  HMONITOR monitor = MonitorFromWindow(hwnd, MONITOR_DEFAULTTONEAREST);
  if (monitor == nullptr) {
    return 1.0;
  }

  const UINT dpi = FlutterDesktopGetDpiForMonitor(monitor);
  if (dpi == 0) {
    return 1.0;
  }

  return static_cast<double>(dpi) / 96.0;
}

int ScaleToDpiValue(int source, double scale_factor) {
  const int scaled = static_cast<int>(source * scale_factor);
  return scaled > 0 ? scaled : 1;
}

// 原始 Flutter View 窗口过程，用于在自定义处理后转发消息。
WNDPROC g_flutter_view_wndproc = nullptr;

// 针对 Flutter 子窗口的自定义窗口过程：
// 在 pinned 模式下，对 WM_NCHITTEST 返回 HTTRANSPARENT，
// 让父窗口处理命中测试，从而实现流畅的窗口拖动。
LRESULT CALLBACK FlutterViewWindowProc(HWND hwnd,
                                       UINT const message,
                                       WPARAM const wparam,
                                       LPARAM const lparam) {
  switch (message) {
    case WM_NCHITTEST: {
      if (rt_is_pinned() && !rt_is_locked()) {
        // 获取鼠标屏幕坐标
        POINT screen_pos{GET_X_LPARAM(lparam), GET_Y_LPARAM(lparam)};

        // 转换为客户区坐标
        POINT client_pos = screen_pos;
        ScreenToClient(hwnd, &client_pos);

        RECT client_rect{};
        GetClientRect(hwnd, &client_rect);

        // 在右上角预留一块区域给 Flutter 内部的 pin 按钮点击
        constexpr int kPinSafeWidthDip = 80;
        constexpr int kPinSafeHeightDip = 80;
        constexpr int kLockSafeWidthDip = 80;
        constexpr int kLockSafeHeightDip = 80;
        const double scale_factor = GetFlutterWindowScaleFactor(hwnd);
        const int kPinSafeWidthScaled =
            ScaleToDpiValue(kPinSafeWidthDip, scale_factor);
        const int kPinSafeHeightScaled =
            ScaleToDpiValue(kPinSafeHeightDip, scale_factor);
        const int kLockSafeWidthScaled =
            ScaleToDpiValue(kLockSafeWidthDip, scale_factor);
        const int kLockSafeHeightScaled =
            ScaleToDpiValue(kLockSafeHeightDip, scale_factor);
        const bool in_pin_safe_region =
            client_pos.x >= client_rect.right - kPinSafeWidthScaled &&
            client_pos.x <= client_rect.right &&
            client_pos.y >= client_rect.top &&
            client_pos.y <= client_rect.top + kPinSafeHeightScaled;
        const bool in_lock_safe_region =
            client_pos.x >= client_rect.right - kLockSafeWidthScaled &&
            client_pos.x <= client_rect.right &&
            client_pos.y >= client_rect.bottom - kLockSafeHeightScaled &&
            client_pos.y <= client_rect.bottom;

        if (!in_pin_safe_region && !in_lock_safe_region) {
          // 返回 HTTRANSPARENT，让系统将命中测试传递给父窗口，
          // 父窗口会返回 HTCAPTION，从而触发系统原生拖动。
          return HTTRANSPARENT;
        }
      }
      break;
    }
  }

  if (g_flutter_view_wndproc) {
    return CallWindowProc(g_flutter_view_wndproc, hwnd, message, wparam,
                          lparam);
  }
  return DefWindowProc(hwnd, message, wparam, lparam);
}

}  // namespace

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  // 子类化 Flutter View 的窗口过程，以便在 pinned 模式下
  // 对 WM_NCHITTEST 返回 HTTRANSPARENT，让父窗口处理拖动。
  HWND flutter_view_hwnd = flutter_controller_->view()->GetNativeWindow();
  g_flutter_view_wndproc = reinterpret_cast<WNDPROC>(
      SetWindowLongPtr(flutter_view_hwnd, GWLP_WNDPROC,
                       reinterpret_cast<LONG_PTR>(FlutterViewWindowProc)));

  return true;
}

void FlutterWindow::OnDestroy() {
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
