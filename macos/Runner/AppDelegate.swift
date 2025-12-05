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

class StrokeEventStreamHandler: NSObject, FlutterStreamHandler {
  private var eventSink: FlutterEventSink?
  private var monitor: Any?
  private var pollTimer: Timer?
  private var lastActivity: Date = Date()
  private var lastButtonDown: Bool = false

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    NSLog("[RingoTrack] StrokeEventStreamHandler onListen")
    self.eventSink = events

    // 捕获全局左键（落笔）事件
    monitor = NSEvent.addGlobalMonitorForEvents(
      matching: [.leftMouseDown, .otherMouseDown, .leftMouseUp, .otherMouseUp],
      handler: { [weak self] event in
        guard let self = self else { return }
        let isDown = (event.type == .leftMouseDown || event.type == .otherMouseDown)
        let now = Date()
        self.lastActivity = now
        self.lastButtonDown = isDown
        self.emitStroke(at: now, isDown: isDown)
      }
    )

    // 轮询系统输入时间，避免全局监听权限不足时无法恢复
    pollTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
      guard let self = self else { return }
      let idleLeftDown = CGEventSource.secondsSinceLastEventType(
        .combinedSessionState,
        eventType: .leftMouseDown
      )
      let idleLeftDrag = CGEventSource.secondsSinceLastEventType(
        .combinedSessionState,
        eventType: .leftMouseDragged
      )
      let idle = min(idleLeftDown, idleLeftDrag)
      if idle.isInfinite || idle.isNaN || idle < 0 {
        return
      }
      let activityTime = Date().addingTimeInterval(-idle)
      let isDown = CGEventSource.buttonState(.combinedSessionState, button: .left)

      let delta = activityTime.timeIntervalSince(self.lastActivity)
      if abs(delta) > 0.05 || isDown != self.lastButtonDown {
        self.lastActivity = activityTime
        self.lastButtonDown = isDown
        self.emitStroke(at: activityTime, isDown: isDown)
      }
    }

    // 初始化一次，避免 Dart 侧在无事件时立即判定为 Idle，默认视为未按下
    lastActivity = Date()
    lastButtonDown = false
    emitStroke(at: lastActivity, isDown: false)
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    NSLog("[RingoTrack] StrokeEventStreamHandler onCancel")
    if let monitor = monitor {
      NSEvent.removeMonitor(monitor)
    }
    pollTimer?.invalidate()
    pollTimer = nil
    monitor = nil
    eventSink = nil
    return nil
  }

  private func emitStroke(at date: Date, isDown: Bool) {
    guard let sink = eventSink else { return }
    let timestampMillis = Int(date.timeIntervalSince1970 * 1000)
    sink([
      "timestamp": timestampMillis,
      "isDown": isDown,
    ])
  }
}
