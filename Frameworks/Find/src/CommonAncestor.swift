import Foundation

/// The folder that stands for a set of paths when Find in Project searches
/// the file browser's selection: the deepest folder every path is under.
/// Taken by path component rather than by character,
/// so a folder selected with something inside it answers the folder,
/// and a name that merely begins the same way as another is not a shared folder.
/// Nothing in common is the root.
/// One path is itself.
/// No paths is nothing.
@objc(CommonAncestor)
public final class CommonAncestor: NSObject {
  /// The folder, or the file's folder when the shared path is a file on disk.
  @objc public static func of(_ paths: [String]) -> String? {
    guard let shared = folder(sharedBy: paths) else { return nil }
    var isDirectory: ObjCBool = false
    if FileManager.default.fileExists(atPath: shared, isDirectory: &isDirectory), !isDirectory.boolValue {
      return (shared as NSString).deletingLastPathComponent
    }
    return shared
  }

  /// The prefix logic alone, with no look at the disk.
  static func folder(sharedBy paths: [String]) -> String? {
    guard let first = paths.first else { return nil }
    if paths.count == 1 { return first }

    var common = components(of: first)
    for path in paths.dropFirst() {
      let shared = zip(common, components(of: path)).prefix { $0 == $1 }.count
      common = Array(common.prefix(shared))
    }
    return common.isEmpty ? "/" : NSString.path(withComponents: common)
  }

  /// The path's components once standardized, so a trailing separator changes nothing.
  private static func components(of path: String) -> [String] {
    ((path as NSString).standardizingPath as NSString).pathComponents
  }
}
