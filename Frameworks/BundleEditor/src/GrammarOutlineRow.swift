import SwiftUI

/// One rule in the outline, disclosing its nested patterns. A repository entry
/// or an injection shows its name rather than the rule's own title.
struct GrammarOutlineRow: View {
  let rule: GrammarRule
  var label: String?

  var body: some View {
    if rule.patterns.isEmpty {
      row
    } else {
      DisclosureGroup {
        ForEach(rule.patterns) { child in
          GrammarOutlineRow(rule: child)
        }
      } label: {
        row
      }
    }
  }

  private var row: some View {
    HStack {
      Text(label ?? rule.title)
        .lineLimit(1)
        .truncationMode(.middle)
      Spacer()
      Text(shapeLabel)
        .font(.caption)
        .foregroundStyle(.secondary)
    }
    .tag(rule.id)
  }

  private var shapeLabel: String {
    switch rule.shape {
    case .match: "match"
    case .beginEnd: "begin end"
    case .beginWhile: "begin while"
    case .include: "include"
    case .patterns: "patterns"
    case nil: ""
    }
  }
}
