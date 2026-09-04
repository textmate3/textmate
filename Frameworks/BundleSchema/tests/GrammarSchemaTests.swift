import BundleSchema
import Foundation
import Testing

/// A grammar fixture next to this file, loaded the way the bundle loader loads it:
/// an XML property list into a dictionary.
private func fixture(_ name: String) throws -> [String: Any] {
  let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appending(path: "fixtures/\(name)")
  let data = try Data(contentsOf: url)
  let plist = try PropertyListSerialization.propertyList(from: data, format: nil)
  return try #require(plist as? [String: Any])
}

@Suite struct GrammarSchemaTables {
  @Test func keyNamesAreUnique() {
    let grammarNames = GrammarSchema.grammarKeys.map(\.name)
    let ruleNames = GrammarSchema.ruleKeys.map(\.name)
    #expect(Set(grammarNames).count == grammarNames.count)
    #expect(Set(ruleNames).count == ruleNames.count)
  }

  @Test func ruleKeysAreTheOnesTheParserReads() {
    let parserKeys: Set = [
      "name", "scopeName", "contentName", "match", "begin", "while", "end", "applyEndPatternLast", "include",
      "patterns", "captures", "beginCaptures", "whileCaptures", "endCaptures", "repository", "injections", "disabled",
    ]
    let ruleNames = Set(GrammarSchema.ruleKeys.map(\.name))
    // scopeName and injections are read by the same code but belong to the grammar level.
    #expect(parserKeys.subtracting(["scopeName", "injections"]).isSubset(of: ruleNames))
  }

  @Test func everyExclusiveAndRequiredKeyIsARuleKey() {
    for (first, second) in GrammarSchema.exclusiveRuleKeys {
      #expect(GrammarSchema.ruleKey(named: first) != nil)
      #expect(GrammarSchema.ruleKey(named: second) != nil)
    }
    for (key, required) in GrammarSchema.requiredRuleKeys {
      #expect(GrammarSchema.ruleKey(named: key) != nil)
      #expect(GrammarSchema.ruleKey(named: required) != nil)
    }
  }
}

@Suite struct GrammarRuleShapes {
  @Test func shapeFollowsTheDefiningKey() {
    #expect(GrammarRuleShape.of(["match": "a"]) == .match)
    #expect(GrammarRuleShape.of(["begin": "a", "end": "b"]) == .beginEnd)
    #expect(GrammarRuleShape.of(["begin": "a", "while": "b"]) == .beginWhile)
    #expect(GrammarRuleShape.of(["include": "#a"]) == .include)
    #expect(GrammarRuleShape.of(["patterns": []]) == .patterns)
    #expect(GrammarRuleShape.of(["comment": "nothing here"]) == nil)
  }
}

@Suite struct GrammarValidation {
  @Test func aRealGrammarHasNoIssues() throws {
    let issues = GrammarValidator().issues(in: try fixture("JSON.tmLanguage"))
    #expect(issues.isEmpty, "\(issues)")
  }

  @Test func reportsEachKindOfConflict() throws {
    let issues = GrammarValidator().issues(in: try fixture("Conflicts.tmLanguage"))
    let messages = Set(issues.map(\.description))

    #expect(messages.contains("colour: not a grammar key"))
    #expect(messages.contains("patterns[0]: match and begin cannot both be present"))
    #expect(messages.contains("patterns[1]: end needs begin"))
    #expect(messages.contains("patterns[2]: begin needs end or while"))
    #expect(messages.contains("patterns[3].include: no repository rule named missing"))
    #expect(messages.contains("repository.present: flavour is not a rule key"))

    // #present resolves through the grammar's repository,
    // and #inner through the enclosing rule's, but not from outside that rule.
    #expect(!messages.contains { $0.hasPrefix("patterns[4]") })
    #expect(!messages.contains { $0.hasPrefix("patterns[5]") })
    #expect(messages.contains("patterns[6].include: no repository rule named inner"))
  }

  @Test func acceptsIntegersForBooleans() {
    let issues = GrammarValidator().issues(in: [
      "scopeName": "source.x",
      "patterns": [["begin": "a", "end": "b", "applyEndPatternLast": 1]],
    ])
    #expect(issues.isEmpty, "\(issues)")
  }

  @Test func reportsValuesOfTheWrongKind() {
    let issues = GrammarValidator().issues(in: [
      "scopeName": "source.x",
      "fileTypes": "rb",
      "patterns": [["match": 3]],
    ])
    let messages = Set(issues.map(\.description))
    #expect(messages.contains("fileTypes: should be a list of text"))
    #expect(messages.contains("patterns[0].match: should be text"))
  }
}
