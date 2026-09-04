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
    var remaining = dictionary
    scopeName = remaining.removeValue(forKey: "name") as? String
    contentName = remaining.removeValue(forKey: "contentName") as? String
    match = remaining.removeValue(forKey: "match") as? String
    begin = remaining.removeValue(forKey: "begin") as? String
    end = remaining.removeValue(forKey: "end") as? String
    whilePattern = remaining.removeValue(forKey: "while") as? String
    include = remaining.removeValue(forKey: "include") as? String
    comment = remaining.removeValue(forKey: "comment") as? String
    applyEndPatternLast = GrammarRule.flag(remaining.removeValue(forKey: "applyEndPatternLast"))
    disabled = GrammarRule.flag(remaining.removeValue(forKey: "disabled"))
    patterns = GrammarRule.rules(remaining.removeValue(forKey: "patterns"))
    captures = GrammarCapture.captures(remaining.removeValue(forKey: "captures"))
    beginCaptures = GrammarCapture.captures(remaining.removeValue(forKey: "beginCaptures"))
    endCaptures = GrammarCapture.captures(remaining.removeValue(forKey: "endCaptures"))
    whileCaptures = GrammarCapture.captures(remaining.removeValue(forKey: "whileCaptures"))
    repository = GrammarNamedRule.namedRules(remaining.removeValue(forKey: "repository"))
    extra = remaining
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

  /// Gives the rule another shape, carrying the pattern across where the
  /// shapes share one: a match becomes a begin, a begin becomes a match. The
  /// captures tables stay, since the form shows the ones the shape uses.
  func convert(to newShape: GrammarRuleShape) {
    guard newShape != shape else { return }
    let pattern = match ?? begin ?? ""
    match = nil
    begin = nil
    end = nil
    whilePattern = nil
    include = nil
    switch newShape {
    case .match:
      match = pattern
    case .beginEnd:
      begin = pattern
      end = ""
    case .beginWhile:
      begin = pattern
      whilePattern = ""
    case .include:
      include = ""
      contentName = nil
    case .patterns:
      contentName = nil
    }
  }

  /// The rows shown under this rule in the outline: its patterns, then the
  /// rules of captures that have patterns of their own, labeled by table
  /// and number.
  var outlineChildren: [(label: String?, rule: GrammarRule)] {
    var children: [(label: String?, rule: GrammarRule)] = patterns.map { (nil, $0) }
    for (table, entries) in [("captures", captures), ("beginCaptures", beginCaptures), ("endCaptures", endCaptures), ("whileCaptures", whileCaptures)] {
      for capture in entries where !capture.rule.patterns.isEmpty {
        children.append(("\(table) \(capture.key)", capture.rule))
      }
    }
    return children
  }

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

  /// An empty rule of a shape, with the shape's defining keys present and
  /// blank so the form shows their fields.
  static func blank(_ shape: GrammarRuleShape) -> GrammarRule {
    let rule = GrammarRule()
    switch shape {
    case .match: rule.match = ""
    case .beginEnd:
      rule.begin = ""
      rule.end = ""
    case .beginWhile:
      rule.begin = ""
      rule.whilePattern = ""
    case .include: rule.include = ""
    case .patterns: break
    }
    return rule
  }

  static func rules(_ value: Any?) -> [GrammarRule] {
    (value as? [Any] ?? []).compactMap { ($0 as? [String: Any]).map(GrammarRule.init(dictionary:)) }
  }

  private static func flag(_ value: Any?) -> Bool? {
    if let flag = value as? Bool { return flag }
    if let number = value as? NSNumber { return number.boolValue }
    return nil
  }

  private static func put(_ dictionary: inout [String: Any], _ key: String, _ value: String?) {
    if let value { dictionary[key] = value }
  }
}
