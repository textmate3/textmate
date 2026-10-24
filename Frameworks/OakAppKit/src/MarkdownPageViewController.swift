import AppKit
import SwiftUI

/// Hosts a MarkdownView over one Markdown file for an AppKit window.
/// The window creates it by file URL, takes its view, and never sees SwiftUI.
/// The About window uses it for Changes and Legal.
/// A file that cannot be read or parsed shows the reason in its place rather than an empty page.
@objc(OakMarkdownPageViewController)
@MainActor
public final class MarkdownPageViewController: NSViewController {
  private let fileURL: URL

  @objc public init(fileURL: URL) {
    self.fileURL = fileURL
    super.init(nibName: nil, bundle: nil)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("MarkdownPageViewController is created in code")
  }

  public override func loadView() {
    // As the window's content view, the hosting view hands the window a minimum size taken from the content.
    // Every page of the About window declares the same 560 by 200.
    do {
      let markdown = try String(contentsOf: fileURL, encoding: .utf8)
      let document = try MarkdownDocument(markdown: markdown)
      view = NSHostingView(rootView: MarkdownView(document: document).frame(minWidth: 560, minHeight: 200))
    } catch {
      let unavailable = ContentUnavailableView("Nothing to Show", systemImage: "doc", description: Text(error.localizedDescription))
      view = NSHostingView(rootView: unavailable.frame(minWidth: 560, minHeight: 200))
    }
  }
}
