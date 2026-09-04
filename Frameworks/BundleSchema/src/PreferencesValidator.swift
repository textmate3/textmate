import Foundation

/// Checks a preferences item, as the dictionary its property list loads
/// into, against the schema: keys nothing reads, and values of the wrong
/// kind for the key.
public struct PreferencesValidator: Sendable {
  public init() {}

  public func issues(in item: [String: Any]) -> [SchemaIssue] {
    var issues: [SchemaIssue] = []

    for key in item.keys.sorted() where PreferencesSchema.itemKey(named: key) == nil {
      issues.append(SchemaIssue(path: key, message: "not a preferences key"))
    }

    guard let settings = item["settings"] else {
      issues.append(SchemaIssue(path: "settings", message: "a preferences item needs settings"))
      return issues
    }
    guard let settings = settings as? [String: Any] else {
      issues.append(SchemaIssue(path: "settings", message: "should be a dictionary"))
      return issues
    }

    issues += settingsIssues(in: settings)
    return issues
  }

  /// The issues in a `settings` dictionary on its own.
  public func settingsIssues(in settings: [String: Any]) -> [SchemaIssue] {
    var issues: [SchemaIssue] = []

    for key in settings.keys.sorted() where PreferencesSchema.settingKey(named: key) == nil {
      issues.append(SchemaIssue(path: "settings.\(key)", message: "not a setting key"))
    }

    for key in PreferencesSchema.settingKeys {
      guard let value = settings[key.name] else { continue }
      let path = "settings.\(key.name)"
      if let message = mismatch(value, key) {
        issues.append(SchemaIssue(path: path, message: message))
      }
      if key.name == "indentedSoftWrap", let table = value as? [String: Any] {
        issues += indentedSoftWrapIssues(in: table, path: path)
      }
      if key.name == "shellVariables", let variables = value as? [Any] {
        issues += shellVariablesIssues(in: variables, path: path)
      }
    }

    return issues
  }

  private func indentedSoftWrapIssues(in table: [String: Any], path: String) -> [SchemaIssue] {
    var issues: [SchemaIssue] = []
    for key in table.keys.sorted() where !PreferencesSchema.indentedSoftWrapKeys.contains(where: { $0.name == key }) {
      issues.append(SchemaIssue(path: path, message: "\(key) is not an indented soft wrap key"))
    }
    for key in PreferencesSchema.indentedSoftWrapKeys {
      if table[key.name] == nil {
        issues.append(SchemaIssue(path: "\(path).\(key.name)", message: "indented soft wrap needs \(key.name)"))
      } else if !(table[key.name] is String) {
        issues.append(SchemaIssue(path: "\(path).\(key.name)", message: "should be text"))
      }
    }
    return issues
  }

  private func shellVariablesIssues(in variables: [Any], path: String) -> [SchemaIssue] {
    var issues: [SchemaIssue] = []
    for (index, variable) in variables.enumerated() {
      let variablePath = "\(path)[\(index)]"
      guard let variable = variable as? [String: Any] else {
        issues.append(SchemaIssue(path: variablePath, message: "not a variable"))
        continue
      }
      for key in variable.keys.sorted() where !PreferencesSchema.shellVariableKeys.contains(where: { $0.name == key }) {
        issues.append(SchemaIssue(path: variablePath, message: "\(key) is not a variable key"))
      }
      for name in ["name", "value"] {
        if variable[name] == nil {
          issues.append(SchemaIssue(path: variablePath, message: "a variable needs a \(name)"))
        } else if !(variable[name] is String) {
          issues.append(SchemaIssue(path: "\(variablePath).\(name)", message: "should be text"))
        }
      }
      if let disabled = variable["disabled"], !PreferencesValidator.isBoolean(disabled) {
        issues.append(SchemaIssue(path: "\(variablePath).disabled", message: "should be true or false"))
      }
    }
    return issues
  }

  private func mismatch(_ value: Any, _ key: SchemaKey) -> String? {
    switch key.kind {
    case .boolean:
      if key.name == "disableIndentCorrections", let text = value as? String, text == "emptyLines" {
        return nil
      }
      return PreferencesValidator.isBoolean(value) ? nil : "should be true or false"
    case .choice(let words):
      guard let text = value as? String else { return "should be one of \(words.joined(separator: ", "))" }
      return words.contains(text) ? nil : "\(text) is not one of \(words.joined(separator: ", "))"
    case .textList:
      guard let list = value as? [Any] else { return "should be a list of text" }
      return list.allSatisfy { $0 is String } ? nil : "should be a list of text"
    case .pairs:
      guard let list = value as? [Any] else { return "should be a list of pairs" }
      for pair in list {
        guard let pair = pair as? [Any], pair.count == 2, pair.allSatisfy({ $0 is String }) else {
          return "each pair should be two strings, an opener and a closer"
        }
      }
      return nil
    case .shellVariables, .list:
      return value is [Any] ? nil : "should be a list"
    case .dictionary:
      return value is [String: Any] ? nil : "should be a dictionary"
    case .color:
      guard let text = value as? String else { return "should be a color" }
      return ThemeValidator.isColor(text) ? nil : "should be a color as #RRGGBB or #RRGGBBAA, or a system color name"
    default:
      return value is String ? nil : "should be text"
    }
  }

  /// A boolean as property lists in the wild write one: a boolean, a
  /// number, or the strings 0, 1, true and false, all of which the
  /// application reads as a flag.
  public static func isBoolean(_ value: Any) -> Bool {
    if value is Bool || value is NSNumber { return true }
    if let text = value as? String { return ["0", "1", "true", "false"].contains(text) }
    return false
  }
}
