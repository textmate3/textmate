import Foundation
import GrammarSchema
import Observation

/// One rule of a grammar as the form edits it, with its nested patterns,
/// captures and repository. Loads from the dictionary the grammar's property
/// list holds and writes the same shape back. Keys the schema does not know
/// are kept and written back untouched, so nothing is lost by editing.
@Observable
@MainActor
final class GrammarRule: Identifiable {
  let id = UUID()

  var scopeName: String?
  var contentName: String?
  var match: String?
  var begin: String?
  var end: String?
  var whilePattern: String?
  var include: String?
  var comment: String?
  var applyEndPatternLast: Bool?
  var disabled: Bool?

  var patterns: [GrammarRule] = []
  var captures: [GrammarCapture] = []
  var beginCaptures: [GrammarCapture] = []
  var endCaptures: [GrammarCapture] = []
  var whileCaptures: [GrammarCapture] = []
  var repository: [GrammarNamedRule] = []

  /// Keys the schema does not know, written back as they came.
  private var extra: [String: Any] = [:]

  init() {}

  init(dictionary: [String: Any]) {
    for (key, value) in dictionary {
      switch key {
      case "name": scopeName = value as? String
      case "contentName": contentName = value as? String
      case "match": match = value as? String
      case "begin": begin = value as? String
      case "end": end = value as? String
      case "while": whilePattern = value as? String
      case "include": include = value as? String
      case "comment": comment = value as? String
      case "applyEndPatternLast": applyEndPatternLast = GrammarRule.flag(value)
      case "disabled": disabled = GrammarRule.flag(value)
      case "patterns": patterns = GrammarRule.rules(value)
      case "captures": captures = GrammarCapture.captures(value)
      case "beginCaptures": beginCaptures = GrammarCapture.captures(value)
      case "endCaptures": endCaptures = GrammarCapture.captures(value)
      case "whileCaptures": whileCaptures = GrammarCapture.captures(value)
      case "repository": repository = GrammarNamedRule.namedRules(value)
      default: extra[key] = value
      }
    }
  }

  var dictionary: [String: Any] {
    var result = extra
    GrammarRule.put(&result, "name", scopeName)
    GrammarRule.put(&result, "contentName", contentName)
    GrammarRule.put(&result, "match", match)
    GrammarRule.put(&result, "begin", begin)
    GrammarRule.put(&result, "end", end)
    GrammarRule.put(&result, "while", whilePattern)
    GrammarRule.put(&result, "include", include)
    GrammarRule.put(&result, "comment", comment)
    if let applyEndPatternLast { result["applyEndPatternLast"] = applyEndPatternLast }
    if let disabled { result["disabled"] = disabled }
    if !patterns.isEmpty { result["patterns"] = patterns.map(\.dictionary) }
    if !captures.isEmpty { result["captures"] = GrammarCapture.dictionary(captures) }
    if !beginCaptures.isEmpty { result["beginCaptures"] = GrammarCapture.dictionary(beginCaptures) }
    if !endCaptures.isEmpty { result["endCaptures"] = GrammarCapture.dictionary(endCaptures) }
    if !whileCaptures.isEmpty { result["whileCaptures"] = GrammarCapture.dictionary(whileCaptures) }
    if !repository.isEmpty { result["repository"] = GrammarNamedRule.dictionary(repository) }
    return result
  }

  var shape: GrammarRuleShape? { GrammarRuleShape.of(dictionary) }

  /// What the outline shows for the rule: its scope, or what it matches or includes.
  var title: String {
    if let scopeName, !scopeName.isEmpty { return scopeName }
    if let include, !include.isEmpty { return include }
    if let match, !match.isEmpty { return match }
    if let begin, !begin.isEmpty { return begin }
    if !patterns.isEmpty { return "\(patterns.count) patterns" }
    return "rule"
  }

  /// Every rule below this one, in outline order: patterns, then the rules of
  /// each captures table, then the repository.
  var descendants: [GrammarRule] {
    let below = patterns + (captures + beginCaptures + endCaptures + whileCaptures).map(\.rule) + repository.map(\.rule)
    return below.flatMap { [$0] + $0.descendants }
  }

  static func rules(_ value: Any) -> [GrammarRule] {
    (value as? [Any] ?? []).compactMap { ($0 as? [String: Any]).map(GrammarRule.init(dictionary:)) }
  }

  private static func flag(_ value: Any) -> Bool? {
    if let flag = value as? Bool { return flag }
    if let number = value as? NSNumber { return number.boolValue }
    return nil
  }

  private static func put(_ dictionary: inout [String: Any], _ key: String, _ value: String?) {
    if let value { dictionary[key] = value }
  }
}
