import BundlesManager
import Foundation
import Testing

/// A bundle's `Changes.json` next to this file, laid out as it is at the top of an installed bundle.
private func fixture(_ bundle: String) -> URL {
  URL(fileURLWithPath: #filePath).deletingLastPathComponent().appending(path: "fixtures/\(bundle)/Changes.json")
}

/// One calendar for every test, pinned to the zone the fixtures were committed in and to English month names.
private var pacific: Calendar {
  var calendar = Calendar(identifier: .gregorian)
  calendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
  calendar.locale = Locale(identifier: "en_US")
  return calendar
}

@Suite struct BundleChangesReading {
  @Test func readsTheFile() throws {
    let changes = try #require(BundleChanges.read(fixture("source.tmbundle")))
    #expect(changes.name == "Source")
    #expect(changes.commits.count == 3)

    let newest = changes.commits[0]
    #expect(newest.author == "Shane Becker")
    #expect(newest.summary == "Merge pull request #1 from textmate3/env_ruby_shebang")
    #expect(newest.body == "Point the Ruby command shebang at env ruby")

    let components = pacific.dateComponents([.year, .month, .day, .hour], from: newest.date)
    #expect(components.year == 2026)
    #expect(components.month == 9)
    #expect(components.day == 10)
    #expect(components.hour == 18)
  }

  @Test func anEmptyBodyIsAnEmptyString() throws {
    let changes = try #require(BundleChanges.read(fixture("source.tmbundle")))
    #expect(changes.commits[1].body == "")
  }

  @Test func aBundleWithoutTheFileReadsAsNil() {
    #expect(BundleChanges.read(fixture("no-such.tmbundle")) == nil)
  }
}

@Suite struct BundleChangesLogGrouping {
  private var bundles: [BundleChanges] {
    get throws {
      [
        try #require(BundleChanges.read(fixture("source.tmbundle"))),
        try #require(BundleChanges.read(fixture("markdown.tmbundle"))),
      ]
    }
  }

  @Test func mixesTheBundlesNewestFirst() throws {
    let log = BundleChangesLog(bundles: try bundles, year: 2026, calendar: pacific)
    let entries = log.months.flatMap(\.entries)
    #expect(entries.count == 7)
    #expect(entries.map(\.bundleName) == ["Markdown", "Source", "Source", "Markdown", "Markdown", "Source", "Markdown"])
    #expect(entries.map(\.commit.date) == entries.map(\.commit.date).sorted(by: >))
  }

  @Test func groupsByCalendarMonth() throws {
    let log = BundleChangesLog(bundles: try bundles, year: 2026, calendar: pacific)
    #expect(log.months.map(\.title) == ["September 2026", "August 2026", "May 2026"])
    #expect(log.months.map(\.entries.count) == [4, 1, 2])
  }

  @Test func keepsThisYearAndTheTwoBefore() throws {
    #expect(BundleChangesLog(bundles: try bundles, year: 2028, calendar: pacific).months.flatMap(\.entries).count == 7)
    #expect(BundleChangesLog(bundles: try bundles, year: 2029, calendar: pacific).months.isEmpty)
  }

  @Test func noBundlesIsNoMonths() {
    #expect(BundleChangesLog(bundles: [], year: 2026, calendar: pacific).months.isEmpty)
  }
}
