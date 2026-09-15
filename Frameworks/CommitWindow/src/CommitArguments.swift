import Foundation

/// A command the action menu offers for a file, declared by the bundle command
/// that opened the window.
///
/// The spelling is `--action-cmd 'A,M:Revert ${TM_DISPLAYNAME},svn,revert'`:
/// the statuses it applies to, a colon, its name, then the command to run. The
/// file it acts on is appended when it runs.
struct CommitAction: Identifiable, Equatable {
  let id = UUID()
  let name: String
  let command: [String]
  let statuses: Set<String>

  static func == (lhs: CommitAction, rhs: CommitAction) -> Bool { lhs.id == rhs.id }

  init?(declaration: String) {
    guard let colon = declaration.firstIndex(of: ":") else { return nil }

    let parts = declaration[declaration.index(after: colon)...].components(separatedBy: ",")
    guard let name = parts.first, parts.count > 1 else { return nil }

    self.name = name
    self.command = Array(parts.dropFirst())
    self.statuses = Set(declaration[..<colon].components(separatedBy: ","))
  }

  func applies(to item: CommitItem) -> Bool { statuses.contains(item.status) }
}

/// What the tool was invoked with.
///
/// The arguments arrive as the tool's own `argv`, so the first is its path and
/// is dropped. Anything that is not a known option is a file to commit, and the
/// `--status` option carries their statuses in the same order, separated by
/// colons.
struct CommitArguments {
  var actions: [CommitAction] = []
  var commitButtonPrefix = "Commit"
  var diffCommand: [String] = []
  var log = ""
  var paths: [String] = []
  var showsContinueButton = false
  var statuses: [String] = []

  /// True when there was not enough to show a window for, which is how the
  /// tool asks to be cancelled rather than displayed.
  var isEmpty: Bool { paths.isEmpty || statuses.isEmpty }

  init(argv: [String]) {
    var remaining = Array(argv.dropFirst()).makeIterator()

    while let argument = remaining.next() {
      switch argument {
        case "--show-continue-button": showsContinueButton = true
        case "--commit-button-title":  commitButtonPrefix = remaining.next() ?? commitButtonPrefix
        case "--log":                  log = remaining.next() ?? ""
        case "--status":               statuses = (remaining.next() ?? "").components(separatedBy: ":")
        case "--diff-cmd":             diffCommand = (remaining.next() ?? "").components(separatedBy: ",")
        case "--action-cmd":
          if let declaration = remaining.next(), let action = CommitAction(declaration: declaration) {
            actions.append(action)
          }
        default:
          paths.append(argument)
      }
    }
  }

  /// The files and their statuses, paired. A path with no status is dropped
  /// rather than shown with a blank one, which is what the index arithmetic
  /// this replaces did by crashing.
  func items(didSelectFiles: Bool) -> [CommitItem] {
    zip(paths, statuses).map { path, status in
      CommitItem(path: path, status: status, isIncluded: CommitItem.included(status: status, didSelectFiles: didSelectFiles))
    }
  }
}
