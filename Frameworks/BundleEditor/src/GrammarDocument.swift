import Foundation
import GrammarSchema
import Observation

/// The part of a grammar the editor edits: the comment, the patterns, the
/// repository and the injections. The grammar's other keys, its name, scope
/// and file types, belong to the properties panel beside it.
///
/// Rules are added, removed and moved here rather than in the views, so the
/// outline and the form only ever describe what the document holds.
@Observable
@MainActor
final class GrammarDocument {
  var comment: String?
  var patterns: [GrammarRule] = []
  var repository: [GrammarNamedRule] = []
  var injections: [GrammarNamedRule] = []

  /// Keys the editor does not know, written back as they came.
  private var extra: [String: Any] = [:]

  /// The grammar's other keys, its scope name above all, which the parser
  /// needs and the properties panel edits. Not written back from here.
  var context: [String: Any] = [:]

  init() {}

  init(dictionary: [String: Any]) {
    var remaining = dictionary
    comment = remaining.removeValue(forKey: "comment") as? String
    patterns = GrammarRule.rules(remaining.removeValue(forKey: "patterns"))
    repository = GrammarNamedRule.namedRules(remaining.removeValue(forKey: "repository"))
    injections = GrammarNamedRule.namedRules(remaining.removeValue(forKey: "injections"))
    extra = remaining
  }

  var dictionary: [String: Any] {
    var result = extra
    if let comment { result["comment"] = comment }
    if !patterns.isEmpty { result["patterns"] = patterns.map(\.dictionary) }
    if !repository.isEmpty { result["repository"] = GrammarNamedRule.dictionary(repository) }
    if !injections.isEmpty { result["injections"] = GrammarNamedRule.dictionary(injections) }
    return result
  }

  /// The whole grammar as the parser wants it: the context's keys under the
  /// edited ones.
  var fullDictionary: [String: Any] {
    context.merging(dictionary) { _, edited in edited }
  }

  /// Every rule in the document, in outline order.
  var allRules: [GrammarRule] {
    let roots = patterns + repository.map(\.rule) + injections.map(\.rule)
    return roots.flatMap { [$0] + $0.descendants }
  }

  func rule(with id: GrammarRule.ID) -> GrammarRule? {
    allRules.first { $0.id == id }
  }

  /// The repository entry or injection whose rule this is, if it is one's.
  func namedRule(for id: GrammarRule.ID) -> GrammarNamedRule? {
    (repository + injections).first { $0.rule.id == id }
  }

  var issues: [GrammarIssue] {
    GrammarValidator().issues(in: dictionary)
  }

  // MARK: - Adding, removing and moving

  /// Where a rule sits: the list of patterns it is in, which is the
  /// document's own or a rule's, and its index there.
  private enum Place {
    case document(Int)
    case rule(GrammarRule, Int)
  }

  private func place(of id: GrammarRule.ID) -> Place? {
    if let index = patterns.firstIndex(where: { $0.id == id }) {
      return .document(index)
    }
    for rule in allRules {
      if let index = rule.patterns.firstIndex(where: { $0.id == id }) {
        return .rule(rule, index)
      }
    }
    return nil
  }

  private func patterns(at place: Place) -> [GrammarRule] {
    switch place {
    case .document: patterns
    case .rule(let rule, _): rule.patterns
    }
  }

  private func setPatterns(_ rules: [GrammarRule], at place: Place) {
    switch place {
    case .document: patterns = rules
    case .rule(let rule, _): rule.patterns = rules
    }
  }

  /// Puts a rule after another, in the same list, or at the end of the
  /// top level when there is nothing to follow.
  func insert(_ rule: GrammarRule, after id: GrammarRule.ID?) {
    guard let id, let place = place(of: id) else {
      patterns.append(rule)
      return
    }
    var rules = patterns(at: place)
    let index =
      switch place {
      case .document(let index), .rule(_, let index): index
      }
    rules.insert(rule, at: index + 1)
    setPatterns(rules, at: place)
  }

  /// Puts a rule at the end of another rule's patterns.
  func insert(_ rule: GrammarRule, into id: GrammarRule.ID) {
    self.rule(with: id)?.patterns.append(rule)
  }

  func addRepositoryRule(named name: String) -> GrammarRule {
    let rule = GrammarRule()
    rule.match = ""
    repository.append(GrammarNamedRule(name: name, rule: rule))
    return rule
  }

  /// Removes a rule wherever it sits: a pattern, a repository entry, an
  /// injection, or a capture's rule, which removes the capture.
  func remove(_ id: GrammarRule.ID) {
    if let place = place(of: id) {
      setPatterns(patterns(at: place).filter { $0.id != id }, at: place)
      return
    }
    repository.removeAll { $0.rule.id == id }
    injections.removeAll { $0.rule.id == id }
    for rule in allRules {
      rule.captures.removeAll { $0.rule.id == id }
      rule.beginCaptures.removeAll { $0.rule.id == id }
      rule.endCaptures.removeAll { $0.rule.id == id }
      rule.whileCaptures.removeAll { $0.rule.id == id }
    }
  }

  /// Moves a pattern up or down within its list. Does nothing at the ends.
  func move(_ id: GrammarRule.ID, by offset: Int) {
    guard let place = place(of: id) else { return }
    var rules = patterns(at: place)
    let index =
      switch place {
      case .document(let index), .rule(_, let index): index
      }
    let target = index + offset
    guard rules.indices.contains(target) else { return }
    rules.swapAt(index, target)
    setPatterns(rules, at: place)
  }

  func canMove(_ id: GrammarRule.ID, by offset: Int) -> Bool {
    guard let place = place(of: id) else { return false }
    let index =
      switch place {
      case .document(let index), .rule(_, let index): index
      }
    return patterns(at: place).indices.contains(index + offset)
  }
}
