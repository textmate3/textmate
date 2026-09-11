import AppKit
import Testing

import Preferences

/// The first version of the sidebar showed the pane that was selected when the
/// window opened and never changed it again, because it handed SwiftUI a view
/// controller and SwiftUI updates a representable in place rather than asking
/// for a new one. These pin the swap that replaced it.
@MainActor
@Suite struct PaneContainerSwap {
  private func container() -> NSView {
    NSView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
  }

  private func pane() -> NSView {
    NSView(frame: NSRect(x: 0, y: 0, width: 400, height: 200))
  }

  @Test func theFirstPaneGoesIn() {
    let host = container()
    let first = pane()
    PaneContainer.show(first, in: host)
    #expect(host.subviews == [first])
  }

  @Test func thePaneIsReplacedRatherThanStackedOn() {
    let host = container()
    let first = pane()
    let second = pane()

    PaneContainer.show(first, in: host)
    PaneContainer.show(second, in: host)

    #expect(host.subviews == [second])
    #expect(first.superview == nil)
  }

  @Test func switchingBackAndForthLeavesOneSubview() {
    let host = container()
    let first = pane()
    let second = pane()

    PaneContainer.show(first, in: host)
    PaneContainer.show(second, in: host)
    PaneContainer.show(first, in: host)

    #expect(host.subviews == [first])
  }

  @Test func showingWhatIsAlreadyThereChangesNothing() {
    let host = container()
    let only = pane()

    PaneContainer.show(only, in: host)
    let constraintsAfterFirst = host.constraints.count
    PaneContainer.show(only, in: host)

    #expect(host.subviews == [only])
    // Doing it again would otherwise add a second set of the same constraints.
    #expect(host.constraints.count == constraintsAfterFirst)
  }

  @Test func theWidthIsTakenFromTheContainer() {
    let host = container()
    let only = pane()
    PaneContainer.show(only, in: host)
    host.layoutSubtreeIfNeeded()

    #expect(only.frame.width == host.frame.width)
    #expect(only.translatesAutoresizingMaskIntoConstraints == false)
  }
}
