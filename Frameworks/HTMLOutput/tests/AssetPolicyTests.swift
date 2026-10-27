import Foundation
import Testing
@testable import HTMLOutput

/// What a page may read from disk: inside a root, not outside it, not out through `..`, by whole component,
/// through a link placed inside a root, and from the targets of linked bundles.
@Suite struct AssetPolicyTests {
  /// A directory of this test's own, with the files and links named inside it, gone when the test is.
  private struct Jail {
    let root: URL

    init() throws {
      root = FileManager.default.temporaryDirectory.appendingPathComponent("asset-policy-\(UUID().uuidString)")
      try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    func touch(_ relativePath: String) throws {
      let url = root.appendingPathComponent(relativePath)
      try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
      FileManager.default.createFile(atPath: url.path, contents: Data())
    }

    func link(_ relativePath: String, to target: String) throws {
      try FileManager.default.createSymbolicLink(atPath: path(relativePath), withDestinationPath: path(target))
    }

    func path(_ relativePath: String) -> String {
      root.appendingPathComponent(relativePath).path
    }

    func remove() {
      try? FileManager.default.removeItem(at: root)
    }
  }

  @Test func normalizationFoldsDotsAndSlashesWithoutTheDisk() {
    #expect(AssetPolicy.normalized("/a/./b//c/") == "/a/b/c")
    #expect(AssetPolicy.normalized("/a/b/../c") == "/a/c")
    #expect(AssetPolicy.normalized("/../a") == "/a")
    #expect(AssetPolicy.normalized("a/../../b") == "../b")
  }

  @Test func anAssetInsideARootIsAllowed() throws {
    let jail = try Jail()
    defer { jail.remove() }
    try jail.touch("root/style.css")
    try jail.touch("root/images/header.png")

    let roots = [jail.path("root")]
    #expect(AssetPolicy.isAllowed(jail.path("root/style.css"), roots: roots))
    #expect(AssetPolicy.isAllowed(jail.path("root/images/header.png"), roots: roots))
  }

  @Test func anAssetOutsideEveryRootIsRefused() throws {
    let jail = try Jail()
    defer { jail.remove() }
    try jail.touch("root/style.css")
    try jail.touch("elsewhere/secret.txt")

    let roots = [jail.path("root")]
    #expect(!AssetPolicy.isAllowed(jail.path("elsewhere/secret.txt"), roots: roots))
    #expect(!AssetPolicy.isAllowed("/etc/hosts", roots: roots))
  }

  @Test func anAssetCannotClimbOutWithDotDot() throws {
    let jail = try Jail()
    defer { jail.remove() }
    try jail.touch("root/style.css")
    try jail.touch("elsewhere/secret.txt")

    #expect(!AssetPolicy.isAllowed(jail.path("root/../elsewhere/secret.txt"), roots: [jail.path("root")]))
  }

  /// A link inside a root is the user's placement, the way a bundle repository checked out elsewhere is linked
  /// into the bundles directory, so the path is judged as written and the link is honored.
  @Test func aSymbolicLinkInsideARootIsHonored() throws {
    let jail = try Jail()
    defer { jail.remove() }
    try jail.touch("root/style.css")
    try jail.touch("elsewhere/style.css")
    try jail.link("root/link", to: "elsewhere")

    let roots = [jail.path("root")]
    #expect(AssetPolicy.isAllowed(jail.path("root/link/style.css"), roots: roots))
    #expect(!AssetPolicy.isAllowed(jail.path("elsewhere/style.css"), roots: roots))
  }

  @Test func rootContainmentIsByPathComponent() throws {
    let jail = try Jail()
    defer { jail.remove() }
    try jail.touch("root/style.css")
    try jail.touch("rootling/style.css")

    #expect(!AssetPolicy.isAllowed(jail.path("rootling/style.css"), roots: [jail.path("root")]))
  }

  @Test func anyOfSeveralRootsAdmitsAndAnEmptyOneAdmitsNothing() throws {
    let jail = try Jail()
    defer { jail.remove() }
    try jail.touch("bundles/support/style.css")
    try jail.touch("project/notes/pic.png")
    try jail.touch("elsewhere/x.png")

    let roots = [jail.path("bundles"), "", jail.path("project")]
    #expect(AssetPolicy.isAllowed(jail.path("bundles/support/style.css"), roots: roots))
    #expect(AssetPolicy.isAllowed(jail.path("project/notes/pic.png"), roots: roots))
    #expect(!AssetPolicy.isAllowed(jail.path("elsewhere/x.png"), roots: roots))
    #expect(!AssetPolicy.isAllowed("/anything", roots: [""]))
  }

  /// The application hands commands the resolved path of a linked bundle, so the roots built from the bundle
  /// locations take in each link's target as well.
  @Test func rootsTakeInTheTargetsOfLinkedBundles() throws {
    let jail = try Jail()
    defer { jail.remove() }
    try jail.touch("location/Bundles/native.tmbundle/Support/a.css")
    try jail.touch("checkout/linked.tmbundle/Support/b.css")
    try jail.touch("checkout/other.txt")
    try jail.link("location/Bundles/linked.tmbundle", to: "checkout/linked.tmbundle")

    let roots = AssetPolicy.roots(forBundleLocations: [jail.path("location"), ""])
    #expect(AssetPolicy.isAllowed(jail.path("location/Bundles/native.tmbundle/Support/a.css"), roots: roots))
    #expect(AssetPolicy.isAllowed(jail.path("location/Bundles/linked.tmbundle/Support/b.css"), roots: roots))
    let resolvedAsset = try #require(AssetPolicy.resolvedPath(jail.path("checkout/linked.tmbundle/Support/b.css")))
    #expect(AssetPolicy.isAllowed(resolvedAsset, roots: roots))
    let resolvedOther = try #require(AssetPolicy.resolvedPath(jail.path("checkout/other.txt")))
    #expect(!AssetPolicy.isAllowed(resolvedOther, roots: roots))
  }
}
