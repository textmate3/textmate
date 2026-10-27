import Testing
@testable import OakFilterList

/// The ranker face answers as the C++ ranker does, which has its own tests over the scoring.
/// These check the face: the score comes through, the ranges land on the matched bytes, and a miss is nil.
@Suite struct TMRankerTests {
  private func score(_ filter: String, _ candidate: String) -> Double {
    TMRanker.rankFilter(filter, candidate: candidate)?.score ?? 0
  }

  @Test func capitalsCoverTheFilter() {
    #expect(score("otv", "OTVStatusBar.mm") < score("otv", "OakTextView.mm"))
  }

  @Test func closerToTheStartRanksHigher() {
    #expect(score("doc", "OakDocument.mm") < score("doc", "document.cc"))
  }

  @Test func aFullMatchRanksHighest() {
    #expect(score("rmate", "RMateServer.cc") < score("rmate", "rmate"))
  }

  @Test func aCandidateWithoutTheFilterIsNil() {
    #expect(TMRanker.rankFilter("xyz", candidate: "OakTextView.mm") == nil)
  }

  @Test func theRangesLandOnTheMatchedBytes() throws {
    let match = try #require(TMRanker.rankFilter("rmate", candidate: "rmate"))
    #expect(match.byteRanges.map(\.rangeValue) == [NSRange(location: 0, length: 5)])
  }

  @Test func theFilterIsNormalized() {
    #expect(TMRanker.normalizeFilter("Oak Text") == "oaktext")
  }
}
