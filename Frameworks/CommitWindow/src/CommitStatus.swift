import SwiftUI

/// The letters a source control system reports a file's state with, and the
/// colours they are drawn in.
///
/// This replaces a value transformer that built an attributed string by hand,
/// padding each letter with hair spaces and an expansion attribute to reach a
/// fixed width. A fixed width is what a monospaced font in a frame gives for
/// free, so all of that arithmetic is gone.
enum CommitStatus: Character, CaseIterable {
  case added = "A"
  case conflict = "C"
  case deleted = "D"
  case external = "X"
  case ignored = "I"
  case merged = "G"
  case modified = "M"
  case removed = "R"
  case unversioned = "?"

  /// An underscore stands for a column a system reports nothing in, and is
  /// drawn as a blank rather than as an underscore.
  static let blank: Character = "_"

  var foreground: Color {
    switch self {
      case .added: .init(red: 0, green: 0.667, blue: 0)
      case .conflict, .unversioned: .init(red: 0, green: 0.502, blue: 0.502)
      case .deleted, .removed: .init(red: 1, green: 0, blue: 0)
      case .external: .white
      case .ignored: .init(red: 0.502, green: 0, blue: 0.502)
      case .merged, .modified: .init(red: 0.922, green: 0.392, blue: 0)
    }
  }

  var background: Color {
    switch self {
      case .added: .init(red: 0.733, green: 1, blue: 0.702)
      case .conflict, .unversioned: .init(red: 0.639, green: 0.808, blue: 0.816)
      case .deleted, .removed: .init(red: 0.961, green: 0.741, blue: 0.741)
      case .external: .black
      case .ignored: .init(red: 0.929, green: 0.682, blue: 0.961)
      case .merged, .modified: .init(red: 0.969, green: 0.882, blue: 0.678)
    }
  }
}

/// One column of a status string, which may be a letter this knows, a letter it
/// does not, or a blank.
struct CommitStatusColumn: Identifiable {
  let id: Int
  let letter: Character
  let status: CommitStatus?

  var isBlank: Bool { letter == CommitStatus.blank }

  var foreground: Color { status?.foreground ?? Color(nsColor: .controlTextColor) }
  var background: Color { status?.background ?? Color(nsColor: .controlBackgroundColor) }

  /// A status string is one letter per column, in the order the system reports
  /// them, so `MM` and `A_` both mean something and both have two columns.
  static func columns(of status: String) -> [CommitStatusColumn] {
    status.enumerated().map { index, letter in
      CommitStatusColumn(id: index, letter: letter, status: CommitStatus(rawValue: letter))
    }
  }
}
