import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    self.contentViewController = flutterViewController

    // 固定窗口尺寸为 1440x900
    let windowFrame = self.frame
    let targetFrame = NSRect(
      x: windowFrame.origin.x,
      y: windowFrame.origin.y,
      width: 1440,
      height: 900
    )
    self.setFrame(targetFrame, display: true)
    // 将窗口居中到当前屏幕
    self.center()

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
