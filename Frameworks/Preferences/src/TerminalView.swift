import AppKit
import SwiftUI

/// The Terminal pane: the mate shell command, installed or not and where,
/// and the rmate server that lets a remote shell open files here.
struct TerminalView: View {
  @State private var installedPath = MateInstaller.installedPath
  @State private var destination = InstallPathPopUp.usualPaths[0]
  @State private var existingItem: String?
  @State private var mateIsMissing = false

  @AppStorage("rmateServerDisabled") private var disablesRmate = false
  @AppStorage("rmateServerListen") private var rmateInterface = "localhost"
  @AppStorage("rmateServerPort") private var rmatePort = "52698"

  var body: some View {
    Form {
      shellSupportRows
      Divider()
        .padding(.vertical, 4)
      rmateRows
    }
    .formStyle(.columns)
    .padding(20)
    .frame(width: 600)
    .onAppear {
      if let installedPath {
        destination = (installedPath as NSString).abbreviatingWithTildeInPath
      }
    }
    .alert("File Already Exists", isPresented: replaceIsAsked) {
      Button("Replace", action: performInstall)
      Button("Cancel", role: .cancel) {}
    } message: {
      Text(replaceQuestion)
    }
    .alert("Unable to find ‘mate’", isPresented: $mateIsMissing) {
      Button("OK") {}
    } message: {
      Text(TerminalView.missingMateExplanation)
    }
  }

  // MARK: Shell support

  private var isInstalled: Bool { installedPath != nil }

  @ViewBuilder
  private var shellSupportRows: some View {
    LabeledContent("Shell support:") {
      HStack(spacing: 6) {
        Image(systemName: "circle.fill")
          .font(.caption2)
          .foregroundStyle(isInstalled ? Color.green : Color.red)
        Text(isInstalled ? "Shell support installed" : "Shell support not installed")
      }
    }

    LabeledContent("Location:") {
      HStack {
        InstallPathPopUp(path: $destination)
          .disabled(isInstalled)
          .frame(maxWidth: .infinity, alignment: .leading)
        Button(isInstalled ? "Uninstall" : "Install") {
          if isInstalled {
            uninstall()
          } else {
            install()
          }
        }
      }
    }

    LabeledContent("") {
      Text(shellSupportSummary)
        .font(.caption)
        .foregroundStyle(.secondary)
    }
  }

  /// The path the summary shows: the installed one, or the one about to be chosen.
  private var shownPath: String {
    let path = installedPath.map { ($0 as NSString).abbreviatingWithTildeInPath } ?? destination
    return path.replacingOccurrences(of: "~/", with: "$HOME/")
  }

  private var shellSupportSummary: String {
    """
    To use TextMate as editor for subversion, git, and similar you need to install the mate shell command \
    and add a line like the following to ~/.bashrc:

    \texport EDITOR="\(shownPath) -w"
    """
  }

  private var expandedDestination: String {
    (destination as NSString).expandingTildeInPath
  }

  private var replaceIsAsked: Binding<Bool> {
    Binding(
      get: { existingItem != nil },
      set: { if !$0 { existingItem = nil } }
    )
  }

  private var replaceQuestion: String {
    let folder = ((expandedDestination as NSString).deletingLastPathComponent as NSString).abbreviatingWithTildeInPath
    return "\(existingItem ?? "An item") with the name “mate” already exists in the folder \(folder). Do you want to replace it?"
  }

  private static let missingMateExplanation =
    "The ‘mate’ binary is missing from the application bundle. We recommend that you re-download the application."

  /// Something already at the destination is named before it is replaced.
  private func install() {
    guard MateInstaller.bundledMateExists else {
      mateIsMissing = true
      return
    }
    let attributes = try? FileManager.default.attributesOfItem(atPath: expandedDestination)
    switch attributes?[.type] as? FileAttributeType {
    case nil: performInstall()
    case .typeRegular?: existingItem = "A file"
    case .typeDirectory?: existingItem = "A folder"
    case .typeSymbolicLink?: existingItem = "A link"
    default: existingItem = "An item"
    }
  }

  private func performInstall() {
    if MateInstaller.install(atPath: expandedDestination) {
      installedPath = MateInstaller.installedPath
    }
  }

  private func uninstall() {
    if MateInstaller.uninstall() {
      installedPath = nil
    }
  }

  // MARK: rmate

  @ViewBuilder
  private var rmateRows: some View {
    LabeledContent("rmate:") {
      Toggle("Accept rmate connections", isOn: $disablesRmate.negated)
    }

    LabeledContent("Access for:") {
      HStack {
        PopUpPicker(
          selection: $rmateInterface,
          choices: [
            PopUpChoice("local clients", "localhost"),
            PopUpChoice("remote clients", "remote"),
          ]
        )
        .frame(width: 160)
        Text("Port:")
        TextField("", text: $rmatePort)
          .labelsHidden()
          .frame(width: 70)
      }
      .disabled(disablesRmate)
    }

    LabeledContent("") {
      Text(TerminalView.rmateSummary)
        .font(.caption)
        .foregroundStyle(.secondary)
    }
  }

  private static let rmateSummary: LocalizedStringKey = """
    If you wish to activate TextMate from an ssh session you can do so by copying the \
    [rmate](https://github.com/textmate/rmate/) script to the server you are logged into. The script will \
    connect back to TextMate so you need to either allow access for remote clients (and setup your router to \
    accept the specified port) or create an ssh tunnel.
    """
}
