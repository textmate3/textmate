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

  /// The window hands focus to the first key view, which is the search
  /// field. The table is the thing to arrive on, as it always was.
  public override func viewDidAppear() {
    super.viewDidAppear()
    if let table = view.firstDescendant(of: NSTableView.self) {
      view.window?.makeFirstResponder(table)
    }
  }
}

extension NSView {
  /// The first view of the kind below this one, depth first.
  func firstDescendant<View: NSView>(of kind: View.Type) -> View? {
    for subview in subviews {
      if let match = subview as? View ?? subview.firstDescendant(of: kind) {
        return match
      }
    }
    return nil
  }
}
