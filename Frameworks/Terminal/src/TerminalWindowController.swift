import AppKit
import SwiftUI

/// A terminal in a window of its own, opened from the menu, the way the Bundle
/// Editor is. It owns no part of a document window, so nothing about the editor
/// changes and this can be taken back out without a trace.
@objc(TMTerminalWindowController)
public final class TerminalWindowController: NSWindowController, NSWindowDelegate {
  private let session = TerminalSession()

  @objc public static let sharedInstance = TerminalWindowController()

  private init() {
    let window = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: 640, height: 400),
      styleMask: [.titled, .closable, .miniaturizable, .resizable],
      backing: .buffered,
      defer: false
    )
    window.title = "Terminal"
    window.setFrameAutosaveName("TMTerminalWindow")
    super.init(window: window)

    window.delegate = self
    window.contentView = NSHostingView(rootView: TerminalView(session: session))
  }

  required init?(coder: NSCoder) {
    fatalError("The Terminal window is not loaded from a nib.")
  }

  /// Opens the window, starting a shell the first time. The directory is the
  /// project the person is in, when there is one, so the shell opens where
  /// their work is.
  @objc public func show(in directory: String?) {
    session.start(in: directory)
    showWindow(self)
    window?.makeKeyAndOrderFront(self)
  }

  public func windowWillClose(_ notification: Notification) {
    session.terminate()
  }
}
