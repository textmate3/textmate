import SwiftUI

/// A text field over one settings key, the global .tm_properties value. It
/// reads the value when made and writes it back on return or when focus
/// leaves, not on every keystroke, since each write is a file.
struct SettingsTextField: View {
  let key: String
  @State private var text: String
  @FocusState private var isFocused: Bool

  init(key: String) {
    self.key = key
    _text = State(initialValue: PreferencesSettings.string(forKey: key) ?? "")
  }

  var body: some View {
    TextField("", text: $text)
      .labelsHidden()
      .focused($isFocused)
      .onSubmit(save)
      .onChange(of: isFocused) { _, isFocused in
        if !isFocused {
          save()
        }
      }
  }

  private func save() {
    PreferencesSettings.setString(text, forKey: key)
  }
}
