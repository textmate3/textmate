import BundleSchema
import Foundation
import Observation

/// A preferences item's `settings` as the form edits it: the flat settings
/// in one bag of values, the indented soft wrap's two keys in another, and
/// the shell variables as rows. Reads back as the one dictionary the item
/// holds, with keys the form does not show kept as they came.
@Observable
@MainActor
final class PreferencesDocument {
  let settings: SchemaValues
  let indentedSoftWrap: SchemaValues
  private(set) var shellVariables: [ShellVariable]

  /// The item's other keys, name and scope above all, which come back
  /// unchanged.
  var context: [String: Any] = [:]

  init(dictionary: [String: Any] = [:]) {
    let all = dictionary["settings"] as? [String: Any] ?? [:]
    settings = SchemaValues(all.filter { !["indentedSoftWrap", "shellVariables"].contains($0.key) })
    indentedSoftWrap = SchemaValues(all["indentedSoftWrap"] as? [String: Any] ?? [:])
    shellVariables = (all["shellVariables"] as? [Any] ?? []).map { ShellVariable(dictionary: $0 as? [String: Any] ?? [:]) }
  }

  /// The editable keys as the bundle editor saves them.
  var dictionary: [String: Any] {
    var all = settings.dictionary
    if !indentedSoftWrap.dictionary.isEmpty {
      all["indentedSoftWrap"] = indentedSoftWrap.dictionary
    }
    if !shellVariables.isEmpty {
      all["shellVariables"] = shellVariables.map(\.dictionary)
    }
    return ["settings": all]
  }

  var issues: [SchemaIssue] {
    var whole = context
    whole["settings"] = dictionary["settings"]
    return PreferencesValidator().issues(in: whole)
  }

  /// The names of the group's keys that hold a value.
  func setKeys(in group: SchemaGroup) -> [String] {
    group.keys.map(\.name).filter { name in
      switch name {
      case "indentedSoftWrap": !indentedSoftWrap.dictionary.isEmpty
      case "shellVariables": !shellVariables.isEmpty
      default: settings[name] != nil
      }
    }
  }

  func isEmpty(group: SchemaGroup) -> Bool {
    setKeys(in: group).isEmpty
  }

  func addShellVariable() {
    shellVariables.append(ShellVariable(dictionary: ["name": "", "value": ""]))
  }

  func removeShellVariable(_ id: ShellVariable.ID) {
    shellVariables.removeAll { $0.id == id }
  }
}
