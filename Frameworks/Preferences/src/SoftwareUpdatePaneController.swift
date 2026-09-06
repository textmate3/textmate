import AppKit
import SwiftUI

/// The Objective-C face of the Software Update pane. The preferences window
/// treats it like any other pane: a view controller with an identifier, a
/// title and a toolbar image. Objective-C never sees SwiftUI.
@objc(TMSoftwareUpdatePaneController)
@MainActor
public final class SoftwareUpdatePaneController: NSViewController, PreferencesPaneProtocol {
  public init() {
    super.init(nibName: nil, bundle: nil)
    identifier = NSUserInterfaceItemIdentifier("Software Update")
    title = "Software Update"
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("The Software Update pane is not loaded from a nib.")
  }

  // The protocol is not actor isolated, so this cannot touch the title.
  @objc nonisolated public var toolbarItemImage: NSImage {
    NSImage(systemSymbolName: "arrow.triangle.2.circlepath", accessibilityDescription: "Software Update")!
  }

  public override func loadView() {
    view = NSHostingView(rootView: SoftwareUpdateView())
  }
}
