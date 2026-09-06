import AppKit
import SwiftUI

/// The Objective-C face of the Files pane. The preferences window treats it
/// like any other pane: a view controller with an identifier, a title and a
/// toolbar image. Objective-C never sees SwiftUI.
@objc(TMFilesPaneController)
@MainActor
public final class FilesPaneController: NSViewController, PreferencesPaneProtocol {
  public init() {
    super.init(nibName: nil, bundle: nil)
    identifier = NSUserInterfaceItemIdentifier("Files")
    title = "Files"
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("The Files pane is not loaded from a nib.")
  }

  // The protocol is not actor isolated, so this cannot touch the title.
  @objc nonisolated public var toolbarItemImage: NSImage {
    NSImage(systemSymbolName: "doc.on.doc", accessibilityDescription: "Files")!
  }

  public override func loadView() {
    view = NSHostingView(rootView: FilesView())
  }
}
