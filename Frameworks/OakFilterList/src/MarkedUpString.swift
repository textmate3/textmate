import AppKit

/// A chooser row's text with the parts the filter matched marked up: a background and an underline on each.
/// The ranges are byte offsets into the text's UTF-8, which is what the ranker reports.
func markedUpString(_ text: String, byteRanges: [NSRange], lineBreakMode: NSLineBreakMode = .byTruncatingMiddle) -> NSMutableAttributedString {
  let paragraphStyle = NSMutableParagraphStyle()
  paragraphStyle.lineBreakMode = lineBreakMode

  let baseAttributes: [NSAttributedString.Key: Any] = [.paragraphStyle: paragraphStyle]
  let highlightAttributes: [NSAttributedString.Key: Any] = [
    .paragraphStyle: paragraphStyle,
    .backgroundColor: NSColor.tmMatchedTextBackground(),
    .underlineStyle: NSUnderlineStyle.single.rawValue,
    .underlineColor: NSColor.tmMatchedTextUnderline(),
  ]

  // A range that cuts a character in two is not text, and shows as a question mark the way it always has.
  let bytes = Array(text.utf8)
  func piece(_ range: Range<Int>) -> String {
    String(bytes: bytes[range.clamped(to: 0..<bytes.count)], encoding: .utf8) ?? "?"
  }

  let result = NSMutableAttributedString()
  var from = 0
  for range in byteRanges {
    result.append(NSAttributedString(string: piece(from..<range.location), attributes: baseAttributes))
    result.append(NSAttributedString(string: piece(range.location..<NSMaxRange(range)), attributes: highlightAttributes))
    from = NSMaxRange(range)
  }
  if from < bytes.count {
    result.append(NSAttributedString(string: piece(from..<bytes.count), attributes: baseAttributes))
  }
  return result
}
