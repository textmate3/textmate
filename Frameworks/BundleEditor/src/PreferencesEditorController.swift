import AppKit
import Observation
import SwiftUI

/// The Objective-C face of the preferences editor, the same shape as the
/// grammar and theme editors': the bundle editor hands it the item's
/// settings, puts its view where the text pane goes, hears about edits, and
/// reads the settings back when it saves.
@objc(TMPreferencesEditorController)
@MainActor
public final class PreferencesEditorController: NSViewController, BundleItemEditor {
  private var document = PreferencesDocument()
  private var saved: NSDictionary = [:]
  private var hostingView: NSHostingView<PreferencesEditorView>?

  @objc public var editedHandler: (() -> Void)?

  @objc public func load(_ item: [String: Any], context: [String: Any]) {
    document = PreferencesDocument(dictionary: item)
    document.context = context
    saved = document.dictionary as NSDictionary
    hostingView?.rootView = PreferencesEditorView(document: document)
    observeEdits()
  }

  @objc public func updateContext(_ context: [String: Any]) {
    document.context = context
  }

  @objc public var itemDictionary: [String: Any] { document.dictionary }

  @objc public var isEdited: Bool { !saved.isEqual(to: document.dictionary) }

  @objc public func markSaved() {
    saved = document.dictionary as NSDictionary
  }

  public override func loadView() {
    let hostingView = NSHostingView(rootView: PreferencesEditorView(document: document))
    self.hostingView = hostingView
    view = hostingView
  }

  /// Re-arms after every change, since observation tracking fires once.
  private func observeEdits() {
    withObservationTracking {
      _ = document.dictionary
    } onChange: { [weak self] in
      Task { @MainActor in
        guard let self else { return }
        self.editedHandler?()
        self.observeEdits()
      }
    }
  }
}
