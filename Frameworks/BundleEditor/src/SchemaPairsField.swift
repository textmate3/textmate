import BundleSchema
import SwiftUI

/// A list of opener and closer pairs as rows of two fields, with a button
/// to add a row and one per row to take it away. No rows removes the key.
struct SchemaPairsField: View {
  let key: SchemaKey
  let values: SchemaValues

  var body: some View {
    LabeledContent(key.name) {
      VStack(alignment: .trailing, spacing: 4) {
        ForEach(Array(values.pairs(key.name).enumerated()), id: \.offset) { index, pair in
          HStack(spacing: 4) {
            TextField("opener", text: Binding(get: { pair[0] }, set: { update(index, opener: $0) }))
              .labelsHidden()
              .font(.body.monospaced())
              .multilineTextAlignment(.center)
              .frame(width: 60)
            TextField("closer", text: Binding(get: { pair[1] }, set: { update(index, closer: $0) }))
              .labelsHidden()
              .font(.body.monospaced())
              .multilineTextAlignment(.center)
              .frame(width: 60)
            Button {
              remove(index)
            } label: {
              Image(systemName: "minus.circle")
            }
            .buttonStyle(.borderless)
            .help("Remove this pair")
          }
        }
        Button("Add Pair") {
          values.setPairs(values.pairs(key.name) + [["", ""]], for: key.name)
        }
      }
    }
  }

  private func update(_ index: Int, opener: String? = nil, closer: String? = nil) {
    var pairs = values.pairs(key.name)
    guard pairs.indices.contains(index) else { return }
    if let opener { pairs[index][0] = opener }
    if let closer { pairs[index][1] = closer }
    values.setPairs(pairs, for: key.name)
  }

  private func remove(_ index: Int) {
    var pairs = values.pairs(key.name)
    guard pairs.indices.contains(index) else { return }
    pairs.remove(at: index)
    values.setPairs(pairs, for: key.name)
  }
}
