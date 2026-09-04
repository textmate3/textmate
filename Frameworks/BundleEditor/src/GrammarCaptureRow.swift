import SwiftUI

/// One line of a captures table: the capture's number or name, the scope it
/// gets, and a button to remove it. A capture with its own patterns says so,
/// since those are edited from the outline.
struct GrammarCaptureRow: View {
  @Bindable var capture: GrammarCapture
  let onRemove: () -> Void

  var body: some View {
    HStack {
      TextField("key", text: $capture.key)
        .labelsHidden()
        .frame(width: 48)
        .multilineTextAlignment(.trailing)
      TextField("scope", text: Binding(get: { capture.rule.scopeName ?? "" }, set: { capture.rule.scopeName = $0.isEmpty ? nil : $0 }))
        .labelsHidden()
        .font(.body.monospaced())
        .multilineTextAlignment(.leading)
      if !capture.rule.patterns.isEmpty {
        Text("\(capture.rule.patterns.count) patterns")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      Button(action: onRemove) {
        Image(systemName: "minus.circle")
      }
      .buttonStyle(.borderless)
      .help("Remove this capture")
    }
  }
}
