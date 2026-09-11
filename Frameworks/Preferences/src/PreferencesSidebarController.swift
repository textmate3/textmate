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

/// Hosts a pane's existing view controller inside SwiftUI.
private struct PaneHost: NSViewControllerRepresentable {
  let controller: NSViewController

  func makeNSViewController(context: Context) -> NSViewController {
    controller
  }

  func updateNSViewController(_ controller: NSViewController, context: Context) {
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
        .tag(pane.id)
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
