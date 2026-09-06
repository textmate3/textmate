import AppKit
import SwiftUI

/// A choice in a pop up: what a person reads and the value the setting
/// stores. A nil value is a separator line.
struct PopUpChoice: Equatable {
  let title: String
  let value: String?

  init(_ title: String, _ value: String) {
    self.title = title
    self.value = value
  }

  private init() {
    title = ""
    value = nil
  }

  static let separator = PopUpChoice()
}

/// An AppKit pop up button over string values. SwiftUI's own menu picker
/// keeps its content width on the Mac, whatever frame it is given, and the
/// preference panes want every pop up to fill its column.
struct PopUpPicker: NSViewRepresentable {
  @Binding var selection: String
  let choices: [PopUpChoice]

  @MainActor
  final class Coordinator: NSObject {
    var selection: Binding<String>
    var choices: [PopUpChoice] = []

    init(selection: Binding<String>) {
      self.selection = selection
    }

    @objc func choose(_ button: NSPopUpButton) {
      guard let value = button.selectedItem?.representedObject as? String else { return }
      if selection.wrappedValue != value {
        selection.wrappedValue = value
      }
    }
  }

  func makeCoordinator() -> Coordinator {
    Coordinator(selection: $selection)
  }

  func makeNSView(context: Context) -> NSPopUpButton {
    let button = NSPopUpButton(frame: .zero, pullsDown: false)
    button.target = context.coordinator
    button.action = #selector(Coordinator.choose(_:))
    button.setContentHuggingPriority(.defaultLow, for: .horizontal)
    return button
  }

  func updateNSView(_ button: NSPopUpButton, context: Context) {
    context.coordinator.selection = $selection
    if context.coordinator.choices != choices {
      context.coordinator.choices = choices
      button.menu?.removeAllItems()
      for choice in choices {
        guard let value = choice.value else {
          button.menu?.addItem(.separator())
          continue
        }
        let item = NSMenuItem(title: choice.title, action: nil, keyEquivalent: "")
        item.representedObject = value
        button.menu?.addItem(item)
      }
    }

    let current = button.selectedItem?.representedObject as? String
    if current != selection {
      let index = button.itemArray.firstIndex { ($0.representedObject as? String) == selection } ?? -1
      button.selectItem(at: index)
    }
  }
}
