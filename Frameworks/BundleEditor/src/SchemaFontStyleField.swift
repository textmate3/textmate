import BundleSchema
import SwiftUI

/// The words of a theme's `fontStyle` as toggles. `plain` on its own means
/// clear whatever an enclosing scope set, so it is a toggle too. The key is
/// written as the words joined by spaces, or removed when none is on.
struct SchemaFontStyleField: View {
  let key: SchemaKey
  let values: SchemaValues

  var body: some View {
    LabeledContent(key.name) {
      HStack(spacing: 12) {
        ForEach(ThemeSchema.fontStyleWords, id: \.self) { word in
          Toggle(word, isOn: Binding(get: { words.contains(word) }, set: { isOn in set(word, isOn) }))
            .toggleStyle(.checkbox)
        }
      }
    }
  }

  private var words: [String] {
    (values.string(key.name) ?? "").split(separator: " ").map(String.init)
  }

  private func set(_ word: String, _ isOn: Bool) {
    var current = words.filter { $0 != word }
    if isOn {
      current.append(word)
    }
    let ordered = ThemeSchema.fontStyleWords.filter { current.contains($0) }
    values.setString(ordered.joined(separator: " "), for: key.name)
  }
}
