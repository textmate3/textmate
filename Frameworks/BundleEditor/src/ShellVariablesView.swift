import SwiftUI

/// The shell variables as rows: a checkbox for whether the variable is set,
/// its name, its value, and a button to take the row away. A button below
/// adds one.
struct ShellVariablesView: View {
  let document: PreferencesDocument

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      ForEach(document.shellVariables) { variable in
        ShellVariableRow(variable: variable) {
          document.removeShellVariable(variable.id)
        }
      }
      Button("Add Variable") {
        document.addShellVariable()
      }
    }
  }
}

private struct ShellVariableRow: View {
  @Bindable var variable: ShellVariable
  let remove: () -> Void

  var body: some View {
    HStack(spacing: 6) {
      Toggle("", isOn: $variable.enabled)
        .toggleStyle(.checkbox)
        .labelsHidden()
        .help("Set this variable")
      TextField("name", text: $variable.name)
        .labelsHidden()
        .font(.body.monospaced())
        .frame(width: 200)
      TextField("value", text: $variable.value)
        .labelsHidden()
        .font(.body.monospaced())
      Button {
        remove()
      } label: {
        Image(systemName: "minus.circle")
      }
      .buttonStyle(.borderless)
      .help("Remove this variable")
    }
  }
}
