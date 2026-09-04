import SwiftUI

/// The grammar's rules as an outline: the patterns with their nesting, then
/// the repository by name, then the injections by selector. Selecting a row
/// shows that rule's form. The bar underneath adds, removes and moves rules,
/// and each row's context menu offers the same.
struct GrammarOutlineView: View {
  let document: GrammarDocument
  @Binding var selection: GrammarRule.ID?

  /// The rules whose nested patterns are shown. A rule that gets a nested
  /// rule added opens, so the new rule is in view.
  @State private var expanded: Set<GrammarRule.ID> = []

  var body: some View {
    VStack(spacing: 0) {
      List(selection: $selection) {
        Section("Patterns") {
          ForEach(document.patterns) { rule in
            GrammarOutlineRow(rule: rule, expanded: $expanded, actions: actions)
          }
        }
        if !document.repository.isEmpty {
          Section("Repository") {
            ForEach(document.repository) { entry in
              GrammarOutlineRow(rule: entry.rule, label: entry.name, expanded: $expanded, actions: actions)
            }
          }
        }
        if !document.injections.isEmpty {
          Section("Injections") {
            ForEach(document.injections) { entry in
              GrammarOutlineRow(rule: entry.rule, label: entry.name, expanded: $expanded, actions: actions)
            }
          }
        }
      }
      // Not the sidebar style: its translucency lets whatever is behind the
      // window show through a pane that is not at the window's edge.
      .listStyle(.inset)
      Divider()
      GrammarOutlineBar(document: document, selection: selection, actions: actions)
    }
  }

  private var actions: GrammarOutlineActions {
    GrammarOutlineActions(
      add: { shape, placement in
        let rule = GrammarRule.blank(shape)
        switch placement {
        case .after(let id):
          document.insert(rule, after: id)
        case .inside(let id):
          document.insert(rule, into: id)
          expanded.insert(id)
        case .repository:
          _ = document.addRepositoryRule(named: "new-rule")
        }
        selection = placement == .repository ? document.repository.last?.rule.id : rule.id
      },
      remove: { id in
        document.remove(id)
        if selection == id { selection = nil }
      },
      move: { id, offset in document.move(id, by: offset) }
    )
  }
}
