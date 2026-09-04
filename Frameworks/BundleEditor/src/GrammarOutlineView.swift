import SwiftUI

/// The grammar's rules as an outline: the patterns with their nesting, then
/// the repository by name, then the injections by selector. Selecting a row
/// shows that rule's form.
struct GrammarOutlineView: View {
  let document: GrammarDocument
  @Binding var selection: GrammarRule.ID?

  var body: some View {
    List(selection: $selection) {
      Section("Patterns") {
        ForEach(document.patterns) { rule in
          GrammarOutlineRow(rule: rule)
        }
      }
      if !document.repository.isEmpty {
        Section("Repository") {
          ForEach(document.repository) { entry in
            GrammarOutlineRow(rule: entry.rule, label: entry.name)
          }
        }
      }
      if !document.injections.isEmpty {
        Section("Injections") {
          ForEach(document.injections) { entry in
            GrammarOutlineRow(rule: entry.rule, label: entry.name)
          }
        }
      }
    }
    .listStyle(.sidebar)
  }
}
