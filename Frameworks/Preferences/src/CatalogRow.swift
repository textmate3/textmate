import Foundation

/// One row of the Bundles table, a value copied from the catalog's snapshot
/// so the table can identify and sort it.
struct CatalogRow: Identifiable, Equatable {
  let id: UUID
  let name: String
  let category: String?
  let summary: String
  let updated: Date?
  let link: URL?
  let isInstalled: Bool
  let isInstalling: Bool
  let isMandatory: Bool

  init(_ bundle: CatalogBundle) {
    id = bundle.identifier
    name = bundle.name
    category = bundle.category
    summary = bundle.summary
    updated = bundle.updated
    link = bundle.link
    isInstalled = bundle.isInstalled
    isInstalling = bundle.isInstalling
    isMandatory = bundle.isMandatory
  }

  /// The columns sort on these, since a flag and an optional date have no order of their own.
  var installedRank: Int { isInstalled ? 1 : 0 }
  var sortableUpdated: Date { updated ?? .distantPast }
}
