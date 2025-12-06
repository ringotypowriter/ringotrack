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

  // 毛玻璃 tint 图层，用于动态修改颜色
  private var glassTintView: NSView?
  private var glassTintGradientLayer: CAGradientLayer?

  // 关闭窗口前，将窗口恢复成标准大窗尺寸，
  // 避免系统记住 pinned 小窗或用户调整后的尺寸。
  override func close() {
    if let screen = self.screen ?? NSScreen.main {
      let targetWidth: CGFloat = 1440
      let targetHeight: CGFloat = 900
      let screenFrame = screen.visibleFrame
      let originX = screenFrame.origin.x + (screenFrame.width - targetWidth) / 2
      let originY = screenFrame.origin.y + (screenFrame.height - targetHeight) / 2
      let targetFrame = NSRect(
        x: originX,
        y: originY,
        width: targetWidth,
        height: targetHeight
      )
      self.setFrame(targetFrame, display: false)
    }
    super.close()
  }

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

    // 设置毛玻璃 tint 颜色控制的 MethodChannel
    let glassTintChannel = FlutterMethodChannel(
      name: "ringotrack/glass_tint",
      binaryMessenger: binaryMessenger
    )
    glassTintChannel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else {
        result(FlutterError(code: "window_deallocated",
                            message: "MainFlutterWindow released",
                            details: nil))
        return
      }

      switch call.method {
      case "setTintColor":
        guard let args = call.arguments as? [String: Any],
              let r = args["r"] as? Double,
              let g = args["g"] as? Double,
              let b = args["b"] as? Double else {
          result(FlutterError(code: "invalid_arguments",
                              message: "Expected r, g, b as doubles",
                              details: nil))
          return
        }
        self.setGlassTintColor(r: r, g: g, b: b)
        result(true)
      case "resetTintColor":
        self.resetGlassTintColor()
        result(true)
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

    // 让内容视图覆盖到整个窗口区域，并让系统标题栏背景透明，
    // 这样我们可以用一整块毛玻璃把 titlebar + content 统一起来。
    self.titlebarAppearsTransparent = true
    self.styleMask.insert(.fullSizeContentView)
    self.titleVisibility = .visible

    // 在 Flutter 内容视图内部添加一层毛玻璃背景，覆盖整个窗口区域。
    if let contentView = self.contentView {
      let blurView = NSVisualEffectView(frame: contentView.bounds)
      blurView.autoresizingMask = [.width, .height]
      blurView.material = .sidebar
      blurView.blendingMode = .behindWindow
      blurView.state = .active

      // 叠加一层带渐变的白色 tint：顶部更白，向下渐变到几乎透明，
      // 这样 titlebar + 顶部区域会更亮，但没有生硬的分界高度。
      let tintView = NSView(frame: blurView.bounds)
      tintView.autoresizingMask = [.width, .height]
      tintView.wantsLayer = true
      let gradientLayer = CAGradientLayer()
      gradientLayer.colors = [
        NSColor.white.withAlphaComponent(0.78).cgColor,
        NSColor.white.withAlphaComponent(0.46).cgColor,
        NSColor.white.withAlphaComponent(0.18).cgColor,
        NSColor.white.withAlphaComponent(0.02).cgColor,
      ]
      gradientLayer.locations = [0.0, 0.22, 0.55, 1.0]
      gradientLayer.startPoint = CGPoint(x: 0.5, y: 1.0)
      gradientLayer.endPoint = CGPoint(x: 0.5, y: 0.0)
      gradientLayer.frame = tintView.bounds
      gradientLayer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
      tintView.layer = CALayer()
      tintView.layer?.masksToBounds = true
      tintView.layer?.addSublayer(gradientLayer)
      blurView.addSubview(tintView)

      // 保存引用，以便后续动态修改
      self.glassTintView = tintView
      self.glassTintGradientLayer = gradientLayer

      contentView.wantsLayer = true
      contentView.layer?.backgroundColor = NSColor.clear.cgColor

      contentView.addSubview(blurView, positioned: .below, relativeTo: nil)
    }
  }

  /// 设置毛玻璃 tint 颜色（传入 0-1 的 RGB 值）
  private func setGlassTintColor(r: Double, g: Double, b: Double) {
    guard let gradientLayer = self.glassTintGradientLayer else { return }

    let baseColor = NSColor(
      calibratedRed: CGFloat(r),
      green: CGFloat(g),
      blue: CGFloat(b),
      alpha: 1.0
    )

    // 自定义颜色时使用纯色（统一透明度），不使用渐变
    let tintColor = baseColor.withAlphaComponent(0.25).cgColor
    gradientLayer.colors = [tintColor, tintColor, tintColor, tintColor]

    NSLog("[RingoTrack] Set glass tint to RGB(\(r), \(g), \(b)) - solid color")
  }

  /// 重置为默认白色 tint
  private func resetGlassTintColor() {
    guard let gradientLayer = self.glassTintGradientLayer else { return }

    gradientLayer.colors = [
      NSColor.white.withAlphaComponent(0.78).cgColor,
      NSColor.white.withAlphaComponent(0.46).cgColor,
      NSColor.white.withAlphaComponent(0.18).cgColor,
      NSColor.white.withAlphaComponent(0.02).cgColor,
    ]

    NSLog("[RingoTrack] Reset glass tint to white")
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
