import Foundation

/// What the theme outline has selected: the page entry, the gutter, or one
/// scoped entry by identifier.
enum ThemeSelection: Hashable {
  case page
  case gutter
  case entry(ThemeEntry.ID)

  var entryID: ThemeEntry.ID? {
    if case .entry(let id) = self { return id }
    return nil
  }
}
