import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  private var foregroundAppStreamHandler: ForegroundAppStreamHandler?

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

    NSLog("[RingoTrack] MainFlutterWindow set up foreground app event channel")

    super.awakeFromNib()
  }
}
