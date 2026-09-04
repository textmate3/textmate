import AppKit
import SwiftUI

/// The rendered sample: a read only text view showing the attributed string
/// the renderer built, reporting the scope under the selection as it moves.
struct GrammarPreviewText: NSViewRepresentable {
  let text: NSAttributedString
  let onSelect: (String) -> Void

  func makeCoordinator() -> Coordinator {
    Coordinator(onSelect: onSelect)
  }

  func makeNSView(context: Context) -> NSScrollView {
    let textView = NSTextView(frame: .zero)
    textView.isEditable = false
    textView.isSelectable = true
    textView.delegate = context.coordinator
    textView.isVerticallyResizable = true
    textView.isHorizontallyResizable = true
    textView.autoresizingMask = [.width, .height]
    textView.textContainer?.widthTracksTextView = false
    let unbounded = CGFloat.greatestFiniteMagnitude
    textView.textContainer?.containerSize = NSSize(width: unbounded, height: unbounded)

    let scrollView = NSScrollView(frame: .zero)
    scrollView.hasVerticalScroller = true
    scrollView.hasHorizontalScroller = true
    scrollView.autohidesScrollers = true
    scrollView.documentView = textView
    return scrollView
  }

  func updateNSView(_ scrollView: NSScrollView, context: Context) {
    guard let textView = scrollView.documentView as? NSTextView else { return }
    context.coordinator.onSelect = onSelect
    if textView.textStorage?.isEqual(to: text) == false {
      textView.textStorage?.setAttributedString(text)
    }
  }

  final class Coordinator: NSObject, NSTextViewDelegate {
    var onSelect: (String) -> Void

    init(onSelect: @escaping (String) -> Void) {
      self.onSelect = onSelect
    }

    func textViewDidChangeSelection(_ notification: Notification) {
      guard let textView = notification.object as? NSTextView, let storage = textView.textStorage else { return }
      let location = textView.selectedRange().location
      guard location < storage.length else {
        onSelect("")
        return
      }
      let scope = storage.attribute(.TMGrammarPreviewScopeAttributeName, at: location, effectiveRange: nil) as? String
      onSelect(scope ?? "")
    }
  }
}
