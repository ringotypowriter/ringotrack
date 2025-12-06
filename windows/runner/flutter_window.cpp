#include "flutter_window.h"

#include <optional>
#include <windowsx.h>

#include "flutter/generated_plugin_registrant.h"

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
  // 优先处理无边框窗口（例如 pinned 小窗）的拖动命中逻辑。
  // 由于 Flutter 也会处理窗口消息，这里在调用 Flutter 之前拦截 WM_NCHITTEST，
  // 确保无论 Flutter 是否覆盖命中结果，用户都可以拖动无边框小窗。
  if (message == WM_NCHITTEST) {
    const LONG style =
        static_cast<LONG>(GetWindowLongPtr(hwnd, GWL_STYLE));
    const bool has_caption = (style & WS_CAPTION) != 0;

    // 只对无标题栏的窗口做自定义命中（即无边框场景）。
    if (!has_caption) {
      POINT cursor_pos{GET_X_LPARAM(lparam), GET_Y_LPARAM(lparam)};
      ScreenToClient(hwnd, &cursor_pos);

      RECT client_rect{};
      GetClientRect(hwnd, &client_rect);

      // 右上角区域留给 Flutter 的 pin 按钮点击，其余区域都当作标题栏可拖动。
      constexpr int kPinSafeWidth = 80;   // 顶部右侧的安全宽度
      constexpr int kPinSafeHeight = 80;  // 顶部的安全高度

      const bool in_pin_safe_region =
          cursor_pos.x >= client_rect.right - kPinSafeWidth &&
          cursor_pos.x <= client_rect.right &&
          cursor_pos.y >= client_rect.top &&
          cursor_pos.y <= client_rect.top + kPinSafeHeight;

      if (in_pin_safe_region) {
        return HTCLIENT;
      }

      return HTCAPTION;
    }
  }

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
