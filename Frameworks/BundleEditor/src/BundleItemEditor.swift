import AppKit

/// What the bundle editor asks of a form based editor for one kind of item,
/// whatever the kind: give it the item's editable keys and the rest as
/// context, hear about edits, read the keys back when saving, and be told
/// when they were saved. The grammar and theme editors both answer to this.
@objc(TMBundleItemEditor)
@MainActor
public protocol BundleItemEditor: AnyObject {
  var view: NSView { get }
  var editedHandler: (() -> Void)? { get set }
  var isEdited: Bool { get }
  var itemDictionary: [String: Any] { get }
  func load(_ item: [String: Any], context: [String: Any])
  func updateContext(_ context: [String: Any])
  func markSaved()
}
