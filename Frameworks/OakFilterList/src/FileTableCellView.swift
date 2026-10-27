import AppKit

/// A row with a file's icon, its name, the folder under it, and a button on the right, which the chooser gives it.
/// The views bind to the row's item by key: icon, name and folder.
@objc(OakFileTableCellView)
final class FileTableCellView: NSTableCellView {
  private let folderTextField = ChooserConstruction.label(font: .controlContentFont(ofSize: 10))
  private let closeButton: NSButton

  init(closeButton: NSButton) {
    self.closeButton = closeButton
    super.init(frame: .zero)

    let imageView = NSImageView()
    imageView.setContentHuggingPriority(.required, for: .horizontal)
    imageView.setContentCompressionResistancePriority(.required, for: .horizontal)

    let fileTextField = ChooserConstruction.label(font: .systemFont(ofSize: 13))
    fileTextField.lineBreakMode = .byTruncatingTail
    fileTextField.cell?.lineBreakMode = .byTruncatingTail
    folderTextField.lineBreakMode = .byTruncatingHead
    folderTextField.cell?.lineBreakMode = .byTruncatingHead

    let views: [String: NSView] = ["icon": imageView, "file": fileTextField, "folder": folderTextField, "close": closeButton]
    ChooserConstruction.addAutoLayoutViews(Array(views.values), to: self)
    addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|-(4)-[icon]-(4)-[file]-(4)-[close(==16)]-(8)-|", metrics: nil, views: views))
    addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:[file]-(2)-[folder]-(5)-|", options: [.alignAllLeading, .alignAllTrailing], metrics: nil, views: views))
    imageView.centerYAnchor.constraint(equalTo: centerYAnchor).isActive = true
    closeButton.centerYAnchor.constraint(equalTo: centerYAnchor).isActive = true

    imageView.bind(.value, to: self, withKeyPath: "objectValue.icon", options: nil)
    fileTextField.bind(.value, to: self, withKeyPath: "objectValue.name", options: nil)
    folderTextField.bind(.value, to: self, withKeyPath: "objectValue.folder", options: nil)

    self.imageView = imageView
    textField = fileTextField
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("FileTableCellView is created in code")
  }

  override var backgroundStyle: NSView.BackgroundStyle {
    didSet {
      if backgroundStyle == .emphasized {
        textField?.objectValue = ChooserConstruction.selectedString(for: value(forKeyPath: "objectValue.name"))
        folderTextField.textColor = NSColor(calibratedWhite: 0.9, alpha: 1)
        folderTextField.objectValue = ChooserConstruction.selectedString(for: value(forKeyPath: "objectValue.folder"))
      } else {
        textField?.objectValue = value(forKeyPath: "objectValue.name")
        folderTextField.textColor = NSColor(calibratedWhite: 0.5, alpha: 1)
        folderTextField.objectValue = value(forKeyPath: "objectValue.folder")
      }
    }
  }

  override func accessibilityChildren() -> [Any]? {
    [textField?.cell, folderTextField.cell, closeButton.cell, imageView?.cell].compactMap { $0 }
  }
}
