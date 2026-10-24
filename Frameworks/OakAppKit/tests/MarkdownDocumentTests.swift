import Foundation
import OakAppKit
import Testing

/// A Markdown fixture next to this file, read as the About window reads its resources.
private func fixture(_ name: String) throws -> String {
  let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appending(path: "fixtures/\(name)")
  return try String(contentsOf: url, encoding: .utf8)
}

/// The application's own release notes, the largest Markdown the renderer draws, read from where the build reads them.
private func releaseNotes() throws -> String {
  let repository = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
  return try String(contentsOf: repository.appending(path: "Applications/TextMate/about/Changes.md"), encoding: .utf8)
}

private func plain(_ text: AttributedString) -> String {
  String(text.characters)
}

/// Every block in the document, with the blocks inside list items walked too.
private func allBlocks(_ blocks: [MarkdownBlock]) -> [MarkdownBlock] {
  blocks.flatMap { block -> [MarkdownBlock] in
    guard let items = block.list else { return [block] }
    return [block] + items.flatMap { allBlocks($0.blocks) }
  }
}

/// One accessor per case, so a test can require the case it expects in one line.
extension MarkdownBlock {
  fileprivate var codeBlock: String? {
    guard case .codeBlock(let code) = self else { return nil }
    return code
  }

  fileprivate var heading: (level: Int, text: AttributedString)? {
    guard case .heading(let level, let text) = self else { return nil }
    return (level, text)
  }

  fileprivate var list: [MarkdownListItem]? {
    guard case .list(let items) = self else { return nil }
    return items
  }

  fileprivate var paragraph: AttributedString? {
    guard case .paragraph(let text) = self else { return nil }
    return text
  }
}

@Suite struct MarkdownDocumentBlocks {
  @Test func readsTheSampleAsSixBlocks() throws {
    let document = try MarkdownDocument(markdown: try fixture("Sample.md"))
    #expect(document.blocks.count == 6)
  }

  @Test func headingsCarryTheirLevel() throws {
    let document = try MarkdownDocument(markdown: try fixture("Sample.md"))

    let title = try #require(document.blocks[0].heading)
    #expect(title.level == 1)
    #expect(plain(title.text) == "Title")

    let release = try #require(document.blocks[1].heading)
    #expect(release.level == 2)
    #expect(plain(release.text) == "2026-10-23 (v2.1.0)")

    let smaller = try #require(document.blocks[4].heading)
    #expect(smaller.level == 3)
    #expect(plain(smaller.text) == "Smaller heading")
  }

  @Test func aParagraphKeepsItsLinkAndCodeSpanAndLosesTheBlockIntent() throws {
    let document = try MarkdownDocument(markdown: try fixture("Sample.md"))
    let text = try #require(document.blocks[2].paragraph)
    #expect(plain(text) == "A paragraph with a link and a reference and code span and emphasis.")

    // The second link is reference style, defined at the foot of the file, which Legal.md uses throughout.
    // The definition itself is not a block: the document still has six.
    let links = text.runs.compactMap(\.link)
    #expect(links == [URL(string: "https://example.com"), URL(string: "https://gnu.org/licenses/gpl-3.0.html")])

    let codeSpans = text.runs.filter { $0.inlinePresentationIntent == .code }.map { plain(AttributedString(text[$0.range])) }
    #expect(codeSpans == ["code span"])

    #expect(text.runs.allSatisfy { $0.presentationIntent == nil })
  }

  @Test func listItemsHoldTheirOwnBlocksAndNest() throws {
    let document = try MarkdownDocument(markdown: try fixture("Sample.md"))
    let items = try #require(document.blocks[3].list)
    #expect(items.count == 4)

    #expect(items[0].blocks.count == 1)
    let first = try #require(items[0].blocks[0].paragraph)
    #expect(plain(first) == "First bullet with code")

    #expect(items[1].blocks.count == 2)
    let nested = try #require(items[1].blocks[1].list)
    #expect(nested.count == 2)
    let nestedText = try #require(nested[1].blocks[0].paragraph)
    #expect(plain(nestedText) == "Nested two")

    #expect(items[2].blocks.count == 3)
    let continuation = try #require(items[2].blocks[1].paragraph)
    #expect(plain(continuation) == "Second paragraph of the third bullet.")
    #expect(items[2].blocks[2].list != nil)
  }

  @Test func anIndentedCodeBlockInsideAnItemKeepsItsLines() throws {
    let document = try MarkdownDocument(markdown: try fixture("Sample.md"))
    let items = try #require(document.blocks[3].list)
    #expect(items[3].blocks.count == 2)

    let code = try #require(items[3].blocks[1].codeBlock)
    let lines = code.split(separator: "\n", omittingEmptySubsequences: false)
    #expect(lines.count == 4)
    #expect(lines[0].hasSuffix("<key>autoRefresh</key>"))
    #expect(lines[3].hasSuffix("</array>"))
    #expect(!code.hasSuffix("\n"))
  }

  @Test func aLeadingMetadataBlockIsNotAParagraph() throws {
    let document = try MarkdownDocument(markdown: "Title: Legal\nCSS: css/legal.css\n\nThe text.")
    #expect(document.blocks.count == 1)
    let text = try #require(document.blocks[0].paragraph)
    #expect(plain(text) == "The text.")
  }

  @Test func emptyMarkdownHasNoBlocks() throws {
    let document = try MarkdownDocument(markdown: "")
    #expect(document.blocks.isEmpty)
  }
}

@Suite struct MarkdownDocumentReadsTheReleaseNotes {
  @Test func opensWithTheTitleHeading() throws {
    let document = try MarkdownDocument(markdown: try releaseNotes())
    let title = try #require(document.blocks[0].heading)
    #expect(title.level == 1)
  }

  @Test func hasOneReleaseHeadingPerRelease() throws {
    let document = try MarkdownDocument(markdown: try releaseNotes())
    let releaseHeadings = document.blocks.filter { $0.heading?.level == 2 }
    #expect(releaseHeadings.count >= 170)
  }

  @Test func nestsAtLeastOneListAndHoldsTheCodeBlock() throws {
    let document = try MarkdownDocument(markdown: try releaseNotes())
    let blocks = allBlocks(document.blocks)

    let topLevelLists = document.blocks.filter { $0.list != nil }
    let allLists = blocks.filter { $0.list != nil }
    #expect(allLists.count > topLevelLists.count)

    let codeBlocks = blocks.compactMap(\.codeBlock)
    #expect(codeBlocks.contains { $0.contains("<key>autoRefresh</key>") })
  }

  @Test func hasNoEmptyParagraphOrHeading() throws {
    let document = try MarkdownDocument(markdown: try releaseNotes())
    for block in allBlocks(document.blocks) {
      guard let text = block.heading?.text ?? block.paragraph else { continue }
      #expect(!plain(text).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, "\(block)")
    }
  }
}
