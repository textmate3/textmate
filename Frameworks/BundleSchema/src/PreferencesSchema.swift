/// The preferences format as data: the keys a `.tmPreferences` carries and
/// every key its `settings` dictionary may hold, grouped as a form shows
/// them. Each setting is read by one place in the application, by scope,
/// through `bundles::value_for_setting`: the indent, folding, selection,
/// completion, symbol, layout and theme code. Those readers are the source
/// of these tables.
public enum PreferencesSchema {
  /// The keys of a preferences item's top level.
  public static let itemKeys: [SchemaKey] = [
    SchemaKey("name", .text, "The item's name in the bundle editor."),
    SchemaKey("scope", .scopeSelector, "Where these settings apply."),
    SchemaKey("settings", .dictionary, "The settings themselves."),
    SchemaKey("uuid", .text, "The bundle item's identifier."),
    SchemaKey("comment", .text, "A note for whoever edits the item."),
    SchemaKey("bundleUUID", .text, "The bundle's identifier, which older items carry."),
  ]

  /// The setting keys, in the groups a form shows.
  public static let groups: [SchemaGroup] = [
    SchemaGroup(
      "Indentation",
      [
        SchemaKey("increaseIndentPattern", .regularExpression, "A line matching this indents the next line."),
        SchemaKey("decreaseIndentPattern", .regularExpression, "A line matching this is outdented."),
        SchemaKey("indentNextLinePattern", .regularExpression, "A line matching this indents only the next line."),
        SchemaKey("unIndentedLinePattern", .regularExpression, "Lines matching this are left out of indent decisions."),
        SchemaKey("zeroIndentPattern", .regularExpression, "Lines matching this go to column zero."),
        SchemaKey("disableIndentCorrections", .boolean, "Leaves indentation alone while typing. The string emptyLines corrects only lines with text."),
        SchemaKey("indentOnPaste", .choice(["simple", "disable"]), "simple shifts pasted lines to the caret's indent, disable leaves them as they are, unset re-indents them by the patterns."),
      ]),
    SchemaGroup(
      "Folding",
      [
        SchemaKey("foldingStartMarker", .regularExpression, "A line matching this starts a foldable region."),
        SchemaKey("foldingStopMarker", .regularExpression, "A line matching this ends a foldable region."),
        SchemaKey("foldingIndentedBlockStart", .regularExpression, "A line matching this starts a region folded by indentation."),
        SchemaKey("foldingIndentedBlockIgnore", .regularExpression, "Lines matching this do not end an indented region."),
      ]),
    SchemaGroup(
      "Typing",
      [
        SchemaKey("smartTypingPairs", .pairs, "Typing the opener inserts the closer after the caret."),
        SchemaKey("highlightPairs", .pairs, "Pairs the caret jumps between and the editor flashes."),
        SchemaKey("characterClass", .text, "A word for what the characters in this scope are, so a double click selects them together."),
        SchemaKey("wordCharacters", .text, "Characters that count as part of a word in this scope."),
        SchemaKey("excludeFromParagraphSelection", .boolean, "Lines in this scope end a paragraph selection."),
      ]),
    SchemaGroup(
      "Symbols",
      [
        SchemaKey("showInSymbolList", .boolean, "Text in this scope is a symbol, shown in the symbol list."),
        SchemaKey("symbolTransformation", .text, "Substitutions applied to the symbol's text before it is shown, one s/…/…/ per line."),
      ]),
    SchemaGroup(
      "Completion",
      [
        SchemaKey("completions", .textList, "Words offered when nothing better is found."),
        SchemaKey("completionCommand", .text, "A shell command whose output lines are the completions."),
        SchemaKey("disableDefaultCompletion", .boolean, "Leaves out words from the document."),
      ]),
    SchemaGroup(
      "Wrapping",
      [
        SchemaKey("softWrap", .boolean, "Wraps long lines in this scope."),
        SchemaKey("indentedSoftWrap", .dictionary, "What a wrapped line's continuation is indented by."),
      ]),
    SchemaGroup(
      "Spelling",
      [
        SchemaKey("spellChecking", .boolean, "Checks spelling in this scope.")
      ]),
    SchemaGroup(
      "Environment",
      [
        SchemaKey("shellVariables", .shellVariables, "Variables set for commands run in this scope.")
      ]),
    SchemaGroup(
      "Style",
      [
        SchemaKey("fontName", .text, "A font for this scope."),
        SchemaKey("fontSize", .text, "A size for this scope, in points or as a factor such as 1.2em."),
        SchemaKey("foreground", .color, "The text color."),
        SchemaKey("background", .color, "The background behind the text."),
        SchemaKey("caret", .color, "The insertion point."),
        SchemaKey("selection", .color, "Selected text's background."),
        SchemaKey("invisibles", .color, "Tabs, spaces and line endings when shown."),
        SchemaKey("lineHighlight", .color, "The current line's background."),
        SchemaKey("bold", .boolean, "Bold text."),
        SchemaKey("italic", .boolean, "Italic text."),
        SchemaKey("underline", .boolean, "Underlined text."),
        SchemaKey("strikethrough", .boolean, "Struck through text."),
        SchemaKey("misspelled", .boolean, "Draws the misspelling underline."),
      ]),
  ]

  /// Every setting key, in group order.
  public static let settingKeys: [SchemaKey] = groups.flatMap(\.keys)

  /// The keys of `indentedSoftWrap`.
  public static let indentedSoftWrapKeys: [SchemaKey] = [
    SchemaKey("match", .regularExpression, "Matched against the line's start. What it captures feeds the format."),
    SchemaKey("format", .text, "The continuation's indent, built from the match's captures, such as $0 for the whole match."),
  ]

  /// The keys of one entry in `shellVariables`.
  public static let shellVariableKeys: [SchemaKey] = [
    SchemaKey("name", .text, "The variable's name."),
    SchemaKey("value", .text, "The variable's value."),
    SchemaKey("disabled", .boolean, "Leaves the variable out."),
  ]

  public static func itemKey(named name: String) -> SchemaKey? {
    itemKeys.first { $0.name == name }
  }

  public static func settingKey(named name: String) -> SchemaKey? {
    settingKeys.first { $0.name == name }
  }
}
