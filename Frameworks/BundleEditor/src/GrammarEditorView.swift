import SwiftUI

/// The grammar editor: the outline of rules on the left, the selected rule's
/// form on the right, and what the validator finds along the bottom.
struct GrammarEditorView: View {
  let document: GrammarDocument
  @State private var selection: GrammarRule.ID?

  var body: some View {
    VStack(spacing: 0) {
      HSplitView {
        GrammarOutlineView(document: document, selection: $selection)
          .frame(minWidth: 180, idealWidth: 260)
        Group {
          if let rule = selection.flatMap(document.rule(with:)) {
            GrammarRuleFormView(rule: rule, entry: document.namedRule(for: rule.id))
          } else {
            Text("Select a rule")
              .foregroundStyle(.secondary)
              .frame(maxWidth: .infinity, maxHeight: .infinity)
          }
        }
        .frame(minWidth: 320)
      }
      GrammarIssuesView(issues: document.issues)
    }
  }
}
