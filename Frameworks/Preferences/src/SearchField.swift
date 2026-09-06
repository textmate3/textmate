import AppKit
import SwiftUI

/// The small search field, the AppKit one, since SwiftUI's search lives in a
/// navigation stack the pane does not have. The binding follows every keystroke.
struct SearchField: NSViewRepresentable {
  @Binding var text: String

  @MainActor
  final class Coordinator: NSObject, NSSearchFieldDelegate {
    var text: Binding<String>

    init(text: Binding<String>) {
      self.text = text
    }

    func controlTextDidChange(_ notification: Notification) {
      guard let field = notification.object as? NSSearchField else { return }
      text.wrappedValue = field.stringValue
    }
  }

  func makeCoordinator() -> Coordinator {
    Coordinator(text: $text)
  }

  func makeNSView(context: Context) -> NSSearchField {
    let field = NSSearchField()
    field.controlSize = .small
    field.font = NSFont.systemFont(ofSize: NSFont.systemFontSize(for: .small))
    field.delegate = context.coordinator
    return field
  }

  func updateNSView(_ field: NSSearchField, context: Context) {
    context.coordinator.text = $text
    if field.stringValue != text {
      field.stringValue = text
    }
  }
}
