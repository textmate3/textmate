import AppKit
import SwiftUI

/// The encoding pop up, the AppKit one, since it carries the list a person
/// has chosen to see and the Customize List window that edits it. The binding
/// follows the button's encoding both ways.
struct EncodingPopUp: NSViewRepresentable {
  @Binding var encoding: String

  final class Coordinator {
    var observation: NSKeyValueObservation?
  }

  func makeCoordinator() -> Coordinator {
    Coordinator()
  }

  func makeNSView(context: Context) -> OakEncodingPopUpButton {
    let button = OakEncodingPopUpButton()
    button.encoding = encoding

    let binding = $encoding
    context.coordinator.observation = button.observe(\.encoding, options: [.new]) { _, change in
      guard let value = change.newValue ?? nil else { return }
      if binding.wrappedValue != value {
        binding.wrappedValue = value
      }
    }
    return button
  }

  func updateNSView(_ button: OakEncodingPopUpButton, context: Context) {
    if button.encoding != encoding {
      button.encoding = encoding
    }
  }
}
