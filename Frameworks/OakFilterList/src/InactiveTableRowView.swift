import AppKit

/// A row that can draw as selected while the table is not the first responder, for the chooser's table, which hands
/// focus to the search field and still shows which row the arrow keys are on.
final class InactiveTableRowView: NSTableRowView {
  var drawAsHighlighted = false {
    didSet { updateDrawAsHighlighted() }
  }

  private var effectiveDrawAsHighlighted = false

  private func updateDrawAsHighlighted() {
    let flag = isSelected && drawAsHighlighted && window?.isKeyWindow == true
    guard effectiveDrawAsHighlighted != flag else { return }
    effectiveDrawAsHighlighted = flag

    for view in subviews {
      if let cellView = view as? NSTableCellView {
        cellView.backgroundStyle = interiorBackgroundStyle
      }
      if let control = view as? NSControl {
        control.cell?.backgroundStyle = interiorBackgroundStyle
      }
    }

    needsDisplay = true
  }

  override var isSelected: Bool {
    didSet { updateDrawAsHighlighted() }
  }

  override var isEmphasized: Bool {
    didSet { updateDrawAsHighlighted() }
  }

  override var interiorBackgroundStyle: NSView.BackgroundStyle {
    effectiveDrawAsHighlighted ? .emphasized : super.interiorBackgroundStyle
  }

  override func drawSelection(in dirtyRect: NSRect) {
    guard effectiveDrawAsHighlighted else {
      return super.drawSelection(in: dirtyRect)
    }
    NSColor.selectedContentBackgroundColor.set()
    bounds.insetBy(dx: 0, dy: 0.5).offsetBy(dx: 0, dy: -0.5).intersection(dirtyRect).fill()
  }
}
