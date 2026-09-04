import BundleSchema
import SwiftUI

/// The strip under the outline: add a rule of a chosen shape after the
/// selection or inside it, add a repository rule, remove the selection, or
/// move it up and down within its list.
struct GrammarOutlineBar: View {
  let document: GrammarDocument
  let selection: GrammarRule.ID?
  let actions: GrammarOutlineActions

  var body: some View {
    HStack(spacing: 4) {
      Menu {
        Section("After the selection") {
          Button("Match Rule") { actions.add(.match, .after(selection)) }
          Button("Begin and End Rule") { actions.add(.beginEnd, .after(selection)) }
          Button("Include") { actions.add(.include, .after(selection)) }
        }
        if let selection, document.rule(with: selection) != nil {
          Section("Inside the selection") {
            Button("Nested Match Rule") { actions.add(.match, .inside(selection)) }
            Button("Nested Begin and End Rule") { actions.add(.beginEnd, .inside(selection)) }
            Button("Nested Include") { actions.add(.include, .inside(selection)) }
          }
        }
        Section {
          Button("Repository Rule") { actions.add(.match, .repository) }
        }
      } label: {
        Image(systemName: "plus")
      }
      .menuStyle(.borderlessButton)
      .fixedSize()
      .help("Add a rule")

      Button {
        if let selection { actions.remove(selection) }
      } label: {
        Image(systemName: "minus")
      }
      .disabled(selection == nil)
      .help("Remove the selected rule")

      Spacer()

      Button {
        if let selection { actions.move(selection, -1) }
      } label: {
        Image(systemName: "chevron.up")
      }
      .disabled(!(selection.map { document.canMove($0, by: -1) } ?? false))
      .help("Move the selected rule up")

      Button {
        if let selection { actions.move(selection, 1) }
      } label: {
        Image(systemName: "chevron.down")
      }
      .disabled(!(selection.map { document.canMove($0, by: 1) } ?? false))
      .help("Move the selected rule down")
    }
    .buttonStyle(.borderless)
    .padding(.horizontal, 8)
    .padding(.vertical, 4)
  }
}
