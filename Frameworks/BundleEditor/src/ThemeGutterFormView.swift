import BundleSchema
import SwiftUI

/// The gutter's colors, one field per key the theme code reads.
struct ThemeGutterFormView: View {
  let gutter: SchemaValues

  var body: some View {
    Form {
      Section("gutter") {
        SchemaFormView(keys: ThemeSchema.gutterKeys, values: gutter)
      }
    }
    .formStyle(.grouped)
  }
}
