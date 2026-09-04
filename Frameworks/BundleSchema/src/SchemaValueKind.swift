/// What kind of value a key holds. A form builds one field per kind, and a
/// validator checks each kind its own way.
public enum SchemaValueKind: Sendable, Equatable {
  /// Free text, such as a comment or an item name.
  case text

  /// An Oniguruma regular expression, as `match`, `begin`, `end` and `while` hold.
  case regularExpression

  /// A scope name such as `source.ruby` or `string.quoted.double`,
  /// which may interpolate captures, as `name` and `contentName` hold.
  case scopeName

  /// A scope selector, as `injectionSelector`, the keys of `injections`,
  /// and a theme setting's `scope` hold.
  case scopeSelector

  /// True or false. Property lists write these as booleans or as the integers 0 and 1.
  case boolean

  /// A list of strings, as `fileTypes` holds.
  case textList

  /// A color as `#RRGGBB` or `#RRGGBBAA`, as a theme's settings hold.
  case color

  /// Words from `plain`, `bold`, `italic`, `underline` and `strikethrough`,
  /// separated by spaces, as a theme's `fontStyle` holds.
  case fontStyle

  /// Capture number or name to rule, as `captures` and its begin, end and while forms hold.
  case captures

  /// An ordered list of rules.
  case patterns

  /// Name to rule, as `repository` holds.
  case repository

  /// Scope selector to rule, as `injections` holds.
  case injections

  /// A reference to another rule: `$self`, `$base`, `#name` in a repository,
  /// another grammar's scope name, or `scope#name`.
  case include

  /// A list of dictionaries with a schema of their own, as a theme's
  /// `settings` holds.
  case list

  /// A dictionary with a schema of its own, as a theme's `gutterSettings` holds.
  case dictionary
}
