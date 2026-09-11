import AppKit
import SwiftUI

/// The Preferences window with its panes in a sidebar, the way System Settings
/// arranges them, in place of a row of toolbar tabs.
///
/// This is a spike, reached only when the `preferencesUsesSidebar` default is
/// on. The tabs are what the window does otherwise, and nothing about them
/// changes here.
///
/// Only the container is new. Each of the six panes is already a SwiftUI view
/// behind a view controller, and each is shown here exactly as it is, so the
/// question this answers is whether the arrangement is right, not whether the
/// panes survive being rebuilt.
@objc(TMPreferencesSidebarController)
public final class PreferencesSidebarController: NSViewController {
  private let panes: [Pane]
  private let selectedPaneDefault: String

  /// A pane as the sidebar needs it: what to call it, what to draw beside it,
  /// and the view controller that already knows how to be it.
  fileprivate struct Pane: Identifiable {
    let id: String
    let title: String
    let image: NSImage?
    let controller: NSViewController
  }

  /// Takes the same pane controllers the tabbed window builds, so the two
  /// arrangements can be compared without either owning the panes.
  @objc public init(paneControllers: [NSViewController], selectedPaneDefault: String) {
    self.selectedPaneDefault = selectedPaneDefault
    self.panes = paneControllers.map { controller in
      Pane(
        id: controller.identifier?.rawValue ?? controller.title ?? "",
        title: controller.title ?? controller.identifier?.rawValue ?? "",
        image: (controller as? any PreferencesPaneProtocol)?.toolbarItemImage,
        controller: controller
      )
    }
    super.init(nibName: nil, bundle: nil)
    title = "Preferences"
  }

  required init?(coder: NSCoder) {
    fatalError("The Preferences sidebar is not loaded from a nib.")
  }

  public override func loadView() {
    // The pane controllers are children so their views stay in the responder
    // chain and their life cycle methods still run, which is what the tabbed
    // container did for them too.
    for pane in panes {
      addChild(pane.controller)
    }

    let remembered = UserDefaults.standard.string(forKey: selectedPaneDefault)
    let initial = panes.contains(where: { $0.id == remembered }) ? remembered : panes.first?.id

    view = NSHostingView(
      rootView: PreferencesSidebarView(
        panes: panes,
        initialSelection: initial,
        selectedPaneDefault: selectedPaneDefault
      )
    )
  }
}

/// Shows the selected pane's view, one at a time.
///
/// A container whose single subview is swapped, rather than an
/// `NSViewControllerRepresentable` handing back the controller. Two reasons,
/// and the first is what made switching panes do nothing at all.
///
/// SwiftUI updates a representable in place when only its inputs change, so
/// `makeNSViewController` runs once and every later pane arrives at
/// `updateNSViewController`. Handing back a different controller from `make`
/// is never asked for, so the first pane stays on screen forever.
///
/// A view controller also has one parent, and these are already children of
/// the sidebar controller so their life cycle runs. Letting SwiftUI parent
/// them as well would take them away from it.
private struct PaneHost: NSViewRepresentable {
  let controller: NSViewController

  func makeNSView(context: Context) -> NSView {
    NSView()
  }

  func updateNSView(_ container: NSView, context: Context) {
    PaneContainer.show(controller.view, in: container)
  }
}

/// The swap itself, apart from SwiftUI, so it can be tested. Switching panes
/// doing nothing was the whole of this spike's first bug, and a bug that
/// visible deserves something that would have caught it.
public enum PaneContainer {
  /// Makes the pane's view the container's only subview, pinned across and to
  /// the top. Does nothing when it is already there, so a redraw does not tear
  /// the view out and put it back.
  @MainActor
  public static func show(_ paneView: NSView, in container: NSView) {
    guard container.subviews.first !== paneView else { return }

    for subview in container.subviews {
      subview.removeFromSuperview()
    }

    paneView.translatesAutoresizingMaskIntoConstraints = false
    container.addSubview(paneView)

    // The height is left to the pane, since a sidebar window is taller than
    // the panes were laid out for and stretching them would spread their rows
    // rather than fill the space.
    NSLayoutConstraint.activate([
      paneView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
      paneView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
      paneView.topAnchor.constraint(equalTo: container.topAnchor),
    ])
  }
}

private struct PreferencesSidebarView: View {
  fileprivate let panes: [PreferencesSidebarController.Pane]
  let initialSelection: String?
  let selectedPaneDefault: String

  @State private var selection: String?

  var body: some View {
    NavigationSplitView {
      List(panes, selection: $selection) { pane in
        Label {
          Text(pane.title)
        } icon: {
          if let image = pane.image {
            Image(nsImage: image)
          }
        }
      }
      .navigationSplitViewColumnWidth(min: 170, ideal: 190, max: 260)
    } detail: {
      if let pane = panes.first(where: { $0.id == selection }) {
        PaneHost(controller: pane.controller)
          .navigationTitle(pane.title)
          // The panes were laid out for a narrower window than a sidebar one,
          // so they sit at the top rather than stretching to fill the height.
          .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
      } else {
        Text("Select a pane")
          .foregroundStyle(.secondary)
          .frame(maxWidth: .infinity, maxHeight: .infinity)
      }
    }
    .onAppear {
      selection = initialSelection
    }
    .onChange(of: selection) { _, newValue in
      guard let newValue else { return }
      UserDefaults.standard.set(newValue, forKey: selectedPaneDefault)
    }
  }
}
