import SwiftUI

/// The Variables pane: a table of the environment variables handed to bundle
/// commands, each one switchable, with add and remove below. Naming or
/// valuing a row switches it on, the way it always has.
struct VariablesView: View {
  @State private var variables = EnvironmentVariables()
  @State private var selection: EnvironmentVariable.ID?
  @FocusState private var focusedName: EnvironmentVariable.ID?

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Table($variables.rows, selection: $selection) {
        TableColumn("") { $row in
          Toggle("", isOn: $row.isEnabled)
            .labelsHidden()
            .controlSize(.small)
        }
        .width(20)

        TableColumn("Variable Name") { $row in
          TextField("", text: $row.name)
            .labelsHidden()
            .focused($focusedName, equals: row.id)
            .onSubmit { row.isEnabled = true }
        }
        .width(min: 100, ideal: 140)

        TableColumn("Value") { $row in
          TextField("", text: $row.value)
            .labelsHidden()
            .onSubmit { row.isEnabled = true }
        }
      }
      .onDeleteCommand(perform: removeSelected)

      HStack(spacing: -1) {
        Button(action: add) {
          Image(systemName: "plus")
        }
        Button(action: removeSelected) {
          Image(systemName: "minus")
        }
        .disabled(selection == nil)
      }
      .buttonStyle(.bordered)
      .controlSize(.small)
    }
    .padding(20)
    .frame(width: 600, height: 400)
  }

  private func add() {
    let id = variables.add(above: selection)
    selection = id
    focusedName = id
  }

  private func removeSelected() {
    guard let selection else { return }
    self.selection = variables.remove(selection)
  }
}
