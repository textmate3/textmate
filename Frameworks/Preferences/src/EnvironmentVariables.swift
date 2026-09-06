import Foundation
import Observation

/// The list behind the Variables pane, read from defaults when made and
/// written back after every change, since the settings framework reads the
/// default directly whenever a command runs.
@Observable
@MainActor
final class EnvironmentVariables {
  static let defaultsKey = "environmentVariables"

  var rows: [EnvironmentVariable] {
    didSet { save() }
  }

  init() {
    let stored = UserDefaults.standard.array(forKey: EnvironmentVariables.defaultsKey) as? [[String: Any]] ?? []
    rows = stored.compactMap(EnvironmentVariable.init(dictionary:))
  }

  /// A new row above the selected one, or at the end, ready to be named.
  @discardableResult
  func add(above selected: EnvironmentVariable.ID?) -> EnvironmentVariable.ID {
    let row = EnvironmentVariable(name: "VARIABLE_NAME", value: "variable value")
    let index = rows.firstIndex { $0.id == selected } ?? rows.count
    rows.insert(row, at: index)
    return row.id
  }

  /// Removes the row and says which one to select next: the one above it, or
  /// the one that took its place, or nothing if the list is empty.
  func remove(_ id: EnvironmentVariable.ID) -> EnvironmentVariable.ID? {
    guard let index = rows.firstIndex(where: { $0.id == id }) else { return nil }
    rows.remove(at: index)
    let next = max(index - 1, 0)
    return rows.indices.contains(next) ? rows[next].id : nil
  }

  private func save() {
    UserDefaults.standard.set(rows.map(\.dictionary), forKey: EnvironmentVariables.defaultsKey)
  }
}
