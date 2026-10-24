import OakAppKit
import OakFoundation
import SwiftUI

/// The Contributions page of the About window: every commit to the repository, by everyone, newest first under a heading per day.
/// The data is the per year JSON in the Contributions resource directory, read once when the page appears, newest year first.
/// Reading it is a few megabytes of JSON, so it happens off the main thread behind a progress indicator.
struct ContributionsView: View {
  let directory: URL

  @State private var days: [ContributionDay]?
  @State private var failure: String?

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      VStack(alignment: .leading, spacing: 4) {
        Text("Contributions")
          .font(.largeTitle)
        Link("See the commits at GitHub", destination: URL(string: "https://github.com/textmate3/textmate/commits/main")!)
          .font(.callout)
      }
      .padding(16)

      if let failure {
        ContentUnavailableView("Nothing to Show", systemImage: "doc", description: Text(failure))
      } else if let days {
        List {
          ForEach(days, id: \.title) { day in
            Section(day.title) {
              ForEach(day.commits, id: \.hash) { commit in
                ContributionRow(commit: commit)
              }
            }
          }
        }
        .textSelection(.enabled)
      } else {
        ProgressView()
          .frame(maxWidth: .infinity, maxHeight: .infinity)
      }
    }
    .task {
      do {
        let directory = directory
        let years = try await Task.detached { try ContributionYear.read(directory: directory) }.value
        days = years.flatMap { $0.days() }
      } catch {
        failure = error.localizedDescription
      }
    }
  }
}

/// One commit: the author's avatar, the summary in bold with the short hash linked at the right, and who authored it when.
/// A commit with a body has a chevron beside the summary that shows the rest of the message, drawn as Markdown, the way the page kept it behind an expander.
/// The chevron is a button of its own rather than a DisclosureGroup, which draws no chevron inside a list row that is not its outline.
struct ContributionRow: View {
  let commit: Contribution

  @State private var showsMessage = false

  var body: some View {
    HStack(alignment: .top, spacing: 10) {
      avatar
      VStack(alignment: .leading, spacing: 2) {
        title
        caption
        if showsMessage {
          message
            .padding(.top, 4)
        }
      }
    }
  }

  /// The author's GitHub avatar, 36 points like the page had it, or a generic person when there is no account or no network.
  private var avatar: some View {
    AsyncImage(url: commit.author.avatarURL) { image in
      image.resizable()
    } placeholder: {
      Image(systemName: "person.crop.square")
        .resizable()
        .foregroundStyle(.secondary)
    }
    .frame(width: 36, height: 36)
    .clipShape(RoundedRectangle(cornerRadius: 4))
  }

  private var title: some View {
    HStack(alignment: .firstTextBaseline, spacing: 6) {
      Text(commit.summary)
        .bold()
      if !commit.body.isEmpty {
        Button {
          showsMessage.toggle()
        } label: {
          Image(systemName: showsMessage ? "chevron.down" : "chevron.right")
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        .help(showsMessage ? "Hide the rest of the message" : "Show the rest of the message")
      }
      Spacer()
      if let url = commit.commitURL {
        Link(commit.shortHash, destination: url)
          .font(.caption.monospaced())
      }
    }
  }

  /// The author's name, with their GitHub username when there is one, links to their profile in the same style as the hash link.
  /// The rest of the line is secondary.
  private var caption: some View {
    HStack(spacing: 4) {
      if let profile = commit.author.profileURL, let username = commit.author.username {
        Link("\(commit.author.name) @\(username)", destination: profile)
      } else {
        Text(commit.author.name)
          .foregroundStyle(.secondary)
      }
      Text("authored \(commit.date, format: .dateTime.month(.wide).day().year())")
        .foregroundStyle(.secondary)
    }
    .font(.caption)
  }

  /// The body as Markdown, which rejoins the wrapped lines of a message into paragraphs. A body the parser refuses is shown as it is.
  @ViewBuilder private var message: some View {
    if let document = try? MarkdownDocument(markdown: commit.body) {
      MarkdownBlocksView(document: document)
    } else {
      Text(commit.body)
    }
  }
}
