import AppKit

/// A range an assistive client asked for, in the padded text, taken apart into what falls in the left margin,
/// what falls in the real text, and what falls in the right margin.
struct PaddedRange: Equatable {
  var left: Int
  var range: NSRange
  var right: Int

  /// The padded text is a margin, the real text of the length given, then a margin. A range outside it all
  /// is cut down to it, where the Objective-C raised, since a client that asks for too much gets an answer
  /// either way and raising from an accessibility call takes the application down.
  init(_ requested: NSRange, length: Int, leftMargin: Int = 1, rightMargin: Int = 1) {
    let total = leftMargin + length + rightMargin
    var range = requested
    if NSMaxRange(range) > total {
      range.location = min(range.location, total)
      range.length = total - range.location
    }

    let leftMarginRange = NSRange(location: 0, length: leftMargin)
    let rightMarginRange = NSRange(location: leftMargin + length, length: rightMargin)
    let middleRange = NSRange(location: leftMargin, length: length)

    let leftRange = NSIntersectionRange(range, leftMarginRange)
    let rightRange = NSIntersectionRange(range, rightMarginRange)
    var baseRange = NSIntersectionRange(range, middleRange)
    if baseRange.length == 0 {
      if leftRange.length != 0 {
        baseRange.location = leftMargin
      } else if rightRange.length != 0 {
        baseRange.location = NSMaxRange(middleRange)
      } else {
        // An empty range at a margin is the nearest end of the real text. The Objective-C subtracted the margin
        // from an index inside the left margin and wrapped around below zero.
        baseRange.location = min(max(range.location, leftMargin), leftMargin + length)
      }
    }
    baseRange.location -= leftMargin

    left = leftRange.length
    self.range = baseRange
    right = rightRange.length
  }
}

private func spaces(_ count: Int) -> String {
  String(repeating: " ", count: count)
}

/// The cell behind the chooser's search field, which tells assistive clients the text has one space before it and
/// one after. That works around a VoiceOver fault, rdar://problem/16271507, where the first and last characters of a
/// search field were not read. Every range a client asks about comes in the padded text and is translated to the
/// real one, and every range handed back is shifted the other way. See also
/// https://lists.apple.com/archives/accessibility-dev/2014/Feb/msg00019.html
final class LinkedSearchFieldCell: NSSearchFieldCell {
  private var realLength: Int {
    super.accessibilityNumberOfCharacters()
  }

  override func accessibilityValue() -> Any? {
    " \((super.accessibilityValue() as? String) ?? "") "
  }

  override func accessibilityNumberOfCharacters() -> Int {
    1 + realLength + 1
  }

  override func accessibilitySelectedTextRange() -> NSRange {
    var range = super.accessibilitySelectedTextRange()
    range.location += 1
    return range
  }

  override func setAccessibilitySelectedTextRange(_ range: NSRange) {
    super.setAccessibilitySelectedTextRange(PaddedRange(range, length: realLength).range)
  }

  override func accessibilityVisibleCharacterRange() -> NSRange {
    var range = super.accessibilityVisibleCharacterRange()
    range.location += 1
    return range
  }

  override func setAccessibilityVisibleCharacterRange(_ range: NSRange) {
    super.setAccessibilityVisibleCharacterRange(PaddedRange(range, length: realLength).range)
  }

  override func accessibilityHelp() -> String? {
    "Type filter string, then hear search results using arrow up/down."
  }

  override func accessibilityAttributedString(for range: NSRange) -> NSAttributedString? {
    let padded = PaddedRange(range, length: realLength)
    guard let value = super.accessibilityAttributedString(for: padded.range) else { return nil }
    let string = NSMutableAttributedString(attributedString: value)
    if padded.left != 0 {
      string.insert(NSAttributedString(string: spaces(padded.left)), at: 0)
    }
    if padded.right != 0 {
      string.insert(NSAttributedString(string: spaces(padded.right)), at: string.length)
    }
    return string
  }

  override func accessibilityFrame(for range: NSRange) -> NSRect {
    super.accessibilityFrame(for: PaddedRange(range, length: realLength).range)
  }

  override func accessibilityLine(for index: Int) -> Int {
    super.accessibilityLine(for: PaddedRange(NSRange(location: index, length: 0), length: realLength).range.location)
  }

  override func accessibilityRange(for index: Int) -> NSRange {
    let padded = PaddedRange(NSRange(location: index, length: 0), length: realLength)
    if padded.left != 0 {
      return NSRange(location: 0, length: 1)
    }
    if padded.right != 0 {
      return NSRange(location: NSMaxRange(padded.range), length: 1)
    }
    var range = super.accessibilityRange(for: padded.range.location)
    range.location += 1
    return range
  }

  override func accessibilityRange(forLine line: Int) -> NSRange {
    var range = super.accessibilityRange(forLine: line)
    range.location += 1
    return range
  }

  override func accessibilityRange(for point: NSPoint) -> NSRange {
    var range = super.accessibilityRange(for: point)
    range.location += 1
    return range
  }

  override func accessibilityRTF(for range: NSRange) -> Data? {
    let padded = PaddedRange(range, length: realLength)
    guard let data = super.accessibilityRTF(for: padded.range) else { return nil }
    var documentAttributes: NSDictionary?
    guard let string = NSMutableAttributedString(rtf: data, documentAttributes: &documentAttributes) else { return nil }
    if padded.left != 0 {
      string.insert(NSAttributedString(string: spaces(padded.left)), at: 0)
    }
    if padded.right != 0 {
      string.insert(NSAttributedString(string: spaces(padded.right)), at: string.length)
    }
    let attributes = (documentAttributes as? [NSAttributedString.DocumentAttributeKey: Any]) ?? [:]
    return string.rtf(from: NSRange(location: 0, length: string.length), documentAttributes: attributes)
  }

  override func accessibilityString(for range: NSRange) -> String? {
    let padded = PaddedRange(range, length: realLength)
    let value = super.accessibilityString(for: padded.range) ?? ""
    return spaces(padded.left == 0 ? 0 : 1) + value + spaces(padded.right == 0 ? 0 : 1)
  }

  override func accessibilityStyleRange(for index: Int) -> NSRange {
    let padded = PaddedRange(NSRange(location: index, length: 0), length: realLength)
    if padded.left != 0 {
      return NSRange(location: 0, length: 1)
    }
    if padded.right != 0 {
      return NSRange(location: NSMaxRange(padded.range), length: 1)
    }
    var range = super.accessibilityStyleRange(for: padded.range.location)
    range.location += 1
    return range
  }
}

/// The chooser's search field, whose cell pads its text for assistive clients.
@objc(OakLinkedSearchField)
final class LinkedSearchField: NSSearchField {
  override class var cellClass: AnyClass? {
    get { LinkedSearchFieldCell.self }
    set {}
  }
}
