import AppKit
import SwiftUI

/// The Objective-C face of the Projects pane. The preferences window treats
/// it like any other pane: a view controller with an identifier, a title and
/// a toolbar image. Objective-C never sees SwiftUI.
@objc(TMProjectsPaneController)
@MainActor
public final class ProjectsPaneController: NSViewController, PreferencesPaneProtocol {
  public init() {
    super.init(nibName: nil, bundle: nil)
    identifier = NSUserInterfaceItemIdentifier("Projects")
    title = "Projects"
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("The Projects pane is not loaded from a nib.")
  }

  // The protocol is not actor isolated, so this cannot touch the title.
  @objc nonisolated public var toolbarItemImage: NSImage {
    NSImage(systemSymbolName: "folder", accessibilityDescription: "Projects")!
  }

  public override func loadView() {
    view = NSHostingView(rootView: ProjectsView())
  }
}
