import OakFoundation
import Testing

/// The same round trip as t_application_info.mm, from Swift Testing: the first
/// Swift test in the tree, run by its own executable under <target>/test/run.
@Suite struct ApplicationInfoTests {
  @Test func readsTheDictionary() {
    let info = ApplicationInfo(infoDictionary: [
      "CFBundleShortVersionString": "2.1.0",
      "NSHumanReadableCopyright": "© 2026"
    ])
    #expect(info.shortVersion == "2.1.0")
    #expect(info.copyright == "© 2026")
  }

  @Test func isEmptyWithoutKeys() {
    let info = ApplicationInfo(infoDictionary: [:])
    #expect(info.shortVersion == "")
    #expect(info.copyright == "")
  }
}
