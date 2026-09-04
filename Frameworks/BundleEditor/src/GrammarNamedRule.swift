import Foundation
import Observation

/// A rule with a name, as a repository holds them by rule name and injections
/// hold them by scope selector.
@Observable
@MainActor
final class GrammarNamedRule: Identifiable {
  let id = UUID()
  var name: String
  var rule: GrammarRule

  init(name: String, rule: GrammarRule) {
    self.name = name
    self.rule = rule
  }

  static func namedRules(_ value: Any) -> [GrammarNamedRule] {
    (value as? [String: Any] ?? [:])
      .compactMap { name, entry in (entry as? [String: Any]).map { GrammarNamedRule(name: name, rule: GrammarRule(dictionary: $0)) } }
      .sorted { $0.name < $1.name }
  }

  static func dictionary(_ entries: [GrammarNamedRule]) -> [String: Any] {
    Dictionary(entries.map { ($0.name, $0.rule.dictionary) }, uniquingKeysWith: { first, _ in first })
  }
}
