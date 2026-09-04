/// What kind of value a grammar key holds.
/// The form builds one field per kind,
/// and the validator checks each kind its own way.
public enum GrammarValueKind: Sendable, Equatable {
  /// Free text, such as a comment or an item name.
  case text

  /// An Oniguruma regular expression, as `match`, `begin`, `end` and `while` hold.
  case regularExpression

  /// A scope name such as `source.ruby` or `string.quoted.double`,
  /// which may interpolate captures, as `name` and `contentName` hold.
  case scopeName

  /// A scope selector, as `injectionSelector` and the keys of `injections` hold.
  case scopeSelector

  /// True or false. Grammars write these as booleans or as the integers 0 and 1.
  case boolean

  /// A list of strings, as `fileTypes` holds.
  case textList

  /// Capture number or name to rule, as `captures` and its begin, end and while forms hold.
  case captures

  /// An ordered list of rules.
  case patterns

  /// Name to rule, as `repository` holds.
  case repository

  /// Scope selector to rule, as `injections` holds.
  case injections

  /// A reference to another rule: `$self`, `$base`, `#name`
  /// in a repository, another grammar's scope name, or `scope#name`.
  case include
}
