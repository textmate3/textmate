import SwiftUI

/// The Runtimes pane: for Ruby and for Python, the bundle that carries the runtime, the version the application wants,
/// the one bundle commands run on now, the manager behind it, what is installed, and what is newer.
/// The application pins one version per language and asks its manager for exactly that, so the pane offers to install
/// the bundle and the pinned version, and shows the rest.
struct RuntimesView: View {
  @State private var status = RuntimesStatus()

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      Form {
        LanguageSection(runtime: status.ruby, status: status)
        LanguageSection(runtime: status.python, status: status)
      }
      .formStyle(.grouped)

      Divider()

      HStack {
        Text("Bundle commands run on the versions named here. The versions are set by the application, and a newer one arrives with an update.")
          .font(.caption)
          .foregroundStyle(.secondary)
        Spacer()
        Button("Refresh", action: status.refresh)
          .controlSize(.small)
      }
      .padding(.horizontal, 20)
      .padding(.vertical, 10)
    }
    // Taller than the other panes, so both languages show without scrolling.
    .frame(width: 600, height: 680)
    .onAppear(perform: status.refresh)
  }
}

/// One language: its rows in a grouped form section, with the actions in the rows they belong to.
struct LanguageSection: View {
  let runtime: LanguageRuntime
  let status: RuntimesStatus

  var body: some View {
    Section {
      LabeledContent("Bundle") {
        HStack {
          Text(runtime.bundleName ?? "Runtimes \(runtime.language)")
          if runtime.isBundleInstalling {
            ProgressView()
              .controlSize(.small)
          } else if runtime.isBundleInstalled {
            Label("Installed", systemImage: "checkmark.circle.fill")
              .foregroundStyle(.green)
          } else {
            Button("Install") {
              status.installBundle(for: runtime.language)
            }
            .controlSize(.small)
          }
        }
      }

      LabeledContent("Wanted") {
        HStack {
          Text(runtime.pinnedVersion)
          if runtime.isResolving {
            ProgressView()
              .controlSize(.small)
          } else if runtime.isPinnedInstalled {
            Label("Installed", systemImage: "checkmark.circle.fill")
              .foregroundStyle(.green)
          } else if runtime.isBundleInstalled && runtime.managerPath != nil {
            Button("Install \(runtime.pinnedVersion)") {
              status.resolve(runtime.language)
            }
            .controlSize(.small)
          }
        }
      }

      LabeledContent("In use") {
        if let inUse = runtime.inUse {
          // A path under the home directory is written with a tilde, the way the Mac writes one, and a path still too long for the
          // row loses its middle rather than dropping under the label, which is what the form does with a value that does not fit.
          // The whole path is a hover away.
          HStack(spacing: 6) {
            Text(abbreviated(inUse))
              .lineLimit(1)
              .truncationMode(.middle)
              .frame(maxWidth: 400, alignment: .trailing)
              .help(inUse)
            Button {
              status.reveal(inUse)
            } label: {
              Image(systemName: "magnifyingglass")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help("Show in Finder")
          }
        } else {
          Text("None yet")
            .foregroundStyle(.secondary)
        }
      }

      LabeledContent("Manager") {
        if let path = runtime.managerPath {
          VStack(alignment: .trailing, spacing: 2) {
            Text(runtime.managerVersion ?? runtime.managerName)
            Text(abbreviated(path))
              .font(.caption)
              .foregroundStyle(.secondary)
              .lineLimit(1)
              .truncationMode(.middle)
              .frame(maxWidth: 400, alignment: .trailing)
              .help(path)
          }
        } else {
          Text("\(runtime.managerName) is not on this machine")
            .foregroundStyle(.secondary)
        }
      }

      // Both rows stay one line of text whatever the state, so a refresh changes no row's height and the sections stay put.
      // While the lists reload the last known values stay in place, and the spinner is in the section header.
      LabeledContent("Installed") {
        if let problem = runtime.listingProblem {
          Text(problem)
            .foregroundStyle(.secondary)
        } else if runtime.installedVersions.isEmpty {
          Text(runtime.isRefreshing ? "Checking" : "None")
            .foregroundStyle(.secondary)
        } else {
          Text(runtime.installedVersions.map(\.version).joined(separator: ", "))
        }
      }

      LabeledContent("Newer") {
        if runtime.listingProblem != nil {
          Text("Unknown")
            .foregroundStyle(.secondary)
        } else if runtime.versions.isEmpty {
          Text(runtime.isRefreshing ? "Checking" : "None")
            .foregroundStyle(.secondary)
        } else if runtime.newerThanPinned.isEmpty {
          Text("None")
            .foregroundStyle(.secondary)
        } else {
          Text(runtime.newerThanPinned.map(\.version).joined(separator: ", "))
            .foregroundStyle(.secondary)
        }
      }
    } header: {
      HStack {
        Text(runtime.language)
        Spacer()
        if runtime.isRefreshing {
          ProgressView()
            .controlSize(.small)
        }
      }
      // A fixed height, so the spinner coming and going moves nothing below it.
      .frame(height: 20)
    }
  }

  /// The path with the home directory as a tilde.
  private func abbreviated(_ path: String) -> String {
    (path as NSString).abbreviatingWithTildeInPath
  }
}
