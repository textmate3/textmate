import Testing
import Foundation
@testable import OakFilterList

// What a person picked the last time they typed a given abbreviation. Every
// chooser reads this on every keystroke, and none of it had tests.

@Suite struct OakAbbreviationsTests {
  private func abbreviations() -> OakAbbreviations {
    let name = "OakAbbreviationsTests-\(UUID().uuidString)"
    return OakAbbreviations(name: name, defaults: UserDefaults(suiteName: name)!)
  }

  @Test func nothingIsRememberedToStartWith() {
    #expect(abbreviations().strings(forAbbreviation: "fcm").isEmpty)
  }

  @Test func aPickIsRememberedForItsAbbreviation() {
    let remembered = abbreviations()
    remembered.learn(abbreviation: "fcm", forString: "/src/FileChooser.mm")
    #expect(remembered.strings(forAbbreviation: "fcm") == ["/src/FileChooser.mm"])
  }

  @Test func anExactMatchComesBeforeAPrefixMatch() {
    let remembered = abbreviations()
    remembered.learn(abbreviation: "fcmm", forString: "/long")
    remembered.learn(abbreviation: "fcm", forString: "/exact")
    #expect(remembered.strings(forAbbreviation: "fcm") == ["/exact", "/long"])
  }

  @Test func anAbbreviationThatIsNotAPrefixIsNotOffered() {
    let remembered = abbreviations()
    remembered.learn(abbreviation: "zzz", forString: "/other")
    #expect(remembered.strings(forAbbreviation: "fcm").isEmpty)
  }

  @Test func anEmptyAbbreviationMatchesNothing() {
    // Every remembered pick has an empty prefix, so answering them all would
    // put the whole list in front of the ranker's own answer.
    let remembered = abbreviations()
    remembered.learn(abbreviation: "fcm", forString: "/one")
    #expect(remembered.strings(forAbbreviation: "").isEmpty)
  }

  @Test func anEmptyAbbreviationIsNotLearned() {
    let remembered = abbreviations()
    remembered.learn(abbreviation: "", forString: "/one")
    #expect(remembered.rememberedStrings.isEmpty)
  }

  @Test func anEmptyStringIsNotLearned() {
    let remembered = abbreviations()
    remembered.learn(abbreviation: "fcm", forString: "")
    #expect(remembered.rememberedStrings.isEmpty)
  }

  @Test func theNewestPickComesFirst() {
    let remembered = abbreviations()
    remembered.learn(abbreviation: "fcm", forString: "/first")
    remembered.learn(abbreviation: "fcm", forString: "/second")
    #expect(remembered.strings(forAbbreviation: "fcm") == ["/second", "/first"])
  }

  @Test func repeatingAPickMovesItRatherThanRecordingItTwice() {
    let remembered = abbreviations()
    remembered.learn(abbreviation: "fcm", forString: "/first")
    remembered.learn(abbreviation: "fcm", forString: "/second")
    remembered.learn(abbreviation: "fcm", forString: "/first")
    #expect(remembered.strings(forAbbreviation: "fcm") == ["/first", "/second"])
  }

  @Test func theListIsTrimmedAsItGrows() {
    // The class this replaces trimmed only when the application terminated, so
    // the list grew without limit for as long as it ran, and every keystroke
    // searched all of it.
    let remembered = abbreviations()
    for number in 1...(OakAbbreviations.limit + 10) {
      remembered.learn(abbreviation: "a\(number)", forString: "/file\(number)")
    }
    #expect(remembered.rememberedStrings.count == OakAbbreviations.limit)
  }

  @Test func theOldestPicksAreTheOnesForgotten() {
    let remembered = abbreviations()
    for number in 1...(OakAbbreviations.limit + 1) {
      remembered.learn(abbreviation: "a\(number)", forString: "/file\(number)")
    }
    #expect(remembered.strings(forAbbreviation: "a1").isEmpty)
    #expect(!remembered.strings(forAbbreviation: "a2").isEmpty)
  }

  @Test func aPickSurvivesBeingReadBackFromDefaults() {
    // Written on every pick rather than at termination, so quitting any way
    // other than by choosing Quit no longer loses the lot.
    let name = "OakAbbreviationsTests-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: name)!

    OakAbbreviations(name: name, defaults: defaults).learn(abbreviation: "fcm", forString: "/src/FileChooser.mm")

    let reopened = OakAbbreviations(name: name, defaults: defaults)
    #expect(reopened.strings(forAbbreviation: "fcm") == ["/src/FileChooser.mm"])
  }

  @Test func aMalformedEntryIsIgnoredRatherThanCrashing() {
    let name = "OakAbbreviationsTests-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: name)!
    defaults.set([["short": "fcm"], ["short": "ok", "long": "/kept"]], forKey: name)

    #expect(OakAbbreviations(name: name, defaults: defaults).rememberedStrings == ["/kept"])
  }

  @Test func eachChooserRemembersUnderItsOwnName() {
    let files = OakAbbreviations.abbreviations(forName: "OakFileChooserBindings")
    let items = OakAbbreviations.abbreviations(forName: "OakBundleItemChooserBindings")
    #expect(files !== items)
    #expect(files === OakAbbreviations.abbreviations(forName: "OakFileChooserBindings"))
  }
}
