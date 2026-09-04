import AppKit
import Observation
import SwiftUI

/// The Objective-C face of the grammar editor. The bundle editor hands it the
/// grammar's editable keys as a dictionary, puts its view where the text pane
/// goes, hears about edits through the handler, and reads the dictionary back
/// when it saves.
@objc(TMGrammarEditorController)
@MainActor
public final class GrammarEditorController: NSViewController {
  private var document = GrammarDocument()
  private var saved: NSDictionary = [:]

  /// Called after any edit, so the window can show its modified state.
  @objc public var editedHandler: (() -> Void)?

  @objc public func load(_ grammar: [String: Any]) {
    document = GrammarDocument(dictionary: grammar)
    saved = document.dictionary as NSDictionary
    if isViewLoaded {
      hostingView.rootView = GrammarEditorView(document: document)
    }
    observeEdits()
  }

  /// The grammar's editable keys as edited so far.
  @objc public var grammar: [String: Any] { document.dictionary }

  @objc public var isEdited: Bool { !saved.isEqual(to: document.dictionary) }

  @objc public func markSaved() {
    saved = document.dictionary as NSDictionary
  }

  public override func loadView() {
    view = NSHostingView(rootView: GrammarEditorView(document: document))
  }

  private var hostingView: NSHostingView<GrammarEditorView> {
    view as! NSHostingView<GrammarEditorView>
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
