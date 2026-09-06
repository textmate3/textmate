import AppKit
import SwiftUI

/// The file browser's starting folder: the desktop, home, the root of the
/// disk, and whatever else was picked through Other, each with its icon. The
/// binding holds the folder as a URL string, the way the default has always
/// been stored.
struct FolderPopUp: NSViewRepresentable {
  @Binding var url: String

  @MainActor
  final class Coordinator: NSObject {
    var url: Binding<String>
    weak var button: NSPopUpButton?

    init(url: Binding<String>) {
      self.url = url
    }

    private let standardFolders: [URL] = [
      FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first,
      FileManager.default.homeDirectoryForCurrentUser,
      URL(fileURLWithPath: "/", isDirectory: true),
    ].compactMap { $0 }

    private var current: URL {
      URL(string: url.wrappedValue) ?? FileManager.default.homeDirectoryForCurrentUser
    }

    func rebuild(_ button: NSPopUpButton) {
      let menu = NSMenu()
      let current = current
      if !standardFolders.contains(current) {
        menu.addItem(item(for: current))
        menu.addItem(.separator())
      }
      for folder in standardFolders {
        menu.addItem(item(for: folder))
      }
      menu.addItem(.separator())
      let other = NSMenuItem(title: "Other…", action: #selector(chooseOther(_:)), keyEquivalent: "")
      other.target = self
      menu.addItem(other)

      button.menu = menu
      let index = menu.items.firstIndex { ($0.representedObject as? URL) == current } ?? 0
      button.selectItem(at: index)
    }

    private func item(for folder: URL) -> NSMenuItem {
      let item = NSMenuItem(title: FileManager.default.displayName(atPath: folder.path), action: #selector(choose(_:)), keyEquivalent: "")
      item.target = self
      item.representedObject = folder
      if let icon = (try? folder.resourceValues(forKeys: [.effectiveIconKey]))?.effectiveIcon as? NSImage, let copy = icon.copy() as? NSImage {
        copy.size = NSSize(width: 16, height: 16)
        item.image = copy
      }
      return item
    }

    @objc func choose(_ item: NSMenuItem) {
      guard let folder = item.representedObject as? URL else { return }
      url.wrappedValue = folder.absoluteString
    }

    @objc func chooseOther(_ item: NSMenuItem) {
      guard let button, let window = button.window else { return }
      let panel = NSOpenPanel()
      panel.canChooseFiles = false
      panel.canChooseDirectories = true
      panel.beginSheetModal(for: window) { response in
        MainActor.assumeIsolated {
          if response == .OK, let folder = panel.url {
            self.url.wrappedValue = folder.absoluteString
          }
          // A cancel leaves Other showing as the choice until the menu is made again.
          self.rebuild(button)
        }
      }
    }
  }

  func makeCoordinator() -> Coordinator {
    Coordinator(url: $url)
  }

  func makeNSView(context: Context) -> NSPopUpButton {
    let button = NSPopUpButton(frame: .zero, pullsDown: false)
    button.setContentHuggingPriority(.defaultLow, for: .horizontal)
    context.coordinator.button = button
    return button
  }

  func updateNSView(_ button: NSPopUpButton, context: Context) {
    context.coordinator.url = $url
    context.coordinator.rebuild(button)
  }
}
