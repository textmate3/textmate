/// The theme format as data: the keys a `.tmTheme` carries, the keys of each
/// entry in its `settings` list, the style keys inside an entry, and the
/// gutter's colors. The theme code in Frameworks/theme reads exactly these.
public enum ThemeSchema {
  /// The keys of a theme's top level.
  public static let themeKeys: [SchemaKey] = [
    SchemaKey("name", .text, "The theme's name in menus."),
    SchemaKey("uuid", .text, "The bundle item's identifier."),
    SchemaKey("author", .text, "Who made the theme."),
    SchemaKey("comment", .text, "A note for whoever edits the theme."),
    SchemaKey("semanticClass", .scopeName, "A class such as theme.dark.twilight, so bundles can tell dark from light."),
    SchemaKey("hideFromUser", .boolean, "Leaves the theme out of the theme menu."),
    SchemaKey("colorSpaceName", .text, "sRGB to read colors as sRGB, otherwise they are generic RGB."),
    SchemaKey("settings", .list, "The page's colors first, then a style per scope selector, in order."),
    SchemaKey("gutterSettings", .dictionary, "The gutter's colors."),
  ]

  /// The keys of one entry in `settings`. The first entry has no scope and
  /// sets the page. Every other entry styles what its selector matches.
  public static let entryKeys: [SchemaKey] = [
    SchemaKey("name", .text, "What the entry is for, such as Comment or Keyword."),
    SchemaKey("scope", .scopeSelector, "The scopes this style applies to. Absent on the page entry."),
    SchemaKey("settings", .dictionary, "The style: colors and font style."),
    SchemaKey("comment", .text, "A note for whoever edits the theme."),
  ]

  /// The style keys of the page entry, the one without a scope.
  public static let pageStyleKeys: [SchemaKey] = [
    SchemaKey("background", .color, "The page background."),
    SchemaKey("foreground", .color, "Text with no other style."),
    SchemaKey("caret", .color, "The insertion point."),
    SchemaKey("selection", .color, "Selected text's background."),
    SchemaKey("invisibles", .color, "Tabs, spaces and line endings when shown."),
    SchemaKey("lineHighlight", .color, "The current line's background."),
    SchemaKey("fontName", .text, "A font for the whole page, when the theme wants one."),
    SchemaKey("fontSize", .text, "A size for the whole page, in points or as a factor such as 1.2em."),
  ]

  /// The style keys of a scoped entry.
  public static let scopedStyleKeys: [SchemaKey] = [
    SchemaKey("foreground", .color, "The text color."),
    SchemaKey("background", .color, "The background behind the text."),
    SchemaKey("fontStyle", .fontStyle, "bold, italic, underline, strikethrough, or plain to clear them."),
    SchemaKey("misspelled", .boolean, "Draws the misspelling underline."),
  ]

  /// Every style key either kind of entry may carry.
  public static let styleKeys: [SchemaKey] = {
    var keys = pageStyleKeys
    for key in scopedStyleKeys where !keys.contains(where: { $0.name == key.name }) {
      keys.append(key)
    }
    return keys
  }()

  /// The keys of `gutterSettings`, all colors.
  public static let gutterKeys: [SchemaKey] = [
    SchemaKey("background", .color, "The gutter's background."),
    SchemaKey("foreground", .color, "Line numbers."),
    SchemaKey("divider", .color, "The line between the gutter and the text."),
    SchemaKey("icons", .color, "Fold markers and bookmarks."),
    SchemaKey("iconsHover", .color, "Icons under the pointer."),
    SchemaKey("iconsPressed", .color, "Icons while pressed."),
    SchemaKey("selectionBackground", .color, "The gutter behind selected lines."),
    SchemaKey("selectionBorder", .color, "The edge of the gutter's selection."),
    SchemaKey("selectionForeground", .color, "Line numbers of selected lines."),
    SchemaKey("selectionIcons", .color, "Icons on selected lines."),
    SchemaKey("selectionIconsHover", .color, "Icons on selected lines under the pointer."),
    SchemaKey("selectionIconsPressed", .color, "Icons on selected lines while pressed."),
  ]

  /// The words `fontStyle` is made of.
  public static let fontStyleWords: [String] = ["plain", "bold", "italic", "underline", "strikethrough"]

  public static func themeKey(named name: String) -> SchemaKey? {
    themeKeys.first { $0.name == name }
  }

  public static func entryKey(named name: String) -> SchemaKey? {
    entryKeys.first { $0.name == name }
  }

  public static func styleKey(named name: String) -> SchemaKey? {
    styleKeys.first { $0.name == name }
  }

  public static func gutterKey(named name: String) -> SchemaKey? {
    gutterKeys.first { $0.name == name }
  }
}
