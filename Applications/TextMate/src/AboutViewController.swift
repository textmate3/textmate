import AppKit
import OakFoundation
import SwiftUI

/// Hosts the SwiftUI About page inside the AppKit About window. Objective-C
/// creates it as TMAboutViewController and takes its view, and never sees
/// SwiftUI.
@objc(TMAboutViewController)
public final class AboutViewController: NSViewController {
	public override func loadView() {
		let hostingView = NSHostingView(rootView: AboutView(info: ApplicationInfo.main))
		// A hosting view that is a window's content view rewrites the window's
		// minimum and maximum size from its content. The window sets its own.
		hostingView.sizingOptions = []
		view = hostingView
	}
}
