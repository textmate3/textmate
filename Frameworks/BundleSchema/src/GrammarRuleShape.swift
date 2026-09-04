/// The four shapes a rule takes, decided by which of its keys are present.
/// The form shows the fields for one shape at a time,
/// and the validator reports a rule that mixes them.
public enum GrammarRuleShape: Sendable, Hashable {
  /// A `match` rule: one regular expression, applied within a line.
  case match

  /// A `begin` and `end` rule: a region, with its own patterns inside.
  case beginEnd

  /// A `begin` and `while` rule: a region that continues on each line matching `while`.
  case beginWhile

  /// An `include` rule: a reference to another rule.
  case include

  /// A rule with only `patterns`: a grouping, tried in order.
  case patterns

  /// The shape of a rule, or nil when none of the defining keys is present.
  public static func of(_ rule: [String: Any]) -> GrammarRuleShape? {
    if rule["match"] != nil { return .match }
    if rule["begin"] != nil { return rule["while"] != nil ? .beginWhile : .beginEnd }
    if rule["include"] != nil { return .include }
    if rule["patterns"] != nil { return .patterns }
    return nil
  }
}
