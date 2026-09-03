import Foundation

/// What the application says about itself: the version and copyright from its
/// Info.plist, read once. The About window shows both. Objective-C sees this as
/// OakApplicationInfo through the generated header.
///
/// Sendable by inspection rather than by the compiler: NSObject subclasses cannot
/// be checked, and every stored property here is immutable, which is what the
/// shared `main` instance needs under Swift 6 strict concurrency.
@objc(OakApplicationInfo)
public final class ApplicationInfo: NSObject, @unchecked Sendable {
  /// The running application's own information.
  @objc public static let main = ApplicationInfo(infoDictionary: Bundle.main.infoDictionary ?? [:])

  /// The marketing version, CFBundleShortVersionString, such as 2.1.0.
  @objc public let shortVersion: String

  /// NSHumanReadableCopyright, as the Finder shows it.
  @objc public let copyright: String

  @objc public init(infoDictionary: [String: Any]) {
    shortVersion = infoDictionary["CFBundleShortVersionString"] as? String ?? ""
    copyright = infoDictionary["NSHumanReadableCopyright"] as? String ?? ""
  }
}
