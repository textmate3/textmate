import Foundation

/// Checks a theme, as the dictionary its property list loads into, against
/// the schema: keys the theme code does not read, entries that are not
/// dictionaries or lack their settings, colors that are not `#RRGGBB` or
/// `#RRGGBBAA`, and font styles made of words that are not styles.
public struct ThemeValidator: Sendable {
  public init() {}

  public func issues(in theme: [String: Any]) -> [SchemaIssue] {
    var issues: [SchemaIssue] = []

    for key in theme.keys.sorted() where ThemeSchema.themeKey(named: key) == nil {
      issues.append(SchemaIssue(path: key, message: "not a theme key"))
    }

    for key in ThemeSchema.themeKeys {
      if let value = theme[key.name], let message = mismatch(value, key.kind) {
        issues.append(SchemaIssue(path: key.name, message: message))
      }
    }

    if let entries = theme["settings"] as? [Any] {
      for (index, entry) in entries.enumerated() {
        let path = "settings[\(index)]"
        guard let entry = entry as? [String: Any] else {
          issues.append(SchemaIssue(path: path, message: "not an entry"))
          continue
        }
        issues += entryIssues(in: entry, path: path, isPage: index == 0 && entry["scope"] == nil)
      }
    }

    if let gutter = theme["gutterSettings"] as? [String: Any] {
      issues += colorTableIssues(in: gutter, path: "gutterSettings", keys: ThemeSchema.gutterKeys, lookup: ThemeSchema.gutterKey(named:), noun: "gutter key")
    }

    return issues
  }

  private func entryIssues(in entry: [String: Any], path: String, isPage: Bool) -> [SchemaIssue] {
    var issues: [SchemaIssue] = []

    for key in entry.keys.sorted() where ThemeSchema.entryKey(named: key) == nil {
      issues.append(SchemaIssue(path: path, message: "\(key) is not an entry key"))
    }

    for key in ThemeSchema.entryKeys {
      if let value = entry[key.name], let message = mismatch(value, key.kind) {
        issues.append(SchemaIssue(path: "\(path).\(key.name)", message: message))
      }
    }

    guard let style = entry["settings"] as? [String: Any] else {
      issues.append(SchemaIssue(path: path, message: "an entry needs settings"))
      return issues
    }

    issues += colorTableIssues(in: style, path: "\(path).settings", keys: ThemeSchema.styleKeys, lookup: ThemeSchema.styleKey(named:), noun: "style key")
    return issues
  }

  /// A dictionary of styled values, gutter or entry settings: unknown keys,
  /// then each known key's value against its kind.
  private func colorTableIssues(in table: [String: Any], path: String, keys: [SchemaKey], lookup: (String) -> SchemaKey?, noun: String) -> [SchemaIssue] {
    var issues: [SchemaIssue] = []
    for key in table.keys.sorted() where lookup(key) == nil {
      issues.append(SchemaIssue(path: path, message: "\(key) is not a \(noun)"))
    }
    for key in keys {
      if let value = table[key.name], let message = mismatch(value, key.kind) {
        issues.append(SchemaIssue(path: "\(path).\(key.name)", message: message))
      }
    }
    return issues
  }

  private func mismatch(_ value: Any, _ kind: SchemaValueKind) -> String? {
    switch kind {
    case .color:
      guard let text = value as? String else { return "should be a color" }
      return ThemeValidator.isColor(text) ? nil : "should be a color as #RRGGBB or #RRGGBBAA"
    case .fontStyle:
      guard let text = value as? String else { return "should be font style words" }
      let unknown = text.split(separator: " ").map(String.init).filter { !ThemeSchema.fontStyleWords.contains($0) }
      return unknown.isEmpty ? nil : "\(unknown.joined(separator: ", ")) is not a font style"
    case .boolean:
      return value is Bool || value is NSNumber ? nil : "should be true or false"
    case .list:
      return value is [Any] ? nil : "should be a list"
    case .dictionary:
      return value is [String: Any] ? nil : "should be a dictionary"
    default:
      return value is String ? nil : "should be text"
    }
  }

  /// `#RGB`, `#RRGGBB` or `#RRGGBBAA`, hex digits, which is what the theme
  /// code accepts.
  public static func isColor(_ text: String) -> Bool {
    guard text.hasPrefix("#") else { return false }
    let digits = text.dropFirst()
    return [3, 6, 8].contains(digits.count) && digits.allSatisfy(\.isHexDigit)
  }
}
