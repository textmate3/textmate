import SwiftUI

/// The theme's parts as a list: the page, the gutter, then every scoped
/// entry in the order the theme applies them. The bar underneath adds,
/// removes and moves entries.
struct ThemeOutlineView: View {
  let document: ThemeDocument
  @Binding var selection: ThemeSelection?

  var body: some View {
    VStack(spacing: 0) {
      List(selection: $selection) {
        Section("Theme") {
          Text("Page").tag(ThemeSelection.page)
          Text("Gutter").tag(ThemeSelection.gutter)
        }
        Section("Scopes") {
          ForEach(document.scopedEntries) { entry in
            HStack {
              Text(entry.title)
                .lineLimit(1)
                .truncationMode(.middle)
              Spacer()
              Text(entry.scope ?? "")
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
            }
            .tag(ThemeSelection.entry(entry.id))
            .contextMenu {
              Button("Add Entry After") { add(after: entry.id) }
              Button("Move Up") { document.move(entry.id, by: -1) }
              Button("Move Down") { document.move(entry.id, by: 1) }
              Divider()
              Button("Remove", role: .destructive) { remove(entry.id) }
            }
          }
        }
      }
      .listStyle(.inset)
      Divider()
      bar
    }
  }

  private var bar: some View {
    HStack(spacing: 4) {
      Button {
        add(after: selection?.entryID)
      } label: {
        Image(systemName: "plus")
      }
      .help("Add an entry after the selection")

      Button {
        if let id = selection?.entryID { remove(id) }
      } label: {
        Image(systemName: "minus")
      }
      .disabled(selection?.entryID == nil)
      .help("Remove the selected entry")

      Spacer()

      Button {
        if let id = selection?.entryID { document.move(id, by: -1) }
      } label: {
        Image(systemName: "chevron.up")
      }
      .disabled(!(selection?.entryID.map { document.canMove($0, by: -1) } ?? false))
      .help("Move the selected entry up")

      Button {
        if let id = selection?.entryID { document.move(id, by: 1) }
      } label: {
        Image(systemName: "chevron.down")
      }
      .disabled(!(selection?.entryID.map { document.canMove($0, by: 1) } ?? false))
      .help("Move the selected entry down")
    }
    .buttonStyle(.borderless)
    .padding(.horizontal, 8)
    .padding(.vertical, 4)
  }

  private func add(after id: ThemeEntry.ID?) {
    let entry = document.addEntry(after: id)
    selection = .entry(entry.id)
  }

  private func remove(_ id: ThemeEntry.ID) {
    document.remove(id)
    if selection == .entry(id) { selection = nil }
  }
}
