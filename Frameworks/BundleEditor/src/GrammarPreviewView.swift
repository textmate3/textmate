import SwiftUI

/// Sample text on top, the same text colored by the grammar being edited
/// underneath, and the scope under the selection in a line at the bottom.
/// Re-renders shortly after the sample, the grammar or the appearance
/// changes.
struct GrammarPreviewView: View {
  let document: GrammarDocument
  @Environment(\.colorScheme) private var colorScheme
  @State private var sample = ""
  @State private var rendered = NSAttributedString()
  @State private var pageColor = NSColor.textBackgroundColor
  @State private var scopeAtSelection = ""

  var body: some View {
    VStack(spacing: 0) {
      TextEditor(text: $sample)
        .font(.body.monospaced())
        .frame(minHeight: 60, idealHeight: 90, maxHeight: 140)
        .overlay(alignment: .topLeading) {
          if sample.isEmpty {
            Text("Sample text to parse with this grammar")
              .foregroundStyle(.tertiary)
              .padding(.top, 8)
              .padding(.leading, 5)
              .allowsHitTesting(false)
          }
        }
      Divider()
      GrammarPreviewText(text: rendered, pageColor: pageColor) { scope in
        scopeAtSelection = scope
      }
      Divider()
      Text(scopeAtSelection.isEmpty ? "Select in the preview to see its scope" : scopeAtSelection)
        .font(.caption.monospaced())
        .foregroundStyle(scopeAtSelection.isEmpty ? .tertiary : .secondary)
        .lineLimit(1)
        .truncationMode(.head)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(6)
    }
    .task(id: renderKey) {
      try? await Task.sleep(for: .milliseconds(250))
      guard !Task.isCancelled else { return }
      let renderer = TMGrammarPreviewRenderer(darkAppearance: colorScheme == .dark)
      rendered = renderer.render(sample, grammar: document.fullDictionary)
      pageColor = renderer.backgroundColor
    }
  }

  /// Changes whenever the sample, the grammar or the appearance does, so the
  /// task re-runs.
  private var renderKey: Data {
    let grammar = (try? PropertyListSerialization.data(fromPropertyList: document.fullDictionary, format: .binary, options: 0)) ?? Data()
    return Data(sample.utf8) + grammar + Data([colorScheme == .dark ? 1 : 0])
  }
}
