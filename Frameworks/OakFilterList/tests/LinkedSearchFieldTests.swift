import Foundation
import Testing
@testable import OakFilterList

/// The search field's accessibility padding: a space on either side of the text as assistive clients see it,
/// and the ranges they ask about translated back and forth.
@Suite @MainActor struct LinkedSearchFieldTests {
  @Test func aRangeInsideTheTextShiftsLeftByTheMargin() {
    let padded = PaddedRange(NSRange(location: 2, length: 3), length: 5)
    #expect(padded == PaddedRange(NSRange(location: 2, length: 3), length: 5))
    #expect(padded.range == NSRange(location: 1, length: 3))
    #expect(padded.left == 0 && padded.right == 0)
  }

  @Test func aRangeThatCoversAMarginReportsIt() {
    let fromStart = PaddedRange(NSRange(location: 0, length: 3), length: 5)
    #expect(fromStart.left == 1)
    #expect(fromStart.range == NSRange(location: 0, length: 2))

    let toEnd = PaddedRange(NSRange(location: 4, length: 3), length: 5)
    #expect(toEnd.right == 1)
    #expect(toEnd.range == NSRange(location: 3, length: 2))
  }

  @Test func anEmptyRangeInAMarginLandsAtTheNearestEnd() {
    #expect(PaddedRange(NSRange(location: 0, length: 0), length: 5).range == NSRange(location: 0, length: 0))
    #expect(PaddedRange(NSRange(location: 6, length: 0), length: 5).range == NSRange(location: 5, length: 0))
    #expect(PaddedRange(NSRange(location: 3, length: 0), length: 5).range == NSRange(location: 2, length: 0))
  }

  @Test func aRangePastTheEndIsCutDown() {
    let padded = PaddedRange(NSRange(location: 4, length: 10), length: 5)
    #expect(padded.range == NSRange(location: 3, length: 2))
    #expect(padded.right == 1)
  }

  @Test func theFieldTellsAssistiveClientsAboutPaddedText() throws {
    let field = LinkedSearchField(frame: .zero)
    field.stringValue = "abc"
    let cell = try #require(field.cell as? LinkedSearchFieldCell)
    #expect(cell.accessibilityValue() as? String == " abc ")
    #expect(cell.accessibilityNumberOfCharacters() == 5)
    #expect(cell.accessibilityString(for: NSRange(location: 0, length: 5)) == " abc ")
    #expect(cell.accessibilityString(for: NSRange(location: 1, length: 2)) == "ab")
    #expect(cell.accessibilityHelp()?.hasPrefix("Type filter string") == true)
  }
}
