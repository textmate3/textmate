import OakFoundation
import Testing

/// ApplicationInfo read from Swift:
/// the same round trip t_application_info.mm checks from Objective-C++.
@Suite struct ApplicationInfoTests {
  @Test func readsTheDictionary() {
    let info = ApplicationInfo(infoDictionary: [
      "CFBundleShortVersionString": "2.1.0",
      "NSHumanReadableCopyright": "© 2026",
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
