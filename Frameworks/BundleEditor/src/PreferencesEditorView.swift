import SwiftUI

/// The preferences editor: the form of every setting, and what the
/// validator finds along the bottom.
struct PreferencesEditorView: View {
  let document: PreferencesDocument

  var body: some View {
    VStack(spacing: 0) {
      PreferencesFormView(document: document)
        .frame(minWidth: 480, minHeight: 200)
      SchemaIssuesView(issues: document.issues)
    }
  }
}
