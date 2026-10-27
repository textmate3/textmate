import Testing
@testable import OakFilterList

/// The symbol chooser's reading of a selection: which symbol the selection is in, by position.
@Suite @MainActor struct SymbolChooserTests {
  private func position(_ string: String) -> TMTextPosition {
    TMDocumentSymbols.rangeStarts(inSelectionString: string)[0]
  }

  @Test func aSelectionStringParsesToWhereEachRangeBegins() {
    let starts = TMDocumentSymbols.rangeStarts(inSelectionString: "3:4&10:2-12:1")
    #expect(starts.map(\.string) == ["3:4", "10:2"])
    #expect(starts[0].line == 2)
    #expect(starts[0].column == 3)
  }

  @Test func aReversedRangeBeginsAtItsLowerEnd() {
    #expect(TMDocumentSymbols.rangeStarts(inSelectionString: "12:1-10:2").map(\.string) == ["10:2"])
  }

  @Test func theSymbolAtOrBeforeTheSelectionIsChosen() {
    let positions = ["1", "5", "9:3"].map(position)
    #expect(SymbolChooser.indexOfSymbol(forRangeStarts: [position("5")], amongPositions: positions) == 1)
    #expect(SymbolChooser.indexOfSymbol(forRangeStarts: [position("7")], amongPositions: positions) == 1)
    #expect(SymbolChooser.indexOfSymbol(forRangeStarts: [position("9:3")], amongPositions: positions) == 2)
    #expect(SymbolChooser.indexOfSymbol(forRangeStarts: [position("9:2")], amongPositions: positions) == 1)
  }

  @Test func aSelectionBeforeEverySymbolChoosesNothing() {
    let positions = ["5", "9"].map(position)
    #expect(SymbolChooser.indexOfSymbol(forRangeStarts: [position("1")], amongPositions: positions) == nil)
  }

  @Test func theLastRangeWinsUnlessItIsBeforeEverySymbol() {
    let positions = ["5", "9"].map(position)
    #expect(SymbolChooser.indexOfSymbol(forRangeStarts: [position("6"), position("20")], amongPositions: positions) == 1)
    #expect(SymbolChooser.indexOfSymbol(forRangeStarts: [position("6"), position("1")], amongPositions: positions) == 0)
  }

  @Test func withoutADocumentThereAreNoItems() {
    let chooser = SymbolChooser()
    chooser.updateItems(nil)
    #expect(chooser.items.isEmpty)
    #expect(chooser.window?.title == "Jump to Symbol")
  }
}
