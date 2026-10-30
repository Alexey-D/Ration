import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    self.contentViewController = flutterViewController

    // Стартовый размер окна — как в Windows-версии; таблица рациона требует места.
    self.title = "Рацион"
    self.setContentSize(NSSize(width: 1280, height: 860))
    self.contentMinSize = NSSize(width: 400, height: 600)
    self.center()

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
