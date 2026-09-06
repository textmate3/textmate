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

  private let grammarChoices = PreferencesSettings.grammars().map { PopUpChoice($0.name, $0.scope) }

  var body: some View {
    Form {
      LabeledContent("At startup:") {
        VStack(alignment: .leading, spacing: 2) {
          Toggle("Open documents from last session", isOn: $disablesSessionRestore.negated)
          Text("Hold shift (⇧) to bypass")
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.leading, 19)
        }
      }

      LabeledContent("With no open documents:") {
        VStack(alignment: .leading, spacing: 8) {
          Toggle("Create one at startup", isOn: $disablesDocumentAtStartup.negated)
          Toggle("Create one when re-activated", isOn: $disablesDocumentAtReactivation.negated)
        }
      }

      Divider()
        .padding(.vertical, 4)

      LabeledContent("New document type:") {
        PopUpPicker(selection: $newDocumentType, choices: grammarChoices)
          .frame(maxWidth: .infinity, alignment: .leading)
      }

      LabeledContent("Unknown document type:") {
        PopUpPicker(selection: $unknownDocumentType, choices: [PopUpChoice("Prompt for type", ""), .separator] + grammarChoices)
          .frame(maxWidth: .infinity, alignment: .leading)
      }

      LabeledContent("Encoding:") {
        EncodingPopUp(encoding: $encoding)
          .frame(maxWidth: .infinity, alignment: .leading)
      }

      LabeledContent("Line endings:") {
        PopUpPicker(
          selection: $lineEndings,
          choices: [
            PopUpChoice("LF (recommended)", "\n"),
            PopUpChoice("CR (Mac Classic)", "\r"),
            PopUpChoice("CRLF (Windows)", "\r\n"),
          ]
        )
        .frame(maxWidth: .infinity, alignment: .leading)
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
}
