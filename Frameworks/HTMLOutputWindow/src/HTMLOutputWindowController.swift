import AppKit
import HTMLOutput

/// The window a command's HTML output gets when output goes to a window of its own:
/// an output view filling it, the title and the edited mark bound to the view, and a close that
/// asks before stopping a command still running.
///
/// The controller keeps itself alive from the moment the window shows until a turn of the run loop
/// after it closes, since nothing else holds it: the command runner lets go once the command has finished.
@objc(HTMLOutputWindowController)
@MainActor
public final class HTMLOutputWindowController: NSWindowController, NSWindowDelegate {
  @objc public let htmlOutputView = HTMLOutputView(frame: .zero)

  private var retainedSelf: HTMLOutputWindowController?

  /// The window, a third of the main screen's width and three fifths of its height, in the middle.
  @objc public convenience init() {
    let screen = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1200, height: 800)
    let rect = screen.insetBy(dx: screen.width / 3, dy: screen.height / 5).integral
    let window = NSWindow(contentRect: rect, styleMask: [.titled, .closable, .resizable, .miniaturizable], backing: .buffered, defer: false)
    self.init(window: window)

    window.bind(.title, to: htmlOutputView, withKeyPath: "mainFrameTitle", options: nil)
    window.bind(.documentEdited, to: htmlOutputView, withKeyPath: "runningCommand", options: nil)
    window.contentView = htmlOutputView
    window.delegate = self
    window.isReleasedWhenClosed = false
    window.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
  }

  public override init(window: NSWindow?) {
    super.init(window: window)
  }

  /// A window per command identifier, so each remembers its own frame.
  @objc(initWithIdentifier:)
  public convenience init(identifier: UUID) {
    self.init()
    window?.setFrameAutosaveName("HTML output for \(identifier.uuidString)")
  }

  @available(*, unavailable)
  public required init?(coder: NSCoder) {
    fatalError("HTMLOutputWindowController is created in code")
  }

  deinit {
    MainActor.assumeIsolated {
      NotificationCenter.default.removeObserver(self)
      window?.delegate = nil
    }
  }

  public override func showWindow(_ sender: Any?) {
    retainedSelf = self
    super.showWindow(sender)
  }

  public override func cancelOperation(_ sender: Any?) {
    window?.performClose(sender)
  }

  /// A window with a running command behind it asks before closing, and closes itself once the command has stopped.
  public func windowShouldClose(_ sender: NSWindow) -> Bool {
    guard htmlOutputView.isRunningCommand else { return true }

    htmlOutputView.stopLoading(askingUser: true) { [weak self] didStop in
      guard didStop, let window = self?.window else { return }
      window.orderOut(self)
      window.close()
    }
    return false
  }

  public func windowWillClose(_ notification: Notification) {
    // Let go on the next turn of the run loop rather than inside the close, which is still using the controller.
    DispatchQueue.main.async { [self] in
      retainedSelf = nil
    }
  }
}
