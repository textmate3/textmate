import SwiftUI

/// One rule in the outline, disclosing its nested patterns. A repository entry
/// or an injection shows its name rather than the rule's own title. The
/// context menu offers what the bar under the outline offers, for this rule.
struct GrammarOutlineRow: View {
  let rule: GrammarRule
  var label: String?
  @Binding var expanded: Set<GrammarRule.ID>
  let actions: GrammarOutlineActions

  var body: some View {
    let children = rule.outlineChildren
    if children.isEmpty {
      row
    } else {
      DisclosureGroup(isExpanded: isExpanded) {
        ForEach(children, id: \.rule.id) { child in
          GrammarOutlineRow(rule: child.rule, label: child.label, expanded: $expanded, actions: actions)
        }
      } label: {
        row
      }
    }
  }

  private var isExpanded: Binding<Bool> {
    Binding(
      get: { expanded.contains(rule.id) },
      set: { open in
        if open { expanded.insert(rule.id) } else { expanded.remove(rule.id) }
      }
    )
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
    .contextMenu {
      Button("Add Match Rule After") { actions.add(.match, .after(rule.id)) }
      Button("Add Begin and End Rule After") { actions.add(.beginEnd, .after(rule.id)) }
      Button("Add Include After") { actions.add(.include, .after(rule.id)) }
      Divider()
      Button("Add Nested Match Rule") { actions.add(.match, .inside(rule.id)) }
      Button("Add Nested Begin and End Rule") { actions.add(.beginEnd, .inside(rule.id)) }
      Button("Add Nested Include") { actions.add(.include, .inside(rule.id)) }
      Divider()
      Button("Move Up") { actions.move(rule.id, -1) }
      Button("Move Down") { actions.move(rule.id, 1) }
      Divider()
      Button("Remove", role: .destructive) { actions.remove(rule.id) }
    }
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
