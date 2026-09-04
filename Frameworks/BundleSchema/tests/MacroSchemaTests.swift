import BundleSchema
import Foundation
import Testing

/// A macro fixture next to this file, loaded the way the bundle loader loads it.
private func macroFixture(_ name: String) throws -> [String: Any] {
  let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appending(path: "fixtures/\(name)")
  let data = try Data(contentsOf: url)
  let plist = try PropertyListSerialization.propertyList(from: data, format: nil)
  return try #require(plist as? [String: Any])
}

@Suite struct MacroSchemaTables {
  @Test func keyNamesAreUnique() {
    for keys in [MacroSchema.itemKeys, MacroSchema.stepKeys] {
      let names = keys.map(\.name)
      #expect(Set(names).count == names.count)
    }
  }

  @Test func selectorsEndInAColon() {
    #expect(MacroValidator.isSelector("insertText:"))
    #expect(MacroValidator.isSelector("moveToEndOfDocumentAndModifySelection:"))
    #expect(!MacroValidator.isSelector("insert text"))
    #expect(!MacroValidator.isSelector("insertText"))
    #expect(!MacroValidator.isSelector(":"))
    #expect(!MacroValidator.isSelector("find:with:"))
  }
}

@Suite struct MacroValidation {
  @Test func aRealMacroHasNoIssues() throws {
    let issues = MacroValidator().issues(in: try macroFixture("FormatCSS.tmMacro"))
    #expect(issues.isEmpty, "\(issues)")
  }

  @Test func reportsEachKindOfProblem() throws {
    let issues = MacroValidator().issues(in: try macroFixture("Broken.tmMacro"))
    let messages = Set(issues.map(\.description))

    #expect(messages.contains("flavour: not a macro key"))
    #expect(messages.contains("commands[0]: a step needs a command"))
    #expect(messages.contains("commands[1].command: insert text is not a selector"))
    #expect(messages.contains("commands[2]: repeat is not a step key"))
    #expect(messages.contains("commands[3]: not a step"))
  }
}
