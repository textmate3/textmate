import Foundation

/// A Markdown document as blocks, for a view to lay out.
/// Foundation parses the Markdown into one attributed string.
/// It keeps the block structure as presentation intents on the runs, innermost first.
/// SwiftUI's Text draws inline Markdown and nothing more.
/// So the blocks are recovered here, and a view walks them.
/// What it covers is what the About window's Markdown uses:
/// headings, paragraphs, bullet lists that nest, and indented code blocks.
/// The runs of a paragraph keep their inline attributes, the links, the code spans and the emphasis, for Text to draw.
public struct MarkdownDocument: Equatable, Sendable {
  public let blocks: [MarkdownBlock]

  public init(markdown: String) throws {
    var options = AttributedString.MarkdownParsingOptions()
    options.interpretedSyntax = .full
    let parsed = try AttributedString(markdown: markdown, options: options)
    let runs = parsed.runs.map { run in
      Run(text: AttributedString(parsed[run.range]), components: (run.presentationIntent?.components ?? []).reversed())
    }
    blocks = Self.blocks(of: runs[...], depth: 0)
  }

  /// One run of the parsed string with its intents outermost first.
  /// So the component at a depth is the block the run sits in at that depth of nesting.
  private struct Run {
    let text: AttributedString
    let components: [PresentationIntent.IntentType]

    func component(at depth: Int) -> PresentationIntent.IntentType? {
      depth < components.count ? components[depth] : nil
    }
  }

  /// The blocks among these runs at one depth of nesting.
  /// Consecutive runs that share the block identity at this depth are one block.
  /// A list hands its runs down one depth for its items, and each item one more for its own blocks.
  private static func blocks(of runs: ArraySlice<Run>, depth: Int) -> [MarkdownBlock] {
    var blocks: [MarkdownBlock] = []
    var index = runs.startIndex
    while index < runs.endIndex {
      guard let component = runs[index].component(at: depth) else {
        index += 1
        continue
      }
      let group = runs[index...].prefix { $0.component(at: depth)?.identity == component.identity }
      switch component.kind {
      case .codeBlock: blocks.append(.codeBlock(code(of: group)))
      case .header(let level): blocks.append(.heading(level: level, text: inlineText(of: group)))
      case .paragraph: blocks.append(.paragraph(inlineText(of: group)))
      case .orderedList, .unorderedList: blocks.append(.list(items(of: group, depth: depth + 1)))
      default:
        // Block quotes, tables and rules, which these files do not use.
        // Their contents are drawn as plain blocks rather than dropped.
        blocks.append(contentsOf: self.blocks(of: group, depth: depth + 1))
      }
      index = group.endIndex
    }
    return blocks
  }

  /// The items of one list, each item being the blocks nested one depth further in.
  private static func items(of runs: ArraySlice<Run>, depth: Int) -> [MarkdownListItem] {
    var items: [MarkdownListItem] = []
    var index = runs.startIndex
    while index < runs.endIndex {
      guard let component = runs[index].component(at: depth) else {
        index += 1
        continue
      }
      let group = runs[index...].prefix { $0.component(at: depth)?.identity == component.identity }
      items.append(MarkdownListItem(blocks: blocks(of: group, depth: depth + 1)))
      index = group.endIndex
    }
    return items
  }

  /// The runs of one paragraph or heading joined, with the block intent taken off.
  /// The block is the enum case now, and the text keeps only what Text draws inline.
  private static func inlineText(of runs: ArraySlice<Run>) -> AttributedString {
    var text = AttributedString()
    for run in runs {
      text.append(run.text)
    }
    text.presentationIntent = nil
    return text
  }

  /// The lines of a code block as one string, without the newline the parser leaves at the end.
  private static func code(of runs: ArraySlice<Run>) -> String {
    var code = runs.map { String($0.text.characters) }.joined()
    if code.hasSuffix("\n") {
      code.removeLast()
    }
    return code
  }
}

/// One block of a Markdown document.
/// A list's items carry blocks of their own, which is how lists nest and how an item holds a second paragraph or a code block.
public enum MarkdownBlock: Equatable, Sendable {
  case codeBlock(String)
  case heading(level: Int, text: AttributedString)
  case list([MarkdownListItem])
  case paragraph(AttributedString)
}

/// One item of a list: the blocks it holds, in order.
public struct MarkdownListItem: Equatable, Sendable {
  public let blocks: [MarkdownBlock]
}
