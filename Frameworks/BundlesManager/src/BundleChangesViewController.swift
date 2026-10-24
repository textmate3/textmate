import AppKit
import SwiftUI

/// Hosts the Bundles tab for the Objective-C About window.
/// The window hands it the `Changes.json` of each installed bundle, takes its view, and never sees SwiftUI.
/// The files are read once, when the view loads, so the window makes a new one each time the tab is shown and the list is as current as the bundles are.
@objc(BundleChangesViewController)
@MainActor
public final class BundleChangesViewController: NSViewController {
  private let changesFiles: [URL]

  @objc public init(changesFiles: [URL]) {
    self.changesFiles = changesFiles
    super.init(nibName: nil, bundle: nil)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("BundleChangesViewController is created in code")
  }

  public override func loadView() {
    let bundles = changesFiles.compactMap(BundleChanges.read)
    let year = Calendar.current.component(.year, from: .now)
    let log = BundleChangesLog(bundles: bundles, year: year)
    // As the window's content view, the hosting view hands the window a minimum size taken from the content.
    // Every page of the About window declares the same 560 by 200.
    view = NSHostingView(rootView: BundleChangesView(log: log).frame(minWidth: 560, minHeight: 200))
  }
}
