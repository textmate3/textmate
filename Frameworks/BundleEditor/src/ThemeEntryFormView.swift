import BundleSchema
import SwiftUI

/// The form for one theme entry: its name and scope selector, then the
/// style fields the schema lists for its kind, page or scoped.
struct ThemeEntryFormView: View {
  @Bindable var entry: ThemeEntry

  var body: some View {
    Form {
      if !entry.isPage {
        Section {
          LabeledContent("name") {
            TextField("name", text: Binding(get: { entry.name ?? "" }, set: { entry.name = $0.isEmpty ? nil : $0 }))
              .labelsHidden()
              .multilineTextAlignment(.trailing)
          }
          .help(ThemeSchema.entryKey(named: "name")?.summary ?? "")
          LabeledContent("scope") {
            TextField("scope", text: Binding(get: { entry.scope ?? "" }, set: { entry.scope = $0 }))
              .labelsHidden()
              .font(.body.monospaced())
              .multilineTextAlignment(.trailing)
          }
          .help(ThemeSchema.entryKey(named: "scope")?.summary ?? "")
        }
      }
      Section(entry.isPage ? "page" : "style") {
        SchemaFormView(keys: entry.isPage ? ThemeSchema.pageStyleKeys : ThemeSchema.scopedStyleKeys, values: entry.style)
      }
    }
    .formStyle(.grouped)
  }
}
