import SwiftUI

/// The theme editor: the theme's parts on the left, the selected part's form
/// on the right, the preview beneath, and what the validator finds along
/// the bottom.
struct ThemeEditorView: View {
  let document: ThemeDocument
  @State private var selection: ThemeSelection? = .page

  var body: some View {
    VStack(spacing: 0) {
      VSplitView {
        HSplitView {
          ThemeOutlineView(document: document, selection: $selection)
            .frame(minWidth: 180, idealWidth: 260, maxWidth: 420)
          Group {
            switch selection {
            case .page:
              ThemeEntryFormView(entry: document.page)
            case .gutter:
              ThemeGutterFormView(gutter: document.gutter)
            case .entry(let id):
              if let entry = document.entry(with: id) {
                ThemeEntryFormView(entry: entry)
              } else {
                placeholder
              }
            case nil:
              placeholder
            }
          }
          .frame(minWidth: 320, maxWidth: .infinity)
        }
        .frame(minHeight: 200)
        ThemePreviewView(document: document)
          .frame(minHeight: 140, idealHeight: 240)
      }
      SchemaIssuesView(issues: document.issues)
    }
  }

  private var placeholder: some View {
    Text("Select a part of the theme")
      .foregroundStyle(.secondary)
      .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}
