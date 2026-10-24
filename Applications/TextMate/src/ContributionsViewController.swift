import AppKit
import SwiftUI

/// Hosts the Contributions page inside the AppKit About window.
/// Objective-C creates it as TMContributionsViewController and takes its view, and never sees SwiftUI.
/// The data is the Contributions directory in the application's resources, written by script/update_contributions.
@objc(TMContributionsViewController)
public final class ContributionsViewController: NSViewController {
  public override func loadView() {
    let resources = Bundle.main.resourceURL ?? Bundle.main.bundleURL
    let directory = resources.appending(path: "Contributions")
    // As the window's content view, the hosting view hands the window a minimum size taken from the content.
    // Every page of the About window declares the same 560 by 200.
    view = NSHostingView(rootView: ContributionsView(directory: directory).frame(minWidth: 560, minHeight: 200))
  }
}
