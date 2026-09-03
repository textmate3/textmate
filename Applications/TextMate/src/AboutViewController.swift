import AppKit
import OakFoundation
import SwiftUI

/// Hosts the SwiftUI About page inside the AppKit About window. Objective-C
/// creates it as TMAboutViewController and takes its view, and never sees
/// SwiftUI.
@objc(TMAboutViewController)
public final class AboutViewController: NSViewController {
  public override func loadView() {
    // As the window's content view, the hosting view hands the window a
    // minimum size taken from the SwiftUI content, which AboutView declares.
    view = NSHostingView(rootView: AboutView(info: ApplicationInfo.main))
  }
}
