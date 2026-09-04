import BundleSchema
import SwiftUI

/// One of a few words, or none, as a popup. Choosing none removes the key.
struct SchemaChoiceField: View {
  let key: SchemaKey
  let words: [String]
  let values: SchemaValues

  var body: some View {
    Picker(key.name, selection: Binding(get: { values.string(key.name) ?? "" }, set: { values.setString($0, for: key.name) })) {
      Text("not set").tag("")
      ForEach(words, id: \.self) { word in
        Text(word).tag(word)
      }
      if let current = values.string(key.name), !words.contains(current) {
        Text(current).tag(current)
      }
    }
  }
}
