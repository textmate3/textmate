import AppKit
import SwiftUI

/// The Objective-C face of the Bundles pane. The preferences window treats
/// it like any other pane: a view controller with an identifier, a title and
/// a toolbar image. Objective-C never sees SwiftUI.
@objc(TMBundlesPaneController)
@MainActor
public final class BundlesPaneController: NSViewController, PreferencesPaneProtocol {
  public init() {
    super.init(nibName: nil, bundle: nil)
    identifier = NSUserInterfaceItemIdentifier("Bundles")
    title = "Bundles"
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("The Bundles pane is not loaded from a nib.")
  }

  // The protocol is not actor isolated, so this cannot touch the title.
  @objc nonisolated public var toolbarItemImage: NSImage {
    NSImage(systemSymbolName: "shippingbox", accessibilityDescription: "Bundles")!
  }

  public override func loadView() {
    view = NSHostingView(rootView: BundlesView())
  }
}
