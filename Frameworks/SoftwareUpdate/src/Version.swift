import Foundation

/// A version string, ordered the way Semantic Versioning orders them and accepting the loose forms that turn up in practice.
///
/// Components compare as numbers where both sides are numeric, so 2.0.10 is newer than 2.0.9.
/// A prerelease suffix introduced by a hyphen sorts before the release, so 2.0-beta precedes 2.0.
/// Build metadata introduced by a plus sign is ignored, so 2.0+git.hash equals 2.0.
/// Trailing zero groups are ignored, so 2, 2.0 and 2.0.0 are the same version.
public struct Version: Comparable, Sendable {
  /// The version as it was given.
  public let string: String

  /// The version split into its parts, with each separator kept as a part of its own.
  /// 2.0-beta becomes 2, ., 0, -, beta.
  let tokens: [String]

  public init(_ string: String) {
    self.string = string
    self.tokens = Version.withoutTrailingZeroes(Version.tokens(of: string))
  }

  public static func < (lhs: Version, rhs: Version) -> Bool {
    var left = lhs.tokens[...]
    var right = rhs.tokens[...]

    while let l = left.first, let r = right.first {
      let bothNumeric = isNumeric(l) && isNumeric(r)
      if l != r && (!bothNumeric || !numericallyEqual(l, r)) {
        if bothNumeric {
          return numericallyLess(l, r)
        } else if isSeparator(l) {
          return l == "-" || (l == "+" && r == ".")
        }
        return l.utf8.lexicographicallyPrecedes(r.utf8)
      } else if l == "+" {
        return false
      }
      left = left.dropFirst()
      right = right.dropFirst()
    }

    if let l = left.first {
      return l == "-"
    }
    return right.first == "."
  }

  public static func == (lhs: Version, rhs: Version) -> Bool {
    !(lhs < rhs) && !(rhs < lhs)
  }

  // MARK: Parsing

  private static func tokens(of string: String) -> [String] {
    var result: [String] = []
    var current = ""
    for character in string {
      if character == "." || character == "-" || character == "+" {
        result.append(current)
        result.append(String(character))
        current = ""
      } else {
        current.append(character)
      }
    }
    result.append(current)
    return result
  }

  /// Drops zero groups from the end of the numeric part, so 2.0.0-beta reads as 2-beta.
  private static func withoutTrailingZeroes(_ tokens: [String]) -> [String] {
    let numericPartEnd = tokens.firstIndex { !(isNumeric($0) || $0 == ".") } ?? tokens.endIndex
    var last = numericPartEnd
    while last > tokens.startIndex, isNumeric(tokens[last - 1]), isZero(tokens[last - 1]) {
      last -= 1
      if last == tokens.startIndex {
        break
      }
      last -= 1
    }
    return Array(tokens[..<last]) + Array(tokens[numericPartEnd...])
  }

  private static func isNumeric(_ token: String) -> Bool {
    !token.isEmpty && token.allSatisfy { $0.isASCII && $0.isNumber }
  }

  private static func isSeparator(_ token: String) -> Bool {
    token == "." || token == "-" || token == "+"
  }

  private static func isZero(_ token: String) -> Bool {
    token.allSatisfy { $0 == "0" }
  }

  // Numeric tokens compare by their digits, without going through an integer, so no length overflows.
  private static func significantDigits(_ token: String) -> Substring {
    let digits = token.drop { $0 == "0" }
    return digits.isEmpty ? "0" : digits
  }

  private static func numericallyEqual(_ lhs: String, _ rhs: String) -> Bool {
    significantDigits(lhs) == significantDigits(rhs)
  }

  private static func numericallyLess(_ lhs: String, _ rhs: String) -> Bool {
    let l = significantDigits(lhs)
    let r = significantDigits(rhs)
    if l.count != r.count {
      return l.count < r.count
    }
    return l.utf8.lexicographicallyPrecedes(r.utf8)
  }
}

/// The face Objective-C callers see. A missing string orders before everything.
@objc(OakVersion) public final class VersionComparison: NSObject {
  @objc public static func compare(_ lhs: String?, to rhs: String?) -> ComparisonResult {
    switch (lhs, rhs) {
    case (nil, nil): return .orderedSame
    case (nil, _): return .orderedAscending
    case (_, nil): return .orderedDescending
    case let (l?, r?):
      let left = Version(l)
      let right = Version(r)
      if left < right { return .orderedAscending }
      if right < left { return .orderedDescending }
      return .orderedSame
    }
  }
}
