import BundleSchema
import Foundation
import Observation

/// A macro's recorded steps as the editor holds them, in order. Reads back
/// as the `commands` list the item holds.
@Observable
@MainActor
final class MacroDocument {
  private(set) var steps: [MacroStep]

  /// The item's other keys, name and scope above all, which come back
  /// unchanged.
  var context: [String: Any] = [:]

  init(dictionary: [String: Any] = [:]) {
    steps = (dictionary["commands"] as? [Any] ?? []).map { MacroStep(dictionary: $0 as? [String: Any] ?? [:]) }
  }

  /// The editable keys as the bundle editor saves them.
  var dictionary: [String: Any] {
    ["commands": steps.map(\.dictionary)]
  }

  var issues: [SchemaIssue] {
    var whole = context
    whole["commands"] = dictionary["commands"]
    return MacroValidator().issues(in: whole)
  }

  func step(with id: MacroStep.ID) -> MacroStep? {
    steps.first { $0.id == id }
  }

  func remove(_ id: MacroStep.ID) {
    steps.removeAll { $0.id == id }
  }

  func canMove(_ id: MacroStep.ID, by offset: Int) -> Bool {
    guard let index = steps.firstIndex(where: { $0.id == id }) else { return false }
    return steps.indices.contains(index + offset)
  }

  func move(_ id: MacroStep.ID, by offset: Int) {
    guard let index = steps.firstIndex(where: { $0.id == id }), steps.indices.contains(index + offset) else { return }
    let step = steps.remove(at: index)
    steps.insert(step, at: index + offset)
  }
}
