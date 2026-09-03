import AppKit
import OakFoundation
import SwiftUI

/// Hosts the SwiftUI About page inside the AppKit About window. Objective-C
/// creates it as TMAboutViewController and takes its view, and never sees
/// SwiftUI.
@objc(TMAboutViewController)
public final class AboutViewController: NSViewController {
	public override func loadView() {
		view = NSHostingView(rootView: AboutView(info: ApplicationInfo.main))
	}
}
