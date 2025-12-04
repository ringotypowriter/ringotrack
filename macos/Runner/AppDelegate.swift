import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
}

class ForegroundAppStreamHandler: NSObject, FlutterStreamHandler {
  private var eventSink: FlutterEventSink?
  private var observer: Any?

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    NSLog("[RingoTrack] ForegroundAppStreamHandler onListen")
    self.eventSink = events

    let center = NSWorkspace.shared.notificationCenter
    observer = center.addObserver(
      forName: NSWorkspace.didActivateApplicationNotification,
      object: nil,
      queue: OperationQueue.main
    ) { [weak self] notification in
      guard
        let strongSelf = self,
        let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
      else {
        return
      }

      strongSelf.emitEvent(for: app)
    }

    // 初次监听时主动发一次当前前台应用
    if let frontmost = NSWorkspace.shared.frontmostApplication {
      NSLog("[RingoTrack] ForegroundAppStreamHandler initial frontmost: \(frontmost.bundleIdentifier ?? "unknown")")
      emitEvent(for: frontmost)
    }

    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    NSLog("[RingoTrack] ForegroundAppStreamHandler onCancel")
    if let observer = observer {
      NSWorkspace.shared.notificationCenter.removeObserver(observer)
    }
    observer = nil
    eventSink = nil
    return nil
  }

  private func emitEvent(for app: NSRunningApplication) {
    guard let sink = eventSink else { return }

    let bundleId = app.bundleIdentifier ?? "unknown"
    let timestampMillis = Int(Date().timeIntervalSince1970 * 1000)

     NSLog("[RingoTrack] ForegroundAppStreamHandler emitEvent bundleId=\(bundleId) timestampMillis=\(timestampMillis)")

    sink([
      "appId": bundleId,
      "timestamp": timestampMillis,
    ])
  }
}
