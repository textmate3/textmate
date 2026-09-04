import SwiftUI

/// One line of a captures table: the capture's number or name, and the scope
/// it gets. A capture with its own patterns says so, since those are edited
/// from the outline.
struct GrammarCaptureRow: View {
  @Bindable var capture: GrammarCapture

  var body: some View {
    HStack {
      Text(capture.key)
        .frame(width: 40, alignment: .trailing)
        .foregroundStyle(.secondary)
      TextField("scope", text: Binding(get: { capture.rule.scopeName ?? "" }, set: { capture.rule.scopeName = $0.isEmpty ? nil : $0 }))
        .labelsHidden()
        .font(.body.monospaced())
        .multilineTextAlignment(.leading)
      if !capture.rule.patterns.isEmpty {
        Text("\(capture.rule.patterns.count) patterns")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    }
  }
}
