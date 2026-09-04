import Foundation

/// Checks a macro, as the dictionary its property list loads into, against
/// the schema: keys nothing reads, steps that are not dictionaries, steps
/// without a selector, and selectors that are not selectors.
public struct MacroValidator: Sendable {
  public init() {}

  public func issues(in macro: [String: Any]) -> [SchemaIssue] {
    var issues: [SchemaIssue] = []

    for key in macro.keys.sorted() where MacroSchema.itemKey(named: key) == nil {
      issues.append(SchemaIssue(path: key, message: "not a macro key"))
    }

    for key in MacroSchema.itemKeys {
      if let value = macro[key.name], let message = mismatch(value, key.kind) {
        issues.append(SchemaIssue(path: key.name, message: message))
      }
    }

    if let steps = macro["commands"] as? [Any] {
      issues += stepsIssues(in: steps)
    }

    return issues
  }

  /// The issues in a `commands` list on its own.
  public func stepsIssues(in steps: [Any]) -> [SchemaIssue] {
    var issues: [SchemaIssue] = []
    for (index, step) in steps.enumerated() {
      let path = "commands[\(index)]"
      guard let step = step as? [String: Any] else {
        issues.append(SchemaIssue(path: path, message: "not a step"))
        continue
      }
      for key in step.keys.sorted() where MacroSchema.stepKey(named: key) == nil {
        issues.append(SchemaIssue(path: path, message: "\(key) is not a step key"))
      }
      guard let command = step["command"] else {
        issues.append(SchemaIssue(path: path, message: "a step needs a command"))
        continue
      }
      guard let command = command as? String else {
        issues.append(SchemaIssue(path: "\(path).command", message: "should be text"))
        continue
      }
      if !MacroValidator.isSelector(command) {
        issues.append(SchemaIssue(path: "\(path).command", message: "\(command) is not a selector"))
      }
    }
    return issues
  }

  private func mismatch(_ value: Any, _ kind: SchemaValueKind) -> String? {
    switch kind {
    case .list:
      return value is [Any] ? nil : "should be a list"
    default:
      return value is String ? nil : "should be text"
    }
  }

  /// A one argument selector as the text view records them: a name ending
  /// in a colon, made of letters, digits and underscores.
  public static func isSelector(_ text: String) -> Bool {
    guard text.hasSuffix(":"), text.count > 1 else { return false }
    let name = text.dropLast()
    return name.allSatisfy { $0.isLetter || $0.isNumber || $0 == "_" } && !name.contains(":")
  }
}
