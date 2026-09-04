import Foundation
import GrammarSchema
import Observation

/// The part of a grammar the editor edits: the comment, the patterns, the
/// repository and the injections. The grammar's other keys, its name, scope
/// and file types, belong to the properties panel beside it.
@Observable
@MainActor
final class GrammarDocument {
  var comment: String?
  var patterns: [GrammarRule] = []
  var repository: [GrammarNamedRule] = []
  var injections: [GrammarNamedRule] = []

  /// Keys the editor does not know, written back as they came.
  private var extra: [String: Any] = [:]

  init() {}

  init(dictionary: [String: Any]) {
    for (key, value) in dictionary {
      switch key {
      case "comment": comment = value as? String
      case "patterns": patterns = GrammarRule.rules(value)
      case "repository": repository = GrammarNamedRule.namedRules(value)
      case "injections": injections = GrammarNamedRule.namedRules(value)
      default: extra[key] = value
      }
    }
  }

  var dictionary: [String: Any] {
    var result = extra
    if let comment { result["comment"] = comment }
    if !patterns.isEmpty { result["patterns"] = patterns.map(\.dictionary) }
    if !repository.isEmpty { result["repository"] = GrammarNamedRule.dictionary(repository) }
    if !injections.isEmpty { result["injections"] = GrammarNamedRule.dictionary(injections) }
    return result
  }

  /// Every rule in the document, in outline order.
  var allRules: [GrammarRule] {
    let roots = patterns + repository.map(\.rule) + injections.map(\.rule)
    return roots.flatMap { [$0] + $0.descendants }
  }

  func rule(with id: GrammarRule.ID) -> GrammarRule? {
    allRules.first { $0.id == id }
  }

  var issues: [GrammarIssue] {
    GrammarValidator().issues(in: dictionary)
  }
}
