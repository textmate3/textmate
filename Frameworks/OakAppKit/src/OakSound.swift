import AppKit

/// The moments the application makes a sound, each played with one of the
/// Mac's own interface sounds rather than a file of its own.
@objc public enum OakSoundIdentifier: Int {
  case didMoveItem
  case didTrashItem
  case didBeginRecording
  case didEndRecording

  /// The file under the system's private interface sound folder. Those files
  /// have lived there since macOS 10.7 and still do on 26.
  fileprivate var file: String {
    switch self {
    case .didMoveItem: "system/Volume Mount.aif"
    case .didTrashItem: "dock/drag to trash.aif"
    case .didBeginRecording: "system/begin_record.caf"
    case .didEndRecording: "system/end_record.caf"
    }
  }
}

/// Plays an interface sound, loading each once and keeping it. A file that is
/// not there plays as silence, never as an error: the folder is Apple's, not an
/// API, and going quiet is the right failure.
@objc(OakSound)
@MainActor
public final class Sound: NSObject {
  private static let folder = "/System/Library/Components/CoreAudio.component/Contents/SharedSupport/SystemSounds"
  private static var loaded: [OakSoundIdentifier: NSSound] = [:]

  @objc public static func play(_ identifier: OakSoundIdentifier) {
    if loaded[identifier] == nil {
      let path = (folder as NSString).appendingPathComponent(identifier.file)
      loaded[identifier] = NSSound(contentsOfFile: path, byReference: true)
    }
    loaded[identifier]?.play()
  }
}
