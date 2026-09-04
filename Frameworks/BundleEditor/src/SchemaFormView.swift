import BundleSchema
import SwiftUI

/// A form section built from a schema's key table: one row per key, the
/// field chosen by the key's kind, the key's summary as help. Keys whose
/// kind holds a structure, lists and tables of rules, are not rows here.
/// They belong to an outline, or to a view of their own.
struct SchemaFormView: View {
  let keys: [SchemaKey]
  let values: SchemaValues

  var body: some View {
    ForEach(keys) { key in
      row(for: key)
        .help(key.summary)
    }
  }

  @ViewBuilder
  private func row(for key: SchemaKey) -> some View {
    switch key.kind {
    case .text:
      textField(key)
    case .regularExpression where (values.string(key.name) ?? "").contains("\n"):
      // A pattern written over several lines, as extended mode patterns
      // are, keeps its lines.
      VStack(alignment: .leading, spacing: 4) {
        Text(key.name)
        TextEditor(text: Binding(get: { values.string(key.name) ?? "" }, set: { values.setString($0, for: key.name) }))
          .font(.body.monospaced())
          .frame(minHeight: 80, maxHeight: 240)
          .border(.separator)
      }
    case .regularExpression, .scopeName, .scopeSelector, .include:
      textField(key)
        .font(.body.monospaced())
    case .boolean:
      Toggle(key.name, isOn: Binding(get: { values.flag(key.name) ?? false }, set: { values.setFlag($0, for: key.name) }))
    case .choice(let words):
      SchemaChoiceField(key: key, words: words, values: values)
    case .textList:
      SchemaTextListField(key: key, values: values)
    case .pairs:
      SchemaPairsField(key: key, values: values)
    case .color:
      SchemaColorField(key: key, values: values)
    case .fontStyle:
      SchemaFontStyleField(key: key, values: values)
    case .shellVariables, .captures, .patterns, .repository, .injections, .list, .dictionary, .any:
      EmptyView()
    }
  }

  private func textField(_ key: SchemaKey) -> some View {
    LabeledContent(key.name) {
      TextField(key.name, text: Binding(get: { values.string(key.name) ?? "" }, set: { values.setString($0, for: key.name) }))
        .labelsHidden()
        .multilineTextAlignment(.trailing)
    }
  }
}
