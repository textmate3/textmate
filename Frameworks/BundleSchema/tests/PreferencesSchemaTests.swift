import BundleSchema
import Foundation
import Testing

/// A preferences fixture next to this file, loaded the way the bundle loader loads it.
private func preferencesFixture(_ name: String) throws -> [String: Any] {
  let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appending(path: "fixtures/\(name)")
  let data = try Data(contentsOf: url)
  let plist = try PropertyListSerialization.propertyList(from: data, format: nil)
  return try #require(plist as? [String: Any])
}

@Suite struct PreferencesSchemaTables {
  @Test func settingKeyNamesAreUnique() {
    let names = PreferencesSchema.settingKeys.map(\.name)
    #expect(Set(names).count == names.count)
  }

  @Test func everyGroupHasKeys() {
    for group in PreferencesSchema.groups {
      #expect(!group.keys.isEmpty, "\(group.name)")
    }
  }

  @Test func theKeysTheApplicationReadsAreSettingKeys() {
    for name in ["increaseIndentPattern", "foldingStartMarker", "smartTypingPairs", "showInSymbolList", "completions", "softWrap", "spellChecking", "shellVariables", "characterClass", "fontName"] {
      #expect(PreferencesSchema.settingKey(named: name) != nil, "\(name)")
    }
  }

  @Test func booleansAsPropertyListsWriteThem() {
    #expect(PreferencesValidator.isBoolean(true))
    #expect(PreferencesValidator.isBoolean(1))
    #expect(PreferencesValidator.isBoolean("0"))
    #expect(PreferencesValidator.isBoolean("true"))
    #expect(!PreferencesValidator.isBoolean("maybe"))
  }
}

@Suite struct PreferencesValidation {
  @Test func aRealItemHasNoIssues() throws {
    let issues = PreferencesValidator().issues(in: try preferencesFixture("Ruby.tmPreferences"))
    #expect(issues.isEmpty, "\(issues)")
  }

  @Test func reportsEachKindOfProblem() throws {
    let issues = PreferencesValidator().issues(in: try preferencesFixture("Broken.tmPreferences"))
    let messages = Set(issues.map(\.description))

    #expect(messages.contains("flavour: not a preferences key"))
    #expect(messages.contains("settings.ptrn: not a setting key"))
    #expect(messages.contains("settings.indentOnPaste: sometimes is not one of simple, disable"))
    #expect(messages.contains("settings.smartTypingPairs: each pair should be two strings, an opener and a closer"))
    #expect(messages.contains("settings.softWrap: should be true or false"))
    #expect(messages.contains("settings.completions: should be a list of text"))
    #expect(messages.contains("settings.indentedSoftWrap.match: indented soft wrap needs match"))
    #expect(messages.contains("settings.shellVariables[0]: a variable needs a name"))
    #expect(messages.contains("settings.shellVariables[1]: not a variable"))
  }

  @Test func anItemWithoutSettingsIsReported() {
    let issues = PreferencesValidator().issues(in: ["name": "Empty"])
    #expect(issues.map(\.description) == ["settings: a preferences item needs settings"])
  }
}
