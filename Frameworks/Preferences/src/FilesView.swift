import AppKit
import SwiftUI

/// The Files pane. The three check boxes are defaults, stored negated, the
/// way the application reads them. The rest are settings, the global
/// .tm_properties values, read when the pane is made and written through as
/// they change.
struct FilesView: View {
  @AppStorage("disableSessionRestore") private var disablesSessionRestore = false
  @AppStorage("disableNewDocumentAtStartup") private var disablesDocumentAtStartup = false
  @AppStorage("disableNewDocumentAtReactivation") private var disablesDocumentAtReactivation = false

  @State private var newDocumentType = PreferencesSettings.string(forKey: PreferencesSettings.fileTypeKey, section: "attr.untitled") ?? ""
  @State private var unknownDocumentType = PreferencesSettings.string(forKey: PreferencesSettings.fileTypeKey, section: "attr.file.unknown-type") ?? ""
  @State private var encoding = PreferencesSettings.string(forKey: PreferencesSettings.encodingKey) ?? "UTF-8"
  @State private var lineEndings = PreferencesSettings.string(forKey: PreferencesSettings.lineEndingsKey) ?? "\n"

  private let grammars = PreferencesSettings.grammars()
  private let controlWidth: CGFloat = 280

  var body: some View {
    Form {
      LabeledContent("At startup:") {
        VStack(alignment: .leading, spacing: 2) {
          Toggle("Open documents from last session", isOn: negated($disablesSessionRestore))
          Text("Hold shift (⇧) to bypass")
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.leading, 19)
        }
      }

      LabeledContent("With no open documents:") {
        VStack(alignment: .leading, spacing: 8) {
          Toggle("Create one at startup", isOn: negated($disablesDocumentAtStartup))
          Toggle("Create one when re-activated", isOn: negated($disablesDocumentAtReactivation))
        }
      }

      Divider()
        .padding(.vertical, 4)

      LabeledContent("New document type:") {
        Picker("New document type", selection: $newDocumentType) {
          ForEach(grammars, id: \.scope) { grammar in
            Text(grammar.name).tag(grammar.scope)
          }
        }
        .labelsHidden()
        .frame(width: controlWidth)
      }

      LabeledContent("Unknown document type:") {
        Picker("Unknown document type", selection: $unknownDocumentType) {
          Text("Prompt for type").tag("")
          Divider()
          ForEach(grammars, id: \.scope) { grammar in
            Text(grammar.name).tag(grammar.scope)
          }
        }
        .labelsHidden()
        .frame(width: controlWidth)
      }

      LabeledContent("Encoding:") {
        EncodingPopUp(encoding: $encoding)
          .frame(width: controlWidth)
      }

      LabeledContent("Line endings:") {
        Picker("Line endings", selection: $lineEndings) {
          Text("LF (recommended)").tag("\n")
          Text("CR (Mac Classic)").tag("\r")
          Text("CRLF (Windows)").tag("\r\n")
        }
        .labelsHidden()
        .frame(width: controlWidth)
      }
    }
    .formStyle(.columns)
    .padding(20)
    .frame(width: 600)
    .onChange(of: newDocumentType) { _, scope in
      PreferencesSettings.setString(scope, forKey: PreferencesSettings.fileTypeKey, fileType: "attr.untitled")
    }
    .onChange(of: unknownDocumentType) { _, scope in
      let stored = scope.isEmpty ? nil : scope
      PreferencesSettings.setString(stored, forKey: PreferencesSettings.fileTypeKey, fileType: "attr.file.unknown-type")
    }
    .onChange(of: encoding) { _, encoding in
      PreferencesSettings.setString(encoding, forKey: PreferencesSettings.encodingKey)
    }
    .onChange(of: lineEndings) { _, lineEndings in
      PreferencesSettings.setString(lineEndings, forKey: PreferencesSettings.lineEndingsKey)
    }
  }

  /// The defaults say "disable", the check boxes say "do".
  private func negated(_ flag: Binding<Bool>) -> Binding<Bool> {
    Binding(
      get: { !flag.wrappedValue },
      set: { flag.wrappedValue = !$0 }
    )
  }
}
