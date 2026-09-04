import Foundation

/// Checks a grammar, as the dictionary its property list loads into, against the schema:
/// keys the parser does not read,
/// keys that cannot go together,
/// keys that need another,
/// includes that point nowhere,
/// and values of the wrong kind.
///
/// It does not compile regular expressions.
/// That needs the same Oniguruma the parser uses and belongs to whatever hosts the form.
public struct GrammarValidator: Sendable {
  public init() {}

  public func issues(in grammar: [String: Any]) -> [GrammarIssue] {
    var issues: [GrammarIssue] = []

    for key in grammar.keys.sorted() where GrammarSchema.grammarKey(named: key) == nil {
      issues.append(GrammarIssue(path: key, message: "not a grammar key"))
    }

    for key in GrammarSchema.grammarKeys {
      if let value = grammar[key.name], let message = mismatch(value, key.kind) {
        issues.append(GrammarIssue(path: key.name, message: message))
      }
    }

    let repositories = [repositoryNames(of: grammar)]
    issues += rulesIssues(in: grammar, path: "", repositories: repositories)
    return issues
  }

  // MARK: - Rules

  /// The issues in every rule reachable from a grammar or a rule:
  /// its patterns, its captures, its repository and its injections.
  private func rulesIssues(in container: [String: Any], path: String, repositories: [Set<String>]) -> [GrammarIssue] {
    var issues: [GrammarIssue] = []

    if let patterns = container["patterns"] as? [Any] {
      for (index, pattern) in patterns.enumerated() {
        let patternPath = "\(path)patterns[\(index)]"
        if let rule = pattern as? [String: Any] {
          issues += ruleIssues(in: rule, path: patternPath, repositories: repositories)
        } else {
          issues.append(GrammarIssue(path: patternPath, message: "not a rule"))
        }
      }
    }

    for key in ["captures", "beginCaptures", "endCaptures", "whileCaptures", "repository", "injections"] {
      issues += namedRulesIssues(in: container, under: key, path: path, repositories: repositories)
    }

    return issues
  }

  /// The issues in a dictionary of rules keyed by name: captures by number,
  /// a repository by rule name, injections by scope selector.
  private func namedRulesIssues(in container: [String: Any], under key: String, path: String, repositories: [Set<String>]) -> [GrammarIssue] {
    guard let entries = container[key] as? [String: Any] else { return [] }

    var issues: [GrammarIssue] = []
    for (name, entry) in entries.sorted(by: { $0.key < $1.key }) {
      let entryPath = "\(path)\(key).\(name)"
      if let rule = entry as? [String: Any] {
        issues += ruleIssues(in: rule, path: entryPath, repositories: repositories)
      } else {
        issues.append(GrammarIssue(path: entryPath, message: "not a rule"))
      }
    }
    return issues
  }

  private func ruleIssues(in rule: [String: Any], path: String, repositories: [Set<String>]) -> [GrammarIssue] {
    var issues: [GrammarIssue] = []

    for key in rule.keys.sorted() where GrammarSchema.ruleKey(named: key) == nil {
      issues.append(GrammarIssue(path: path, message: "\(key) is not a rule key"))
    }

    for key in GrammarSchema.ruleKeys {
      if let value = rule[key.name], let message = mismatch(value, key.kind) {
        issues.append(GrammarIssue(path: "\(path).\(key.name)", message: message))
      }
    }

    for (first, second) in GrammarSchema.exclusiveRuleKeys where rule[first] != nil && rule[second] != nil {
      issues.append(GrammarIssue(path: path, message: "\(first) and \(second) cannot both be present"))
    }

    for (key, required) in GrammarSchema.requiredRuleKeys.sorted(by: { $0.key < $1.key }) where rule[key] != nil && rule[required] == nil {
      issues.append(GrammarIssue(path: path, message: "\(key) needs \(required)"))
    }

    if rule["begin"] != nil && rule["end"] == nil && rule["while"] == nil {
      issues.append(GrammarIssue(path: path, message: "begin needs end or while"))
    }

    if let include = rule["include"] as? String, let message = includeIssue(include, repositories: repositories) {
      issues.append(GrammarIssue(path: "\(path).include", message: message))
    }

    // A rule's own repository is visible to the rules inside it,
    // and the parser resolves #name outward through every enclosing repository.
    let nested = repositories + [repositoryNames(of: rule)]
    issues += rulesIssues(in: rule, path: "\(path).", repositories: nested)

    return issues
  }

  // MARK: - Values

  private func includeIssue(_ include: String, repositories: [Set<String>]) -> String? {
    if include.isEmpty {
      return "include is empty"
    }
    if include == "$self" || include == "$base" {
      return nil
    }
    if include.hasPrefix("#") {
      let name = String(include.dropFirst())
      return repositories.contains { $0.contains(name) } ? nil : "no repository rule named \(name)"
    }
    // Another grammar, by scope name, with an optional #name into its repository.
    // Whether that grammar exists is only knowable with the bundle index.
    let scope = include.split(separator: "#", maxSplits: 1).first.map(String.init) ?? ""
    return scope.isEmpty ? "include has no scope name before #" : nil
  }

  /// A message when the value is not what the kind holds, or nil when it is.
  private func mismatch(_ value: Any, _ kind: GrammarValueKind) -> String? {
    switch kind {
    case .text, .regularExpression, .scopeName, .scopeSelector, .include:
      return value is String ? nil : "should be text"
    case .boolean:
      return value is Bool || value is NSNumber ? nil : "should be true or false"
    case .textList:
      return value is [String] ? nil : "should be a list of text"
    case .patterns:
      return value is [Any] ? nil : "should be a list of rules"
    case .captures:
      guard let captures = value as? [String: Any] else { return "should be capture numbers to rules" }
      return captures.keys.allSatisfy { !$0.isEmpty } ? nil : "has an empty capture key"
    case .repository, .injections:
      return value is [String: Any] ? nil : "should be names to rules"
    }
  }

  private func repositoryNames(of container: [String: Any]) -> Set<String> {
    Set((container["repository"] as? [String: Any])?.keys.map { $0 } ?? [])
  }
}
