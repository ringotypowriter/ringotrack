import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  private var foregroundAppStreamHandler: ForegroundAppStreamHandler?
  private var strokeEventStreamHandler: StrokeEventStreamHandler?
  private var isPinnedWindow: Bool = false
  private var previousFrame: NSRect?
  private var previousLevel: NSWindow.Level?
  private var previousCollectionBehavior: NSWindow.CollectionBehavior?

  override func awakeFromNib() {
    NSLog("[RingoTrack] MainFlutterWindow awakeFromNib - setting up FlutterViewController")

    let flutterViewController = FlutterViewController()
    self.contentViewController = flutterViewController

    let windowFrame = self.frame
    let targetFrame = NSRect(
      x: windowFrame.origin.x,
      y: windowFrame.origin.y,
      width: 1440,
      height: 900
    )
    self.setFrame(targetFrame, display: true)

    self.center()

    RegisterGeneratedPlugins(registry: flutterViewController)

    let binaryMessenger = flutterViewController.engine.binaryMessenger

    // 设置窗口置顶模式的 MethodChannel
    let pinChannel = FlutterMethodChannel(
      name: "ringotrack/window_pin",
      binaryMessenger: binaryMessenger
    )
    pinChannel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else {
        result(FlutterError(code: "window_deallocated",
                            message: "MainFlutterWindow released",
                            details: nil))
        return
      }

      switch call.method {
      case "enterPinnedMode":
        let ok = self.enterPinnedMode()
        result(ok)
      case "exitPinnedMode":
        let ok = self.exitPinnedMode()
        result(ok)
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    // 设置前台应用事件的 EventChannel
    let eventChannel = FlutterEventChannel(
      name: "ringotrack/foreground_app_events",
      binaryMessenger: binaryMessenger
    )
    let handler = ForegroundAppStreamHandler()
    eventChannel.setStreamHandler(handler)
    foregroundAppStreamHandler = handler

    // 设置全局左键/落笔事件的 EventChannel
    let strokeChannel = FlutterEventChannel(
      name: "ringotrack/stroke_events",
      binaryMessenger: binaryMessenger
    )
    let strokeHandler = StrokeEventStreamHandler()
    strokeChannel.setStreamHandler(strokeHandler)
    strokeEventStreamHandler = strokeHandler

    NSLog("[RingoTrack] MainFlutterWindow set up foreground app + stroke event channels")

    super.awakeFromNib()
  }

  private func enterPinnedMode() -> Bool {
    if isPinnedWindow {
      return true
    }

    guard let screen = self.screen ?? NSScreen.main else {
      return false
    }

    previousFrame = self.frame
    previousLevel = self.level
    previousCollectionBehavior = self.collectionBehavior

    let workFrame = screen.visibleFrame
    let targetWidth: CGFloat = 360
    let targetHeight: CGFloat = 220
    let margin: CGFloat = 16

    let originX = workFrame.maxX - targetWidth - margin
    let originY = workFrame.maxY - targetHeight - margin
    let targetFrame = NSRect(x: originX, y: originY, width: targetWidth, height: targetHeight)

    self.setFrame(targetFrame, display: true, animate: true)

    var behavior = self.collectionBehavior
    behavior.insert(.canJoinAllSpaces)
    self.collectionBehavior = behavior

    self.level = .floating
    self.isMovable = true
    self.isMovableByWindowBackground = true

    isPinnedWindow = true
    NSLog("[RingoTrack] MainFlutterWindow enterPinnedMode")
    return true
  }

  private func exitPinnedMode() -> Bool {
    if !isPinnedWindow {
      return true
    }

    let frameToRestore = previousFrame ?? self.frame
    let levelToRestore = previousLevel ?? .normal
    let behaviorToRestore = previousCollectionBehavior ?? self.collectionBehavior

    self.level = levelToRestore
    self.collectionBehavior = behaviorToRestore
    self.setFrame(frameToRestore, display: true, animate: true)

    isPinnedWindow = false
    previousFrame = nil
    previousLevel = nil
    previousCollectionBehavior = nil

    NSLog("[RingoTrack] MainFlutterWindow exitPinnedMode")
    return true
  }
}
