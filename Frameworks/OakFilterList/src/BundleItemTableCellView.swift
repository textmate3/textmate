import AppKit

/// A row of Select Bundle Item: the kind's icon, the name, the location under it, and the shortcut on the right,
/// a key equivalent drawn as its symbols or a tab trigger with its arrow.
final class BundleItemTableCellView: NSTableCellView {
  private let contextTextField = ChooserConstruction.label(font: .controlContentFont(ofSize: 10))
  private let shortcutTextField = ChooserConstruction.label(font: .controlContentFont(ofSize: 13))

  init() {
    super.init(frame: .zero)

    let imageView = NSImageView()
    imageView.setContentHuggingPriority(.required, for: .horizontal)
    imageView.setContentCompressionResistancePriority(.required, for: .horizontal)

    let textField = ChooserConstruction.label(font: .systemFont(ofSize: 13))
    shortcutTextField.setContentHuggingPriority(.required, for: .horizontal)
    shortcutTextField.setContentCompressionResistancePriority(.required, for: .horizontal)

    let views: [String: NSView] = ["icon": imageView, "name": textField, "context": contextTextField, "shortcut": shortcutTextField]
    ChooserConstruction.addAutoLayoutViews(Array(views.values), to: self)
    addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|-(4)-[icon]-(4)-[name]-(4)-[shortcut]-(8)-|", metrics: nil, views: views))
    addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:[context]-(8)-|", metrics: nil, views: views))
    addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:[name]-(2)-[context]-(5)-|", options: .alignAllLeading, metrics: nil, views: views))
    imageView.centerYAnchor.constraint(equalTo: centerYAnchor).isActive = true
    shortcutTextField.firstBaselineAnchor.constraint(equalTo: textField.firstBaselineAnchor).isActive = true

    self.imageView = imageView
    self.textField = textField
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("BundleItemTableCellView is created in code")
  }

  override var objectValue: Any? {
    didSet {
      guard let item = objectValue as? BundleItemChooserItem else { return }

      let image = item.icon?.copy() as? NSImage
      image?.size = NSSize(width: 32, height: 32)
      imageView?.image = image
      textField?.objectValue = item.name
      contextTextField.objectValue = item.path

      if let keyEquivalent = item.keyEquivalent {
        shortcutTextField.font = .controlContentFont(ofSize: 0)
        shortcutTextField.objectValue = TMBundleItems.attributedString(forEventString: keyEquivalent, font: shortcutTextField.font ?? .controlContentFont(ofSize: 0))
      } else if let tabTrigger = item.tabTrigger {
        shortcutTextField.font = .controlContentFont(ofSize: 10)
        shortcutTextField.objectValue = tabTrigger + "⇥"
      } else {
        shortcutTextField.objectValue = ""
      }
    }
  }

  override var backgroundStyle: NSView.BackgroundStyle {
    didSet {
      let item = objectValue as? BundleItemChooserItem
      if backgroundStyle == .emphasized {
        textField?.objectValue = ChooserConstruction.selectedString(for: item?.name)
        contextTextField.textColor = NSColor(calibratedWhite: 0.9, alpha: 1)
        contextTextField.objectValue = ChooserConstruction.selectedString(for: item?.path)
      } else {
        textField?.objectValue = item?.name
        contextTextField.textColor = NSColor(calibratedWhite: 0.5, alpha: 1)
        contextTextField.objectValue = item?.path
      }
    }
  }

  override func accessibilityChildren() -> [Any]? {
    [textField?.cell, imageView?.cell, contextTextField.cell, shortcutTextField.cell].compactMap { $0 }
  }
}
