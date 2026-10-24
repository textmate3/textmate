import Foundation
import OakFoundation
import Testing

/// The fixture directory next to this file: one real year file, 2017, as `script/update_contributions` wrote it.
private var fixtures: URL {
  URL(fileURLWithPath: #filePath).deletingLastPathComponent().appending(path: "fixtures/Contributions")
}

/// One calendar for every test, pinned to a zone and to English month names, so the day grouping is the same on any machine.
private var newYork: Calendar {
  var calendar = Calendar(identifier: .gregorian)
  calendar.timeZone = TimeZone(identifier: "America/New_York")!
  calendar.locale = Locale(identifier: "en_US")
  return calendar
}

@Suite struct ContributionYearReading {
  @Test func readsEveryYearFileInTheDirectory() throws {
    let years = try ContributionYear.read(directory: fixtures)
    #expect(years.map(\.year) == [2017])
    #expect(years[0].commits.count == 72)
  }

  @Test func decodesACommitWithItsAccount() throws {
    let newest = try #require(ContributionYear.read(directory: fixtures)[0].commits.first)
    #expect(newest.hash.hasPrefix("75e8723e"))
    #expect(newest.shortHash.count == 10)
    #expect(newest.summary == "Specify ‘ns’ as a (link) dependency")
    #expect(!newest.body.isEmpty)
    #expect(newest.author.name == "Allan Odgaard")
    #expect(newest.author.username == "sorbits")
    #expect(newest.author.avatarURL != nil)
    #expect(newest.author.profileURL == URL(string: "https://github.com/sorbits"))
    #expect(newest.commitURL == URL(string: "https://github.com/textmate3/textmate/commit/\(newest.hash)"))

    // Authored at 10:06 on November 16 in Bangkok, which is 22:06 on November 15 in New York.
    let components = newYork.dateComponents([.year, .month, .day, .hour], from: newest.date)
    #expect(components.year == 2017)
    #expect(components.month == 11)
    #expect(components.day == 15)
    #expect(components.hour == 22)
  }

  @Test func theFileIsNewestAuthorDateFirst() throws {
    // The script sorts each year by author date, since git log's own order is by commit date and parentage.
    let commits = try ContributionYear.read(directory: fixtures)[0].commits
    #expect(commits.map(\.date) == commits.map(\.date).sorted(by: >))

    let oldest = try #require(commits.last)
    #expect(oldest.hash.hasPrefix("a124b494"))
    #expect(oldest.author.username == "rdwampler")
    #expect(!oldest.body.isEmpty)
  }

  @Test func anAuthorWithoutAnAccountHasNoProfile() {
    let author = ContributionAuthor(name: "Per Persson", username: nil, avatarURL: nil)
    #expect(author.profileURL == nil)
  }

  @Test func aMissingDirectoryThrows() {
    #expect(throws: (any Error).self) {
      try ContributionYear.read(directory: fixtures.appending(path: "no-such-directory"))
    }
  }
}

@Suite struct ContributionDays {
  @Test func groupsConsecutiveCommitsByDay() throws {
    let year = try ContributionYear.read(directory: fixtures)[0]
    let days = year.days(calendar: newYork)

    #expect(days.flatMap(\.commits) == year.commits)
    #expect(days.allSatisfy { !$0.commits.isEmpty })
    #expect(Set(days.map(\.title)).count == days.count)
    #expect(days[0].title == "Nov 15, 2017")
  }

  @Test func anEmptyYearHasNoDays() {
    #expect(ContributionYear(year: 2025, commits: []).days(calendar: newYork).isEmpty)
  }
}
