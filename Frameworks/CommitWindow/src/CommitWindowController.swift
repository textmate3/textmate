import AppKit
import SwiftUI

/// The window the commit sheet lives in.
///
/// A window controller rather than a SwiftUI scene, because this is shown as a
/// sheet on whichever project window asked for it, and because it has to hold
/// itself alive until the person answers.
@objc(OakCommitWindowController)
public final class CommitWindowController: NSWindowController {
  private var model: CommitWindowModel!
  private var retainedSelf: CommitWindowController?

  @objc(initWithArguments:environment:reply:)
  public init(arguments: [String], environment: [String: String], reply: CommitWindowReply) {
    let parsed = CommitArguments(argv: arguments)

    // Diffs opened from here go to a project of their own rather than into the
    // one being committed.
    var environment = environment
    environment["TM_PROJECT_UUID"] = CommitWindowBridge.newProjectIdentifier()

    let window = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: 600, height: 350),
      styleMask: [.titled, .resizable],
      backing: .buffered,
      defer: false
    )
    window.setFrameAutosaveName("Commit Window")

    super.init(window: window)

    model = CommitWindowModel(arguments: parsed, environment: environment, reply: reply)
    model.onFinish = { [weak self] in self?.finish() }

    window.contentView = NSHostingView(rootView: CommitWindowView(model: model))
    window.delegate = self

    if parsed.showsContinueButton {
      watchForOptionKey()
    }
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) { fatalError("not from a nib") }

  /// Nothing was asked for, so there is nothing to show. The tool is answered
  /// as cancelled rather than left waiting.
  @objc public var hasNothingToShow: Bool { model.arguments.isEmpty }

  @objc(beginSheetModalForWindow:)
  public func beginSheetModal(for parent: NSWindow?) {
    guard !hasNothingToShow else {
      model.cancel()
      return
    }

    retainedSelf = self

    guard let window, let parent else {
      showWindow(nil)
      return
    }
    parent.beginSheet(window)
  }

  // ==============
  // = Option key =
  // ==============

  private var eventMonitor: Any?

  /// Holding option turns Commit into Commit and Continue, and the title has to
  /// say so while it is held.
  private func watchForOptionKey() {
    eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
      guard let self, window?.isKeyWindow == true else { return event }
      model.continues = !event.modifierFlags.contains(.option)
      return event
    }
  }

  private func finish() {
    if let eventMonitor {
      NSEvent.removeMonitor(eventMonitor)
      self.eventMonitor = nil
    }

    if let window, let parent = window.sheetParent {
      parent.endSheet(window)
    } else {
      close()
    }

    // After the run loop turn, so nothing here is deallocated inside a call
    // that is still on the stack.
    DispatchQueue.main.async { self.retainedSelf = nil }
  }
}

extension CommitWindowController: NSWindowDelegate {
  /// Closing the window is a cancellation, and the tool is waiting either way.
  public func windowWillClose(_ notification: Notification) {
    model.cancel()
  }
}
