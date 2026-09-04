/// The grammar format as data: which keys a grammar and a rule may carry,
/// what each holds, and which keys go together.
/// The parser in Frameworks/parse reads exactly the rule keys listed here.
/// Everything that edits or checks a grammar builds on these tables rather than on its own list.
public enum GrammarSchema {
  /// The keys of a grammar's top level, the `.tmLanguage` dictionary.
  public static let grammarKeys: [SchemaKey] = [
    SchemaKey("name", .text, "The grammar's name in menus."),
    SchemaKey("scopeName", .scopeName, "The scope every document in this language has, such as source.ruby."),
    SchemaKey("fileTypes", .textList, "File extensions and names this grammar opens by default."),
    SchemaKey("firstLineMatch", .regularExpression, "Matched against the first line to pick this grammar for files without a known type."),
    SchemaKey("foldingStartMarker", .regularExpression, "A line matching this starts a foldable region."),
    SchemaKey("foldingStopMarker", .regularExpression, "A line matching this ends a foldable region."),
    SchemaKey("foldingIndentedBlockStart", .regularExpression, "A line matching this starts a region folded by indentation."),
    SchemaKey("foldingIndentedBlockIgnore", .regularExpression, "Lines matching this do not end an indented region."),
    SchemaKey("patterns", .patterns, "The rules tried at the top level, in order."),
    SchemaKey("repository", .repository, "Named rules that patterns include by #name."),
    SchemaKey("injections", .injections, "Rules injected wherever a scope selector matches."),
    SchemaKey("injectionSelector", .scopeSelector, "Where this whole grammar is injected into other grammars."),
    SchemaKey("comment", .text, "A note for whoever edits the grammar."),
    SchemaKey("uuid", .text, "The bundle item's identifier."),
    SchemaKey("keyEquivalent", .text, "The keyboard shortcut that switches a document to this grammar."),
    SchemaKey("hideFromUser", .boolean, "Leaves the grammar out of the language menu."),
  ]

  /// The keys a rule may carry, anywhere rules appear:
  /// patterns, captures, repository entries and injections.
  public static let ruleKeys: [SchemaKey] = [
    SchemaKey("name", .scopeName, "The scope given to what the rule matches."),
    SchemaKey("contentName", .scopeName, "The scope given to what lies between begin and end, not including them."),
    SchemaKey("match", .regularExpression, "A single line match."),
    SchemaKey("begin", .regularExpression, "Where a multi line region starts."),
    SchemaKey("end", .regularExpression, "Where the region ends. May refer back to begin's captures."),
    SchemaKey("while", .regularExpression, "The region continues on each line matching this."),
    SchemaKey("captures", .captures, "Scopes for match's captures, or for both begin's and end's."),
    SchemaKey("beginCaptures", .captures, "Scopes for begin's captures."),
    SchemaKey("endCaptures", .captures, "Scopes for end's captures."),
    SchemaKey("whileCaptures", .captures, "Scopes for while's captures."),
    SchemaKey("patterns", .patterns, "Rules tried inside the region, in order."),
    SchemaKey("repository", .repository, "Named rules that this rule's patterns include by #name."),
    SchemaKey("include", .include, "Use another rule here: $self, $base, #name, or a scope name."),
    SchemaKey("applyEndPatternLast", .boolean, "Try the inner patterns before end at the same position."),
    SchemaKey("disabled", .boolean, "Skip this rule as if it were not there."),
    SchemaKey("comment", .text, "A note for whoever edits the grammar."),
  ]

  /// Pairs of rule keys that cannot appear together.
  public static let exclusiveRuleKeys: [(String, String)] = [
    ("match", "begin"),
    ("match", "end"),
    ("match", "while"),
    ("end", "while"),
    ("include", "match"),
    ("include", "begin"),
  ]

  /// Rule keys that mean nothing without another key present.
  public static let requiredRuleKeys: [String: String] = [
    "end": "begin",
    "while": "begin",
    "beginCaptures": "begin",
    "endCaptures": "end",
    "whileCaptures": "while",
    "applyEndPatternLast": "end",
    "contentName": "begin",
  ]

  public static func grammarKey(named name: String) -> SchemaKey? {
    grammarKeys.first { $0.name == name }
  }

  public static func ruleKey(named name: String) -> SchemaKey? {
    ruleKeys.first { $0.name == name }
  }
}
