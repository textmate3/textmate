import SwiftUI

/// The macro editor: the steps on the left, the selected step on the right,
/// and what the validator finds along the bottom.
struct MacroEditorView: View {
  let document: MacroDocument
  @State private var selection: MacroStep.ID?

  var body: some View {
    VStack(spacing: 0) {
      HSplitView {
        MacroStepsView(document: document, selection: $selection)
          .frame(minWidth: 220, idealWidth: 320, maxWidth: 480)
        Group {
          if let step = selection.flatMap(document.step(with:)) {
            MacroStepFormView(step: step)
          } else {
            Text("Select a step")
              .foregroundStyle(.secondary)
              .frame(maxWidth: .infinity, maxHeight: .infinity)
          }
        }
        .frame(minWidth: 320, maxWidth: .infinity)
      }
      .frame(minHeight: 200)
      SchemaIssuesView(issues: document.issues)
    }
  }
}
