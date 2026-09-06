import AppKit
import SwiftUI

/// Where the mate command goes: the two usual places, whatever else was
/// picked through Other, and Other itself, which opens a save panel. The
/// binding holds the path with a tilde, the way the pop up shows it.
struct InstallPathPopUp: NSViewRepresentable {
  @Binding var path: String

  static let usualPaths = ["/usr/local/bin/mate", "~/bin/mate"]

  @MainActor
  final class Coordinator: NSObject {
    var path: Binding<String>
    weak var button: NSPopUpButton?

    init(path: Binding<String>) {
      self.path = path
    }

    func rebuild(_ button: NSPopUpButton) {
      let menu = NSMenu()
      let current = path.wrappedValue
      if !InstallPathPopUp.usualPaths.contains(current) {
        menu.addItem(item(for: current))
      }
      for usual in InstallPathPopUp.usualPaths {
        menu.addItem(item(for: usual))
      }
      menu.addItem(.separator())
      let other = NSMenuItem(title: "Other…", action: #selector(chooseOther(_:)), keyEquivalent: "")
      other.target = self
      menu.addItem(other)

      button.menu = menu
      let index = menu.items.firstIndex { ($0.representedObject as? String) == current } ?? 0
      button.selectItem(at: index)
    }

    private func item(for path: String) -> NSMenuItem {
      let item = NSMenuItem(title: path, action: #selector(choose(_:)), keyEquivalent: "")
      item.target = self
      item.representedObject = path
      return item
    }

    @objc func choose(_ item: NSMenuItem) {
      guard let chosen = item.representedObject as? String else { return }
      path.wrappedValue = chosen
    }

    @objc func chooseOther(_ item: NSMenuItem) {
      guard let button, let window = button.window else { return }
      let panel = NSSavePanel()
      panel.nameFieldStringValue = "mate"
      panel.beginSheetModal(for: window) { response in
        MainActor.assumeIsolated {
          if response == .OK, let chosen = panel.url {
            self.path.wrappedValue = (chosen.path as NSString).abbreviatingWithTildeInPath
          }
          // A cancel leaves Other showing as the choice until the menu is made again.
          self.rebuild(button)
        }
      }
    }
  }

  func makeCoordinator() -> Coordinator {
    Coordinator(path: $path)
  }

  func makeNSView(context: Context) -> NSPopUpButton {
    let button = NSPopUpButton(frame: .zero, pullsDown: false)
    button.setContentHuggingPriority(.defaultLow, for: .horizontal)
    context.coordinator.button = button
    return button
  }

  func updateNSView(_ button: NSPopUpButton, context: Context) {
    context.coordinator.path = $path
    context.coordinator.rebuild(button)
  }
}
