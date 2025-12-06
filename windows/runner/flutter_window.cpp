#include "flutter_window.h"

#include <optional>
#include <windowsx.h>

#include "flutter/generated_plugin_registrant.h"

namespace {

// 原始 Flutter View 窗口过程，用于在自定义处理后转发消息。
WNDPROC g_flutter_view_wndproc = nullptr;

// 针对 Flutter 子窗口的自定义窗口过程：
// - 在父窗口为无标题栏（即 pinned / 无边框）时，
//   将除右上角一小块区域外的所有区域视为「拖动区域」。
// - 用户在这些区域按下左键时，模拟对父窗口标题栏的点击，触发系统拖动。
LRESULT CALLBACK FlutterViewWindowProc(HWND hwnd,
                                      UINT const message,
                                      WPARAM const wparam,
                                      LPARAM const lparam) {
  switch (message) {
    case WM_LBUTTONDOWN: {
      HWND parent = GetAncestor(hwnd, GA_ROOT);
      if (parent != nullptr) {
        const LONG style =
            static_cast<LONG>(GetWindowLongPtr(parent, GWL_STYLE));
        const bool has_caption = (style & WS_CAPTION) != 0;

        // 仅当父窗口是无标题栏（即自绘无边框场景，例如 pinned 小窗）时，
        // 才把点击视为拖动操作。
        if (!has_caption) {
          // 客户区坐标（对于 WM_LBUTTONDOWN，lParam 已经是客户端坐标）。
          POINT client_pos{GET_X_LPARAM(lparam), GET_Y_LPARAM(lparam)};

          RECT client_rect{};
          GetClientRect(hwnd, &client_rect);

          // 在右上角预留一块区域给 Flutter 内部的 pin 按钮点击，
          // 避免把 pin 按钮点击也拦截成拖动。
          constexpr int kPinSafeWidth = 80;
          constexpr int kPinSafeHeight = 80;
          const bool in_pin_safe_region =
              client_pos.x >= client_rect.right - kPinSafeWidth &&
              client_pos.x <= client_rect.right &&
              client_pos.y >= client_rect.top &&
              client_pos.y <= client_rect.top + kPinSafeHeight;

          if (!in_pin_safe_region) {
            // 将客户端坐标转换为屏幕坐标，用于构造 WM_NCLBUTTONDOWN 的 lParam。
            POINT screen_pos = client_pos;
            ClientToScreen(hwnd, &screen_pos);
            const LPARAM screen_lparam =
                MAKELPARAM(static_cast<short>(screen_pos.x),
                           static_cast<short>(screen_pos.y));

            // 释放当前捕获，并在父窗口上模拟一次对标题栏的点击，
            // 让系统进入窗口拖动模式。
            ReleaseCapture();
            SendMessage(parent, WM_NCLBUTTONDOWN, HTCAPTION, screen_lparam);

            // 不再将该事件传递给 Flutter，避免产生多余的点击反馈。
            return 0;
          }
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

  // 子类化 Flutter View 的窗口过程，以便在无边框模式下拦截鼠标按下事件，
  // 实现「全窗口可拖动」的小窗效果。
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
