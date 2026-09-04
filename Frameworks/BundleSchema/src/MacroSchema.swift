/// The macro format as data: the keys a `.tmMacro` carries and the keys of
/// each recorded step in its `commands` list. A step is a selector the text
/// view performed, with the argument it was given: nothing for a plain
/// action, text for typed text, a dictionary for a command run with
/// options. The text view records exactly this and plays it back as is.
public enum MacroSchema {
  /// The keys of a macro's top level.
  public static let itemKeys: [SchemaKey] = [
    SchemaKey("name", .text, "The macro's name in menus."),
    SchemaKey("scope", .scopeSelector, "Where the macro is offered."),
    SchemaKey("scopeType", .text, "local for a macro recorded in one document."),
    SchemaKey("keyEquivalent", .text, "The keyboard shortcut that plays the macro."),
    SchemaKey("tabTrigger", .text, "Text that, followed by tab, plays the macro."),
    SchemaKey("semanticClass", .scopeName, "A class other bundles can look the macro up by."),
    SchemaKey("commands", .list, "The recorded steps, in order."),
    SchemaKey("uuid", .text, "The bundle item's identifier."),
    SchemaKey("comment", .text, "A note for whoever edits the macro."),
    SchemaKey("bundleUUID", .text, "The bundle's identifier, which older items carry."),
  ]

  /// The keys of one recorded step.
  public static let stepKeys: [SchemaKey] = [
    SchemaKey("command", .text, "The action the text view performed, as a selector such as insertText: or moveRight:."),
    SchemaKey("argument", .any, "What the action was given: the text typed, or a command's options."),
  ]

  public static func itemKey(named name: String) -> SchemaKey? {
    itemKeys.first { $0.name == name }
  }

  public static func stepKey(named name: String) -> SchemaKey? {
    stepKeys.first { $0.name == name }
  }
}
