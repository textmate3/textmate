import BundleSchema
import SwiftUI

/// What the validator finds in the grammar as it is being edited, one line
/// per issue with the path to the rule, or nothing when there is nothing.
struct SchemaIssuesView: View {
  let issues: [SchemaIssue]

  var body: some View {
    if !issues.isEmpty {
      Divider()
      ScrollView {
        VStack(alignment: .leading, spacing: 2) {
          ForEach(issues.indices, id: \.self) { index in
            Text(issues[index].description)
              .font(.caption.monospaced())
              .lineLimit(1)
              .truncationMode(.middle)
          }
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
      }
      .frame(maxHeight: 96)
    }
  }
}
