import Foundation

/// The last few commit messages, offered again from a pull down menu.
///
/// Kept in user defaults, oldest first, which is the order the window that
/// wrote them used and which existing installs already have.
struct CommitMessageHistory {
  static let defaultsKey = "commitMessages"
  static let limit = 5
  static let titleLength = 30

  private let defaults: UserDefaults

  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
  }

  var messages: [String] { defaults.stringArray(forKey: Self.defaultsKey) ?? [] }

  /// Newest first, which is the order a menu should read in.
  var recent: [String] { messages.reversed() }

  /// A message already in the list moves to the end rather than appearing
  /// twice, and a blank one is not remembered at all.
  func remember(_ message: String) {
    guard !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

    var kept = messages.filter { $0 != message }
    kept.append(message)
    defaults.set(Array(kept.suffix(Self.limit)), forKey: Self.defaultsKey)
  }

  func clear() {
    defaults.removeObject(forKey: Self.defaultsKey)
  }

  /// What the menu shows, since a commit message is longer than a menu item.
  static func title(of message: String) -> String {
    let firstLine = message.components(separatedBy: .newlines).first ?? message
    guard firstLine.count > titleLength else { return firstLine }
    return firstLine.prefix(titleLength) + "…"
  }
}
