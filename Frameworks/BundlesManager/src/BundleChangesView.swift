import SwiftUI

/// The Bundles tab of the About window: every installed bundle's recent commits, newest first, under a heading per month.
/// A commit with a body opens to show it. One without is a single line.
struct BundleChangesView: View {
  let log: BundleChangesLog

  var body: some View {
    if log.months.isEmpty {
      ContentUnavailableView(
        "No Bundle Changes",
        systemImage: "shippingbox",
        description: Text("Bundles installed from the catalog carry their recent history. None of the installed bundles has one.")
      )
    } else {
      List {
        ForEach(log.months.indices, id: \.self) { monthIndex in
          Section(log.months[monthIndex].title) {
            ForEach(log.months[monthIndex].entries.indices, id: \.self) { entryIndex in
              BundleCommitRow(entry: log.months[monthIndex].entries[entryIndex])
            }
          }
        }
      }
      .textSelection(.enabled)
    }
  }
}

/// One commit: the bundle's name in bold, the summary, the author set off to the right.
/// The body, when there is one, is behind a disclosure, the way the HTML page kept it behind a cross.
struct BundleCommitRow: View {
  let entry: BundleChangesLog.Entry

  var body: some View {
    if entry.commit.body.isEmpty {
      summary
    } else {
      DisclosureGroup {
        Text(entry.commit.body)
          .font(.callout)
          .foregroundStyle(.secondary)
          .padding(.top, 2)
      } label: {
        summary
      }
    }
  }

  private var summary: some View {
    HStack(alignment: .firstTextBaseline) {
      Text("\(Text(entry.bundleName).bold()): \(entry.commit.summary)")
      Spacer()
      Text(entry.commit.author)
        .foregroundStyle(.secondary)
    }
  }
}
