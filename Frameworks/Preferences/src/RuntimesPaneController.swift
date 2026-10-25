import AppKit
import SwiftUI

/// The Objective-C face of the Runtimes pane, the way the Bundles pane has one.
/// The preferences window treats it like any other pane: a view controller with an identifier, a title and a toolbar image.
@objc(TMRuntimesPaneController)
@MainActor
public final class RuntimesPaneController: NSViewController, PreferencesPaneProtocol {
  public init() {
    super.init(nibName: nil, bundle: nil)
    identifier = NSUserInterfaceItemIdentifier("Runtimes")
    title = "Runtimes"
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("The Runtimes pane is not loaded from a nib.")
  }

  // The protocol is not actor isolated, so this cannot touch the title.
  @objc nonisolated public var toolbarItemImage: NSImage {
    NSImage(systemSymbolName: "cpu", accessibilityDescription: "Runtimes")!
  }

  public override func loadView() {
    view = NSHostingView(rootView: RuntimesView())
  }
}
