import Foundation
import Observation

/// The list behind the Bundles pane: the catalog's snapshots, what the person
/// is filtering and sorting by, and the activity line. It asks the catalog
/// again whenever the catalog says something changed.
@Observable
@MainActor
final class BundleList {
  private let catalog = BundleCatalog.sharedInstance

  private(set) var bundles: [CatalogRow] = []
  private(set) var categories: [String] = []
  private(set) var activityText = ""
  private(set) var isBusy = false

  var searchText = ""
  var category: String?
  var sortOrder: [KeyPathComparator<CatalogRow>] = [KeyPathComparator(\.name, comparator: .localizedStandard)]

  init() {
    catalog.changeHandler = { [weak self] in
      MainActor.assumeIsolated {
        self?.refresh()
      }
    }
    refresh()
  }

  /// The rows the table shows: the search and the category applied, in the sort order.
  var shown: [CatalogRow] {
    bundles
      .filter { searchText.isEmpty || $0.name.localizedCaseInsensitiveContains(searchText) }
      .filter { category == nil || $0.category == category }
      .sorted(using: sortOrder)
  }

  func setInstalled(_ installed: Bool, _ row: CatalogRow) {
    if installed {
      catalog.install(row.id)
    } else {
      catalog.uninstall(row.id)
    }
  }

  func clearActivity() {
    catalog.clearActivity()
    refresh()
  }

  private func refresh() {
    bundles = catalog.bundles.map(CatalogRow.init)
    categories = catalog.categories
    activityText = catalog.activityText
    isBusy = catalog.isBusy
  }
}
