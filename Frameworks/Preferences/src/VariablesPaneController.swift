import AppKit
import SwiftUI

/// The Objective-C face of the Variables pane. The preferences window treats
/// it like any other pane: a view controller with an identifier, a title and
/// a toolbar image. Objective-C never sees SwiftUI.
@objc(TMVariablesPaneController)
@MainActor
public final class VariablesPaneController: NSViewController, PreferencesPaneProtocol {
  public init() {
    super.init(nibName: nil, bundle: nil)
    identifier = NSUserInterfaceItemIdentifier("Variables")
    title = "Variables"
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("The Variables pane is not loaded from a nib.")
  }

  // The protocol is not actor isolated, so this cannot touch the title.
  @objc nonisolated public var toolbarItemImage: NSImage {
    NSImage(systemSymbolName: "dollarsign.circle", accessibilityDescription: "Variables")!
  }

  public override func loadView() {
    view = NSHostingView(rootView: VariablesView())
  }
}
