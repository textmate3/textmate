import Foundation

/// One file the window offers to commit.
@Observable
final class CommitItem: Identifiable {
  let id = UUID()
  let path: String
  var status: String
  var isIncluded: Bool

  init(path: String, status: String, isIncluded: Bool) {
    self.path = (path as NSString).standardizingPath
    self.status = status
    self.isIncluded = isIncluded
  }

  /// Unversioned files are offered but not checked, unless the person named
  /// them, in which case naming them is the answer. External definitions are
  /// never checked, because committing one is almost never what was meant.
  static func included(status: String, didSelectFiles: Bool) -> Bool {
    if status.hasPrefix("X") { return false }
    if status.hasPrefix("?") { return didSelectFiles }
    return true
  }

  var statusColumns: [CommitStatusColumn] { CommitStatusColumn.columns(of: status) }
}
