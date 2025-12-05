import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  private var foregroundAppStreamHandler: ForegroundAppStreamHandler?
  private var strokeEventStreamHandler: StrokeEventStreamHandler?
  private var isPinnedWindow: Bool = false
  private var previousFrame: NSRect?
  private var previousLevel: NSWindow.Level?
  private var previousCollectionBehavior: NSWindow.CollectionBehavior?
  private var previousStyleMask: NSWindow.StyleMask?
  private var previousTitleVisibility: NSWindow.TitleVisibility?
  private var previousTitlebarAppearsTransparent: Bool?
  private var previousCloseButtonHidden: Bool?
  private var previousMiniaturizeButtonHidden: Bool?
  private var previousZoomButtonHidden: Bool?

  override func awakeFromNib() {
    NSLog("[RingoTrack] MainFlutterWindow awakeFromNib - setting up FlutterViewController")

    let flutterViewController = FlutterViewController()
    flutterViewController.backgroundColor = NSColor.clear
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

    // 在 Flutter 内容视图内部添加一层毛玻璃背景，仅影响内容区域，不动系统标题栏。
    if let contentView = self.contentView {
      let blurView = NSVisualEffectView(frame: contentView.bounds)
      blurView.autoresizingMask = [.width, .height]
      blurView.material = .sidebar
      blurView.blendingMode = .behindWindow
      blurView.state = .active

      // 叠加更明显的白色 tint，让背景更接近纯白磨砂。
      let tintView = NSView(frame: blurView.bounds)
      tintView.autoresizingMask = [.width, .height]
      tintView.wantsLayer = true
      tintView.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.38).cgColor
      blurView.addSubview(tintView)

      contentView.wantsLayer = true
      contentView.layer?.backgroundColor = NSColor.clear.cgColor

      contentView.addSubview(blurView, positioned: .below, relativeTo: nil)
    }
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
    previousStyleMask = self.styleMask
    previousTitleVisibility = self.titleVisibility
    previousTitlebarAppearsTransparent = self.titlebarAppearsTransparent
    if let closeButton = self.standardWindowButton(.closeButton) {
      previousCloseButtonHidden = closeButton.isHidden
    }
    if let miniButton = self.standardWindowButton(.miniaturizeButton) {
      previousMiniaturizeButtonHidden = miniButton.isHidden
    }
    if let zoomButton = self.standardWindowButton(.zoomButton) {
      previousZoomButtonHidden = zoomButton.isHidden
    }

    let workFrame = screen.visibleFrame
    let targetWidth: CGFloat = 360
    let targetHeight: CGFloat = 220
    let margin: CGFloat = 16

    let originX = workFrame.maxX - targetWidth - margin
    let originY = workFrame.maxY - targetHeight - margin
    let targetFrame = NSRect(x: originX, y: originY, width: targetWidth, height: targetHeight)

    self.setFrame(targetFrame, display: true, animate: true)

    // 在 pinned 小窗模式下，隐藏标题栏 / 工具栏，让内容填满整个窗口。
    self.titleVisibility = .hidden
    self.titlebarAppearsTransparent = true
    self.styleMask.insert(.fullSizeContentView)
    if let closeButton = self.standardWindowButton(.closeButton) {
      closeButton.isHidden = true
    }
    if let miniButton = self.standardWindowButton(.miniaturizeButton) {
      miniButton.isHidden = true
    }
    if let zoomButton = self.standardWindowButton(.zoomButton) {
      zoomButton.isHidden = true
    }

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

    // 恢复标题栏 / 工具栏相关外观。
    if let styleMask = previousStyleMask {
      self.styleMask = styleMask
    }
    if let titleVisibility = previousTitleVisibility {
      self.titleVisibility = titleVisibility
    }
    if let titlebarTransparent = previousTitlebarAppearsTransparent {
      self.titlebarAppearsTransparent = titlebarTransparent
    }
    if let closeHidden = previousCloseButtonHidden,
       let closeButton = self.standardWindowButton(.closeButton) {
      closeButton.isHidden = closeHidden
    }
    if let miniHidden = previousMiniaturizeButtonHidden,
       let miniButton = self.standardWindowButton(.miniaturizeButton) {
      miniButton.isHidden = miniHidden
    }
    if let zoomHidden = previousZoomButtonHidden,
       let zoomButton = self.standardWindowButton(.zoomButton) {
      zoomButton.isHidden = zoomHidden
    }

    isPinnedWindow = false
    previousFrame = nil
    previousLevel = nil
    previousCollectionBehavior = nil
    previousStyleMask = nil
    previousTitleVisibility = nil
    previousTitlebarAppearsTransparent = nil
    previousCloseButtonHidden = nil
    previousMiniaturizeButtonHidden = nil
    previousZoomButtonHidden = nil

    NSLog("[RingoTrack] MainFlutterWindow exitPinnedMode")
    return true
  }
}
