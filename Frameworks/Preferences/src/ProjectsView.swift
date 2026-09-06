import AppKit
import SwiftUI

/// The Projects pane. The check boxes and pop ups are defaults, some stored
/// negated, the way the application reads them. The three patterns are
/// settings, the global .tm_properties values.
struct ProjectsView: View {
  @AppStorage("initialFileBrowserURL") private var fileBrowserLocation = FileManager.default.homeDirectoryForCurrentUser.absoluteString
  @AppStorage("foldersOnTop") private var foldersOnTop = false
  @AppStorage("allowExpandingLinks") private var showsLinksAsExpandable = false
  @AppStorage("fileBrowserSingleClickToOpen") private var opensFilesOnSingleClick = false
  @AppStorage("autoRevealFile") private var keepsCurrentDocumentSelected = false

  @AppStorage("fileBrowserPlacement") private var fileBrowserPlacement = "right"
  @AppStorage("disableFileBrowserWindowResize") private var disablesWindowResize = false

  @AppStorage("disableTabBarCollapsing") private var showsTabsForSingleDocument = false
  @AppStorage("disableTabReordering") private var disablesTabReordering = false
  @AppStorage("disableTabAutoClose") private var disablesTabAutoClose = false

  @AppStorage("htmlOutputPlacement") private var commandOutputPlacement = "window"

  var body: some View {
    Form {
      LabeledContent("File browser location:") {
        VStack(alignment: .leading, spacing: 8) {
          FolderPopUp(url: $fileBrowserLocation)
            .frame(maxWidth: .infinity, alignment: .leading)
          Toggle("Folders on top", isOn: $foldersOnTop)
          Toggle("Show links as expandable", isOn: $showsLinksAsExpandable)
          Toggle("Open files on single click", isOn: $opensFilesOnSingleClick)
          Toggle("Keep current document selected", isOn: $keepsCurrentDocumentSelected)
        }
      }

      Divider()
        .padding(.vertical, 4)

      LabeledContent("Show file browser on:") {
        VStack(alignment: .leading, spacing: 8) {
          PopUpPicker(
            selection: $fileBrowserPlacement,
            choices: [
              PopUpChoice("Left side", "left"),
              PopUpChoice("Right side", "right"),
            ]
          )
          .frame(maxWidth: .infinity, alignment: .leading)
          Toggle("Adjust window when toggling display", isOn: $disablesWindowResize.negated)
        }
      }

      Divider()
        .padding(.vertical, 4)

      LabeledContent("Document tabs:") {
        VStack(alignment: .leading, spacing: 8) {
          Toggle("Show for single document", isOn: $showsTabsForSingleDocument)
          Toggle("Re-order when opening a file", isOn: $disablesTabReordering.negated)
          Toggle("Automatically close unused tabs", isOn: $disablesTabAutoClose.negated)
        }
      }

      Divider()
        .padding(.vertical, 4)

      LabeledContent("Exclude files matching:") {
        SettingsTextField(key: PreferencesSettings.excludeKey)
      }
      LabeledContent("Include files matching:") {
        SettingsTextField(key: PreferencesSettings.includeKey)
      }
      LabeledContent("Non-text files:") {
        SettingsTextField(key: PreferencesSettings.binaryKey)
      }

      Divider()
        .padding(.vertical, 4)

      LabeledContent("Show command output:") {
        PopUpPicker(
          selection: $commandOutputPlacement,
          choices: [
            PopUpChoice("Below text view", "bottom"),
            PopUpChoice("Right of text view", "right"),
            PopUpChoice("New window", "window"),
          ]
        )
        .frame(maxWidth: .infinity, alignment: .leading)
      }
    }
    .formStyle(.columns)
    .padding(20)
    .frame(width: 600)
  }
}
