import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  private var foregroundAppStreamHandler: ForegroundAppStreamHandler?
  private var strokeEventStreamHandler: StrokeEventStreamHandler?

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

    // 设置前台应用事件的 EventChannel
    let eventChannel = FlutterEventChannel(
      name: "ringotrack/foreground_app_events",
      binaryMessenger: flutterViewController.engine.binaryMessenger
    )
    let handler = ForegroundAppStreamHandler()
    eventChannel.setStreamHandler(handler)
    foregroundAppStreamHandler = handler

    // 设置全局左键/落笔事件的 EventChannel
    let strokeChannel = FlutterEventChannel(
      name: "ringotrack/stroke_events",
      binaryMessenger: flutterViewController.engine.binaryMessenger
    )
    let strokeHandler = StrokeEventStreamHandler()
    strokeChannel.setStreamHandler(strokeHandler)
    strokeEventStreamHandler = strokeHandler

    NSLog("[RingoTrack] MainFlutterWindow set up foreground app + stroke event channels")

    super.awakeFromNib()
  }
}
