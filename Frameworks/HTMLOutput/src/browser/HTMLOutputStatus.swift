import Observation

/// What the strip under a command's output says: where a link goes, how far a
/// page has loaded, and whether there is anywhere to go back or forward to.
@MainActor @Observable
final class HTMLOutputStatus {
  /// The text on the left, which is a link's target while the pointer is over
  /// it and nothing the rest of the time.
  var text = ""

  /// Between 0 and 1 while a page loads. Zero means there is no measurable
  /// progress, which is the ordinary case for a command writing as it runs, so
  /// the strip shows a spinner rather than a bar.
  var progress = 0.0

  var isBusy = false
  var canGoBack = false
  var canGoForward = false

  /// A page reporting no progress gets a spinner, one reporting some gets a
  /// bar. The view this replaces did the same by adding one progress indicator
  /// to the view hierarchy, removing the other, and rebuilding its constraints.
  var showsSpinner: Bool { progress == 0 }

  @ObservationIgnored var goBack: (() -> Void)?
  @ObservationIgnored var goForward: (() -> Void)?
}
