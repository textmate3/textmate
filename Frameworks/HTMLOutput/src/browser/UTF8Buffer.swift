/// Text arriving in arbitrary byte chunks from a command's output, assembled into whole characters.
///
/// A chunk may end in the middle of a multibyte character, so those bytes are held back until the rest
/// arrives. Bytes that are not UTF-8 at all are dropped, since a page can show text but not bytes.
struct UTF8Buffer {
  /// Everything appended so far, as text, apart from the held back tail.
  private(set) var text = ""
  private var pending: [UInt8] = []

  /// Takes in the bytes and returns the text they completed, which is also added to the whole.
  mutating func append(_ bytes: some Sequence<UInt8>) -> String {
    pending.append(contentsOf: bytes)
    let complete = pending.count - Self.incompleteTailLength(of: pending)

    var chunk = ""
    var iterator = pending[..<complete].makeIterator()
    var parser = Unicode.UTF8.ForwardParser()
    parsing: while true {
      switch parser.parseScalar(from: &iterator) {
      case .valid(let encoded):
        chunk.unicodeScalars.append(Unicode.UTF8.decode(encoded))
      case .error:
        continue
      case .emptyInput:
        break parsing
      }
    }

    pending.removeFirst(complete)
    text += chunk
    return chunk
  }

  /// How many bytes at the end begin a character that the bytes so far do not finish: a lead byte
  /// within the last three positions, with nothing but continuation bytes after it, and fewer of them
  /// than the lead byte announces.
  private static func incompleteTailLength(of bytes: [UInt8]) -> Int {
    for distance in 1...min(3, max(bytes.count, 1)) where distance <= bytes.count {
      let byte = bytes[bytes.count - distance]
      if byte & 0xC0 == 0x80 {
        continue
      }
      let expected: Int
      switch byte {
      case 0xC2...0xDF: expected = 2
      case 0xE0...0xEF: expected = 3
      case 0xF0...0xF4: expected = 4
      default: return 0
      }
      return distance < expected ? distance : 0
    }
    return 0
  }
}
