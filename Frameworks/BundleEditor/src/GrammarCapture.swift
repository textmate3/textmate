import Foundation
import Observation

/// One entry of a captures table: the capture's number, or its name for a
/// named group, and the rule applied to it, which is usually just a scope.
@Observable
@MainActor
final class GrammarCapture: Identifiable {
  let id = UUID()
  var key: String
  var rule: GrammarRule

  init(key: String, rule: GrammarRule) {
    self.key = key
    self.rule = rule
  }

  /// Captures in a stable order: numbers by value, then names.
  static func captures(_ value: Any?) -> [GrammarCapture] {
    let entries = (value as? [String: Any] ?? [:]).compactMap { key, entry in
      (entry as? [String: Any]).map { GrammarCapture(key: key, rule: GrammarRule(dictionary: $0)) }
    }
    return entries.sorted { lhs, rhs in
      switch (Int(lhs.key), Int(rhs.key)) {
      case (let left?, let right?): return left < right
      case (nil, nil): return lhs.key < rhs.key
      case (nil, _): return false
      case (_, nil): return true
      }
    }
  }

  static func dictionary(_ captures: [GrammarCapture]) -> [String: Any] {
    Dictionary(captures.map { ($0.key, $0.rule.dictionary) }, uniquingKeysWith: { first, _ in first })
  }
}
