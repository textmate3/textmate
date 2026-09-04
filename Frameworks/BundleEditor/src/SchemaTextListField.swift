import BundleSchema
import SwiftUI

/// A list of strings as lines of text, one per line. Blank lines are not
/// entries, and no lines at all removes the key.
struct SchemaTextListField: View {
  let key: SchemaKey
  let values: SchemaValues

  var body: some View {
    LabeledContent(key.name) {
      TextEditor(text: Binding(get: { values.strings(key.name).joined(separator: "\n") }, set: { values.setStrings($0.split(separator: "\n", omittingEmptySubsequences: true).map(String.init), for: key.name) }))
        .font(.body.monospaced())
        .frame(minHeight: 44, maxHeight: 120)
        .border(.separator)
    }
  }
}
