import Foundation

/// What a page may read from disk.
///
/// A page served from the application's scheme loads its own assets, a style sheet, a script, an image, back through
/// that scheme, and the handler reads them from disk. That read is limited to a set of root directories: the bundle
/// locations, and the directories the command that produced the page was running against. Anything else is refused.
///
/// The page comes from a command already running as the user, so this bounds accidental reach rather than defending
/// against a hostile page. Containment is by normalized path: a `..` component cannot climb out, and a root of `/a/b`
/// does not admit `/a/bc/x`. Symbolic links inside a root are honored rather than resolved, because a link placed
/// there is the user's doing, and bundle repositories checked out elsewhere and linked into the bundles directory
/// depend on it.
enum AssetPolicy {
  /// The path with `.` components dropped, `..` components folded into the one before, and repeated slashes
  /// collapsed, without touching the disk, so that a link in the path stays a link.
  static func normalized(_ path: String) -> String {
    let absolute = path.hasPrefix("/")
    var components: [Substring] = []
    for component in path.split(separator: "/", omittingEmptySubsequences: true) {
      switch component {
      case ".":
        continue
      case "..":
        if let last = components.last, last != ".." {
          components.removeLast()
        } else if !absolute {
          components.append(component)
        }
      default:
        components.append(component)
      }
    }
    let joined = components.joined(separator: "/")
    return absolute ? "/" + joined : joined
  }

  /// Whether the path sits under one of the roots, by whole path component. An empty root admits nothing.
  static func isAllowed(_ path: String, roots: [String]) -> Bool {
    let candidate = normalized(path)
    return roots.contains { root in
      guard !root.isEmpty else { return false }
      let normalizedRoot = normalized(root)
      guard candidate.hasPrefix(normalizedRoot) else { return false }
      return candidate.count == normalizedRoot.count || candidate.dropFirst(normalizedRoot.count).hasPrefix("/")
    }
  }

  /// The roots that come from the bundle locations: each location itself, and the target of every link placed in
  /// its `Bundles` directory. A bundle repository checked out elsewhere and linked in there is handed to commands by
  /// its resolved path, and the pages those commands produce ask for their assets by that path, so the target has
  /// to be a root in its own right.
  static func roots(forBundleLocations locations: [String]) -> [String] {
    var roots: [String] = []
    for location in locations where !location.isEmpty {
      roots.append(location)

      let bundles = (location as NSString).appendingPathComponent("Bundles")
      var isDirectory: ObjCBool = false
      guard FileManager.default.fileExists(atPath: bundles, isDirectory: &isDirectory), isDirectory.boolValue else { continue }

      for name in (try? FileManager.default.contentsOfDirectory(atPath: bundles)) ?? [] {
        let entry = (bundles as NSString).appendingPathComponent(name)
        let type = (try? FileManager.default.attributesOfItem(atPath: entry))?[.type] as? FileAttributeType
        guard type == .typeSymbolicLink, let resolved = resolvedPath(entry) else { continue }
        roots.append(resolved)
      }
    }
    return roots
  }

  /// Every link in the path followed, the way the application resolves a bundle's path for commands.
  static func resolvedPath(_ path: String) -> String? {
    guard let resolved = realpath(path, nil) else { return nil }
    defer { free(resolved) }
    return String(cString: resolved)
  }
}
