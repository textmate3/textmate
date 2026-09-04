import BundleSchema
import Foundation
import Testing

/// A theme fixture next to this file, loaded the way the bundle loader loads it.
private func themeFixture(_ name: String) throws -> [String: Any] {
  let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appending(path: "fixtures/\(name)")
  let data = try Data(contentsOf: url)
  let plist = try PropertyListSerialization.propertyList(from: data, format: nil)
  return try #require(plist as? [String: Any])
}

@Suite struct ThemeSchemaTables {
  @Test func keyNamesAreUnique() {
    for keys in [ThemeSchema.themeKeys, ThemeSchema.entryKeys, ThemeSchema.styleKeys, ThemeSchema.gutterKeys] {
      let names = keys.map(\.name)
      #expect(Set(names).count == names.count)
    }
  }

  @Test func styleKeysCoverBothKindsOfEntry() {
    let all = Set(ThemeSchema.styleKeys.map(\.name))
    #expect(Set(ThemeSchema.pageStyleKeys.map(\.name)).isSubset(of: all))
    #expect(Set(ThemeSchema.scopedStyleKeys.map(\.name)).isSubset(of: all))
  }

  @Test func colorsAreHexWithAHash() {
    #expect(ThemeValidator.isColor("#181818"))
    #expect(ThemeValidator.isColor("#FFFFFF40"))
    #expect(ThemeValidator.isColor("#abc"))
    #expect(!ThemeValidator.isColor("181818"))
    #expect(!ThemeValidator.isColor("#18181"))
    #expect(!ThemeValidator.isColor("white"))
  }
}

@Suite struct ThemeValidation {
  @Test func aRealThemeHasNoIssues() throws {
    let issues = ThemeValidator().issues(in: try themeFixture("Twilight.tmTheme"))
    #expect(issues.isEmpty, "\(issues)")
  }

  @Test func reportsEachKindOfProblem() throws {
    let issues = ThemeValidator().issues(in: try themeFixture("Broken.tmTheme"))
    let messages = Set(issues.map(\.description))

    #expect(messages.contains("flavour: not a theme key"))
    #expect(messages.contains("settings[0].settings.foreground: should be a color as #RRGGBB or #RRGGBBAA"))
    #expect(messages.contains("settings[1].settings.fontStyle: wobbly is not a font style"))
    #expect(messages.contains("settings[2]: an entry needs settings"))
    #expect(messages.contains("settings[3]: not an entry"))
    #expect(messages.contains("gutterSettings: glow is not a gutter key"))
  }
}
