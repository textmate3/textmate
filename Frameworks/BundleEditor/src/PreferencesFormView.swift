import BundleSchema
import SwiftUI

/// Every setting a preferences item may hold, one group per section from
/// the schema. Groups with a value open, the rest closed, since an item
/// holds a few settings out of the many. The two settings with a shape of
/// their own, the indented soft wrap and the shell variables, get their own
/// rows in their groups.
struct PreferencesFormView: View {
  let document: PreferencesDocument
  @State private var openGroups: Set<String> = []

  var body: some View {
    Form {
      ForEach(PreferencesSchema.groups) { group in
        Section {
          DisclosureGroup(isExpanded: Binding(get: { openGroups.contains(group.id) }, set: { open in toggle(group.id, open) })) {
            SchemaFormView(keys: group.keys, values: document.settings)
            if group.keys.contains(where: { $0.name == "indentedSoftWrap" }) {
              indentedSoftWrap
            }
            if group.keys.contains(where: { $0.name == "shellVariables" }) {
              ShellVariablesView(document: document)
                .help(PreferencesSchema.settingKey(named: "shellVariables")?.summary ?? "")
            }
          } label: {
            HStack {
              Text(group.name)
                .fontWeight(.semibold)
              Spacer()
              Text(summary(of: group))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.tail)
            }
          }
        }
      }
    }
    .formStyle(.grouped)
    .onAppear {
      openGroups = Set(PreferencesSchema.groups.filter { !document.isEmpty(group: $0) }.map(\.id))
    }
  }

  private var indentedSoftWrap: some View {
    LabeledContent("indentedSoftWrap") {
      Grid(alignment: .trailing) {
        ForEach(PreferencesSchema.indentedSoftWrapKeys) { key in
          GridRow {
            Text(key.name)
              .foregroundStyle(.secondary)
            TextField(key.name, text: Binding(get: { document.indentedSoftWrap.string(key.name) ?? "" }, set: { document.indentedSoftWrap.setString($0, for: key.name) }))
              .labelsHidden()
              .font(.body.monospaced())
              .multilineTextAlignment(.trailing)
              .frame(width: 240)
              .help(key.summary)
          }
        }
      }
    }
    .help(PreferencesSchema.settingKey(named: "indentedSoftWrap")?.summary ?? "")
  }

  /// The names of the group's keys that hold a value, for a closed group.
  private func summary(of group: SchemaGroup) -> String {
    document.setKeys(in: group).joined(separator: ", ")
  }

  private func toggle(_ id: String, _ open: Bool) {
    if open {
      openGroups.insert(id)
    } else {
      openGroups.remove(id)
    }
  }
}
