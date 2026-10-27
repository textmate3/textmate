import Testing
@testable import HTMLOutput

/// The buffer assembles whole characters from bytes that arrive in any chunking,
/// and drops the bytes that are not UTF-8.
@Suite struct UTF8BufferTests {
  private static let good: [UInt8] = Array(
    """
    Surrogate: 𠻵
    Diacritics: c̄̌
    Thai: ไปกินปูดำที่บ้านกตัญญู
    Right-to-left: ومصادر اخرى ايضاً تُشير بأن اسم الآيفون سيكون
    Double width: 南野 繁弘

    """.utf8)

  /// The same text with stray bytes, truncated sequences and an overlong lead byte mixed in,
  /// ending in a sequence that is never finished.
  private static let bad: [UInt8] =
    Array("Surrogate: 𠻵\nDiacritics: ".utf8) + [0xFE] + Array("c̄̌".utf8) + [0xFE]
    + Array("\nThai: ไปกินปูดำที่บ้านกตัญญู".utf8) + [0xE2, 0x99]
    + Array("\nRight-to-left: ومصادر اخرى ايضاً تُشير بأن".utf8) + [0xC0, 0xFE]
    + Array(" اسم الآيفون سيكون\nDouble width: ".utf8) + [0xF0, 0xA0, 0xBB]
    + Array("南野 繁弘\n".utf8) + [0xE2, 0x99]

  private static let expected = String(decoding: good, as: UTF8.self)

  private func feed(_ source: [UInt8], chunkSize: Int) -> (streamed: String, whole: String) {
    var buffer = UTF8Buffer()
    var streamed = ""
    var first = 0
    while first < source.count {
      let next = min(first + chunkSize, source.count)
      streamed += buffer.append(source[first..<next])
      first = next
    }
    return (streamed, buffer.text)
  }

  @Test(arguments: 1...16) func wellFormedTextSurvivesAnyChunking(chunkSize: Int) {
    let result = feed(Self.good, chunkSize: chunkSize)
    #expect(result.streamed == Self.expected)
    #expect(result.whole == Self.expected)
  }

  @Test(arguments: 1...16) func malformedBytesAreDroppedUnderAnyChunking(chunkSize: Int) {
    let result = feed(Self.bad, chunkSize: chunkSize)
    #expect(result.streamed == Self.expected)
    #expect(result.whole == Self.expected)
  }

  @Test func aCharacterSplitAcrossChunksIsHeldBackUntilWhole() {
    var buffer = UTF8Buffer()
    let bytes = Array("é".utf8)
    #expect(buffer.append([bytes[0]]) == "")
    #expect(buffer.append([bytes[1]]) == "é")
    #expect(buffer.text == "é")
  }
}
