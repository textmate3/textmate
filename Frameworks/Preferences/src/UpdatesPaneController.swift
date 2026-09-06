import AppKit
import SwiftUI

/// The Objective-C face of the Updates pane. The preferences window treats
/// it like any other pane: a view controller with an identifier, a title and
/// a toolbar image. Objective-C never sees SwiftUI.
@objc(TMUpdatesPaneController)
@MainActor
public final class UpdatesPaneController: NSViewController, PreferencesPaneProtocol {
  public init() {
    super.init(nibName: nil, bundle: nil)
    identifier = NSUserInterfaceItemIdentifier("Updates")
    title = "Updates"
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("The Updates pane is not loaded from a nib.")
  }

  // The protocol is not actor isolated, so this cannot touch the title.
  @objc nonisolated public var toolbarItemImage: NSImage {
    NSImage(systemSymbolName: "arrow.triangle.2.circlepath", accessibilityDescription: "Updates")!
  }

  public override func loadView() {
    view = NSHostingView(rootView: UpdatesView())
  }
}
