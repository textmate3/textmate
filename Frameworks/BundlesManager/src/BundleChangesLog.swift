import Foundation

/// Every installed bundle's recent commits as one list, the way the Bundles tab of the About window shows them.
/// Newest first, grouped by month, and no older than three calendar years: this year and the two before it.
/// The year and the calendar are passed in rather than read from the clock, so the grouping is the same in a test as on a Tuesday.
public struct BundleChangesLog: Equatable, Sendable {
  /// One commit with the name of the bundle it belongs to, since the list mixes every bundle together.
  public struct Entry: Equatable, Sendable {
    public let bundleName: String
    public let commit: BundleCommit
  }

  /// The commits of one calendar month, under the title the list shows for it, such as "September 2026".
  public struct Month: Equatable, Sendable {
    public let title: String
    public let entries: [Entry]
  }

  public let months: [Month]

  public init(bundles: [BundleChanges], year: Int, calendar: Calendar = .current) {
    let oldestYear = year - 2
    let entries = bundles.flatMap { bundle in
      bundle.commits.map { Entry(bundleName: bundle.name, commit: $0) }
    }
    .filter { calendar.component(.year, from: $0.commit.date) >= oldestYear }
    .sorted { $0.commit.date > $1.commit.date }

    let formatter = DateFormatter()
    formatter.calendar = calendar
    formatter.locale = calendar.locale
    formatter.timeZone = calendar.timeZone
    formatter.setLocalizedDateFormatFromTemplate("MMMM yyyy")

    var months: [Month] = []
    for entry in entries {
      let title = formatter.string(from: entry.commit.date)
      if let last = months.last, last.title == title {
        months[months.count - 1] = Month(title: title, entries: last.entries + [entry])
      } else {
        months.append(Month(title: title, entries: [entry]))
      }
    }
    self.months = months
  }
}
