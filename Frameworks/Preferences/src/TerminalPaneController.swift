import AppKit
import SwiftUI

/// The Objective-C face of the Terminal pane. The preferences window treats
/// it like any other pane: a view controller with an identifier, a title and
/// a toolbar image. Objective-C never sees SwiftUI.
@objc(TMTerminalPaneController)
@MainActor
public final class TerminalPaneController: NSViewController, PreferencesPaneProtocol {
  public init() {
    super.init(nibName: nil, bundle: nil)
    identifier = NSUserInterfaceItemIdentifier("Terminal")
    title = "Terminal"
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("The Terminal pane is not loaded from a nib.")
  }

  // The protocol is not actor isolated, so this cannot touch the title.
  @objc nonisolated public var toolbarItemImage: NSImage {
    NSImage(systemSymbolName: "terminal", accessibilityDescription: "Terminal")!
  }

  public override func loadView() {
    view = NSHostingView(rootView: TerminalView())
    // Opening the pane claims the txmt scheme for this copy, as it always has,
    // so links from a shell or rmate land here rather than in another TextMate.
    NSWorkspace.shared.setDefaultApplication(at: Bundle.main.bundleURL, toOpenURLsWithScheme: "txmt")
  }
}
