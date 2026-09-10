import Foundation
import SoftwareUpdate
import Testing

@Suite struct VersionOrdering {
  @Test func prereleaseSortsBeforeTheRelease() {
    #expect(Version("2-beta") < Version("2.0"))
    #expect(Version("2.0-beta") < Version("2.0"))
    #expect(Version("2.0.0-beta") < Version("2.0"))
  }

  @Test func trailingZeroesAndBuildMetadataDoNotCount() {
    #expect(Version("2") == Version("2.0"))
    #expect(Version("2") == Version("2.0+git.hash"))
    #expect(Version("2+git.hash") == Version("2.0"))
  }

  @Test func aLaterNumberWinsOverAPrereleaseSuffix() {
    #expect(Version("2.0") < Version("2.0.1-beta"))
    #expect(Version("2.0") < Version("2.1-beta"))
  }

  @Test func componentsCompareAsNumbers() {
    #expect(Version("2.0.9") < Version("2.0.10"))
    #expect(Version("1.01") == Version("1.1"))
    #expect(Version("1.9") < Version("1.10"))
  }

  @Test func numbersTooLargeForAnIntegerStillOrder() {
    #expect(Version("1.99999999999999999999") < Version("1.100000000000000000000"))
  }

  /// Every version in the table against every other, in both orders, with and without build metadata.
  @Test func exhaustiveTable() {
    var versions: [String] = []
    for number in ["1", "1.01", "1.1.1", "1.1.2", "1.2", "1.2.1", "1.10", "2", "2.1", "2.1.1", "2.2"] {
      for suffix in ["-alpha", "-alpha.1", "-alpha.2", "-alpha.3+debug", "-beta", "-beta.1", "-beta.2", "-rc.1", ""] {
        versions.append(number + suffix)
      }
    }

    for i in versions.indices {
      for j in i..<versions.count {
        for lhs in [versions[i], versions[i] + "+git.c0de"] {
          for rhs in [versions[j], versions[j] + "+git.b337"] {
            let left = Version(lhs)
            let right = Version(rhs)
            if i < j {
              #expect(left < right, "\(lhs) < \(rhs)")
            } else {
              #expect(left == right, "\(lhs) == \(rhs)")
            }
          }
        }
      }
    }
  }
}

@Suite struct VersionObjectiveCFace {
  @Test func missingStringsOrderFirst() {
    #expect(VersionComparison.compare(nil, to: "2.0") == .orderedAscending)
    #expect(VersionComparison.compare("2.0", to: nil) == .orderedDescending)
    #expect(VersionComparison.compare(nil, to: nil) == .orderedSame)
  }

  @Test func reportsTheThreeOutcomes() {
    #expect(VersionComparison.compare("2.0-beta", to: "2.0") == .orderedAscending)
    #expect(VersionComparison.compare("2", to: "2.0") == .orderedSame)
    #expect(VersionComparison.compare("2.1-beta", to: "2.0") == .orderedDescending)
  }
}
