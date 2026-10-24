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
          HStack(spacing: 6) {
            Text(inUse)
              .lineLimit(1)
              .truncationMode(.middle)
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
          VStack(alignment: .leading, spacing: 2) {
            Text(runtime.managerVersion ?? runtime.managerName)
            Text(path)
              .font(.caption)
              .foregroundStyle(.secondary)
              .lineLimit(1)
              .truncationMode(.middle)
          }
        } else {
          Text("\(runtime.managerName) is not on this machine")
            .foregroundStyle(.secondary)
        }
      }

      LabeledContent("Installed") {
        if runtime.isRefreshing {
          ProgressView()
            .controlSize(.small)
        } else if let problem = runtime.listingProblem {
          Text(problem)
            .foregroundStyle(.secondary)
        } else if runtime.installedVersions.isEmpty {
          Text("None")
            .foregroundStyle(.secondary)
        } else {
          Text(runtime.installedVersions.map(\.version).joined(separator: ", "))
        }
      }

      LabeledContent("Newer") {
        if runtime.isRefreshing || runtime.listingProblem != nil {
          Text("")
        } else if runtime.newerThanPinned.isEmpty {
          Text("None")
            .foregroundStyle(.secondary)
        } else {
          Text(runtime.newerThanPinned.map(\.version).joined(separator: ", "))
            .foregroundStyle(.secondary)
        }
      }
    } header: {
      Text(runtime.language)
    }
  }
}
