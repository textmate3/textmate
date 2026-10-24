import SwiftUI

/// A Markdown document drawn natively, block by block, in a scroll view.
/// Headings, paragraphs, bullet lists that nest, and code blocks, which is what the About window's Markdown uses.
/// Each run's inline Markdown, the links, code spans and emphasis, is drawn by Text from the attributed string the parser left.
/// Links open through the environment's openURL, so a host decides where they go.
public struct MarkdownView: View {
  public let document: MarkdownDocument

  public init(document: MarkdownDocument) {
    self.document = document
  }

  public var body: some View {
    ScrollView {
      LazyVStack(alignment: .leading, spacing: 12) {
        ForEach(document.blocks.indices, id: \.self) { index in
          MarkdownBlockView(block: document.blocks[index])
        }
      }
      .padding(16)
      .frame(maxWidth: .infinity, alignment: .leading)
      .textSelection(.enabled)
    }
  }
}

/// One block, by its case.
/// A list hands its items to MarkdownListView, which comes back here for the blocks inside each item.
struct MarkdownBlockView: View {
  let block: MarkdownBlock

  var body: some View {
    switch block {
    case .codeBlock(let code):
      Text(code)
        .font(.body.monospaced())
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 4))
    case .heading(let level, let text):
      Text(text)
        .font(Self.font(forHeadingLevel: level))
        .padding(.top, level == 1 ? 0 : 8)
    case .list(let items):
      MarkdownListView(items: items)
    case .paragraph(let text):
      Text(text)
    }
  }

  /// The sizes the HTML page used, 2.4 and 1.6 times a 13 pixel body, land on the large title and the title.
  /// Below that the levels step down, and nothing in these files goes past three.
  private static func font(forHeadingLevel level: Int) -> Font {
    switch level {
    case 1: .largeTitle
    case 2: .title
    case 3: .title3
    default: .headline
    }
  }
}

/// The items of a list, a bullet beside each, with the item's own blocks stacked after the bullet.
/// A nested list is one of those blocks, so nesting is this view inside itself by way of MarkdownBlockView.
struct MarkdownListView: View {
  let items: [MarkdownListItem]

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      ForEach(items.indices, id: \.self) { index in
        HStack(alignment: .firstTextBaseline, spacing: 6) {
          Text("•")
          VStack(alignment: .leading, spacing: 4) {
            ForEach(items[index].blocks.indices, id: \.self) { blockIndex in
              MarkdownBlockView(block: items[index].blocks[blockIndex])
            }
          }
        }
      }
    }
  }
}
