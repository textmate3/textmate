import AppKit
import SwiftUI

/// The Bundles pane: the catalog as a table, a category bar and a search
/// field above it, the automatic updates check box below, and a line saying
/// what just happened or when the index was last updated.
struct BundlesView: View {
  @State private var list = BundleList()
  @AppStorage("disableBundleUpdates") private var disablesUpdates = false

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        // One category at a time, or none, which shows everything: buttons
        // that behave as radio buttons a person can switch back off.
        HStack(spacing: 4) {
          ForEach(list.categories, id: \.self) { category in
            Toggle(category, isOn: selecting(category))
              .toggleStyle(.button)
          }
        }
        .controlSize(.small)

        Spacer()

        SearchField(text: $list.searchText)
          .frame(width: 100)
      }

      Table(list.shown, sortOrder: $list.sortOrder) {
        TableColumn("", sortUsing: KeyPathComparator(\.installedRank)) { bundle in
          installedCell(bundle)
        }
        .width(20)

        TableColumn("Bundle", value: \.name) { bundle in
          Text(bundle.name)
        }
        .width(min: 100, ideal: 140)

        TableColumn("") { bundle in
          if let link = bundle.link {
            Button {
              NSWorkspace.shared.open(link)
            } label: {
              Image(systemName: "arrow.up.forward.square")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
          }
        }
        .width(20)

        TableColumn("Updated", sortUsing: KeyPathComparator(\.sortableUpdated)) { bundle in
          if let updated = bundle.updated {
            Text(updated, format: .dateTime.year().month(.abbreviated).day())
              .frame(maxWidth: .infinity, alignment: .trailing)
          }
        }
        .width(90)

        TableColumn("Description", value: \.summary) { bundle in
          Text(bundle.summary)
        }
      }
      .tableStyle(.bordered)
      .alternatingRowBackgrounds(.enabled)

      Toggle("Check for and install updates automatically", isOn: $disablesUpdates.negated)

      Divider()

      HStack(spacing: 8) {
        if list.isBusy {
          ProgressView()
            .controlSize(.small)
        }
        Text(list.activityText)
          .font(.caption)
          .foregroundStyle(.secondary)
          .frame(maxWidth: .infinity)
      }
    }
    .padding(.top, 8)
    .padding(.horizontal, 20)
    .padding(.bottom, 12)
    .frame(width: 600, height: 450)
    .onAppear(perform: list.clearActivity)
  }

  private func selecting(_ category: String) -> Binding<Bool> {
    Binding(
      get: { list.category == category },
      set: { list.category = $0 ? category : nil }
    )
  }

  /// A check box while the bundle is installed or not, a spinner while it is on its way.
  @ViewBuilder
  private func installedCell(_ bundle: CatalogRow) -> some View {
    if bundle.isInstalling {
      ProgressView()
        .controlSize(.mini)
    } else {
      Toggle(
        "",
        isOn: Binding(
          get: { bundle.isInstalled },
          set: { list.setInstalled($0, bundle) }
        )
      )
      .labelsHidden()
      .controlSize(.small)
      .disabled(bundle.isMandatory && bundle.isInstalled)
    }
  }
}
