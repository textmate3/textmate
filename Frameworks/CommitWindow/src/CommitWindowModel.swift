import AppKit
import Observation

/// Everything the commit window shows and decides, with no view in it.
@MainActor @Observable
final class CommitWindowModel {
  static let showsFileListKey = "showFileListInCommitWindow"

  let arguments: CommitArguments
  let environment: [String: String]
  var items: [CommitItem]
  var showsFileList: Bool {
    didSet { UserDefaults.standard.set(showsFileList, forKey: Self.showsFileListKey) }
  }

  /// True while the option key is down, which turns Commit into Commit and
  /// Continue. Only offered when the command that opened the window asked for
  /// it.
  var continues = false

  /// Set when something the window ran failed, and shown as a sheet.
  var failure: CommitFailure?

  private let history = CommitMessageHistory()
  private let reply: CommitWindowReply

  /// Called when the window has answered and should go away.
  var onFinish: (() -> Void)?

  init(arguments: CommitArguments, environment: [String: String], reply: CommitWindowReply) {
    self.arguments = arguments
    self.environment = environment
    self.reply = reply
    self.items = arguments.items(didSelectFiles: environment["TM_SELECTED_FILES"] != nil)
    self.showsFileList = UserDefaults.standard.bool(forKey: Self.showsFileListKey)
    self.continues = arguments.showsContinueButton
  }

  // ==========
  // = Titles =
  // ==========

  var includedCount: Int { items.count { $0.isIncluded } }

  var commitButtonTitle: String {
    let noun = includedCount == 1 ? "Item" : "Items"
    let suffix = continues ? " & Continue" : ""
    return "\(arguments.commitButtonPrefix) \(includedCount) \(noun)\(suffix)"
  }

  var projectDirectory: String { environment["TM_PROJECT_DIRECTORY"] ?? "" }

  var recentMessages: [String] { history.recent }

  // ===========
  // = Answers =
  // ===========

  /// What the tool receives on its standard output: a `-m` argument carrying
  /// the message, then every included path, each quoted for a shell.
  static func standardOutput(message: String, paths: [String]) -> String {
    let quoted = message.replacingOccurrences(of: "'", with: "'\"'\"'")
    let arguments = [" -m '\(quoted)' "] + paths.map { CommitWindowBridge.escapedPath($0) } + ["\n"]
    return arguments.joined(separator: " ")
  }

  func commit(message: String, andContinue shouldContinue: Bool) {
    let paths = items.filter { $0.isIncluded }.map(\.path)
    reply.sendStandardOutput(Self.standardOutput(message: message, paths: paths), shouldContinue: shouldContinue)
    history.remember(message)
    onFinish?()
  }

  func cancel() {
    reply.sendCancelled()
    onFinish?()
  }

  func clearHistory() { history.clear() }

  // ===========
  // = Actions =
  // ===========

  func setAllIncluded(_ included: Bool) {
    for item in items { item.isIncluded = included }
  }

  /// The shell line a command and a file turn into, with every word quoted.
  /// The tool name is resolved against the environment's own PATH, since the
  /// command runs in the project's world rather than this process's.
  private func shellLine(for command: [String], on item: CommitItem) -> String {
    var words = [CommitWindowBridge.absolutePath(forTool: command[0], environment: environment)]
    words.append(contentsOf: command.dropFirst())
    words.append(item.path)
    return words.map { CommitWindowBridge.escapedPath($0) }.joined(separator: " ")
  }

  /// Opens the file's diff in a window of its own, through the diff command
  /// the bundle named. Does nothing when it named none.
  func showDiff(of item: CommitItem) {
    guard !arguments.diffCommand.isEmpty else { return }

    let name = CommitWindowBridge.displayName(forPath: item.path)
    let line = "cd \"${TM_PROJECT_DIRECTORY}\" && \(shellLine(for: arguments.diffCommand, on: item))|\"$TM_MATE\" --no-wait --name \"---/+++ \(name)\""
    let variables = environment

    // Off the main thread, because a diff of a large file takes a moment and
    // the window has to stay usable.
    Task {
      if await Self.run(line, environment: variables) == nil {
        failure = CommitFailure(title: "Failed running diff command.", detail: line)
      }
    }
  }

  private nonisolated static func run(_ line: String, environment: [String: String]) async -> String? {
    await Task.detached { CommitWindowBridge.runShellCommand(line, environment: environment) }.value
  }

  /// Runs one of the declared action commands against a file, and takes the
  /// first word of what it writes as that file's new status.
  func perform(_ action: CommitAction, on item: CommitItem) {
    let line = "cd \"${TM_PROJECT_DIRECTORY}\" && \(shellLine(for: action.command, on: item))"

    guard let output = CommitWindowBridge.runShellCommand(line, environment: environment) else {
      failure = CommitFailure(title: "Failed running command", detail: line)
      return
    }

    guard let status = Self.statusFromCommandOutput(output) else {
      failure = CommitFailure(title: "Cannot understand output from command", detail: line)
      return
    }

    item.status = status
    item.isIncluded = false
  }

  /// A command answers the new status first, then whatever else it wants to
  /// say. Output with no whitespace at all is not a status and is refused.
  static func statusFromCommandOutput(_ output: String) -> String? {
    guard let end = output.rangeOfCharacter(from: .whitespacesAndNewlines) else { return nil }
    return String(output[..<end.lowerBound])
  }

  func title(of action: CommitAction, for item: CommitItem?) -> String {
    guard let item, action.applies(to: item) else { return action.name }
    return CommitWindowBridge.expandedString(action.name, withVariables: ["TM_DISPLAYNAME": CommitWindowBridge.displayName(forPath: item.path)])
  }
}

struct CommitFailure: Identifiable {
  let id = UUID()
  let title: String
  let detail: String
}
