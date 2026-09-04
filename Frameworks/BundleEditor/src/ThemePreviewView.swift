import SwiftUI

/// Sample text parsed with an installed grammar of the person's choosing and
/// colored with the theme as it is being edited, on the theme's own page
/// color, with the scope under the selection beneath. Re-renders shortly
/// after the sample, the grammar or the theme changes.
struct ThemePreviewView: View {
  let document: ThemeDocument
  @State private var sample = ""
  @State private var grammarScope = "source.ruby"
  @State private var rendered = NSAttributedString()
  @State private var pageColor = NSColor.textBackgroundColor
  @State private var scopeAtSelection = ""
  @State private var grammarScopes: [String] = []

  var body: some View {
    VStack(spacing: 0) {
      HStack {
        Picker("Grammar", selection: $grammarScope) {
          ForEach(grammarScopes, id: \.self) { scope in
            Text(scope).tag(scope)
          }
        }
        .frame(maxWidth: 320)
        Spacer()
      }
      .padding(.horizontal, 8)
      .padding(.vertical, 4)
      Divider()
      TextEditor(text: $sample)
        .font(.body.monospaced())
        .frame(minHeight: 60, idealHeight: 90, maxHeight: 140)
        .overlay(alignment: .topLeading) {
          if sample.isEmpty {
            Text("Sample text to color with this theme")
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
    .onAppear {
      grammarScopes = TMGrammarPreviewRenderer.installedGrammarScopes()
      if !grammarScopes.contains(grammarScope), let first = grammarScopes.first {
        grammarScope = first
      }
    }
    .task(id: renderKey) {
      try? await Task.sleep(for: .milliseconds(250))
      guard !Task.isCancelled else { return }
      let renderer = TMGrammarPreviewRenderer(themeDictionary: document.fullDictionary)
      rendered = renderer.render(sample, grammarScope: grammarScope)
      pageColor = renderer.backgroundColor
    }
  }

  /// Changes whenever the sample, the grammar or the theme does, so the
  /// task re-runs.
  private var renderKey: Data {
    let theme = (try? PropertyListSerialization.data(fromPropertyList: document.fullDictionary, format: .binary, options: 0)) ?? Data()
    return Data(sample.utf8) + Data(grammarScope.utf8) + theme
  }
}
