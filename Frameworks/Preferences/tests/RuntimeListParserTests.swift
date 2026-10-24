import Foundation
import Testing

@testable import Preferences

/// Captured output of `rv ruby list --format json` and `uv python list --managed-python --output-format json`, next to this file.
private func fixture(_ name: String) throws -> Data {
  try Data(contentsOf: URL(fileURLWithPath: #filePath).deletingLastPathComponent().appending(path: "fixtures/\(name)"))
}

@Suite struct RubyListParsing {
  @Test func keepsFinalRubiesNewestFirst() throws {
    let versions = try RuntimeListParser.rubyVersions(from: try fixture("rv_ruby_list.json"))
    #expect(versions.map(\.version) == ["4.0.9", "4.0.8", "4.0.7", "4.0.6", "3.4.12", "3.4.9", "3.3.13", "3.2.11"])
  }

  @Test func tellsInstalledFromDownloadable() throws {
    let versions = try RuntimeListParser.rubyVersions(from: try fixture("rv_ruby_list.json"))
    let installed = versions.filter(\.isInstalled).map(\.version)
    #expect(installed == ["4.0.9", "4.0.8", "4.0.7", "4.0.6", "3.4.9"])
    #expect(versions.first?.path == "/Users/someone/.local/share/rv/rubies/ruby-4.0.9")
    #expect(versions.last?.path == nil)
  }

  @Test func leavesOutJRubyAndPreviews() throws {
    let versions = try RuntimeListParser.rubyVersions(from: try fixture("rv_ruby_list.json"))
    #expect(!versions.contains { $0.version.contains("preview") || $0.version.contains("jruby") })
  }
}

@Suite struct PythonListParsing {
  @Test func keepsFinalCPythonsOncePerVersionNewestFirst() throws {
    let versions = try RuntimeListParser.pythonVersions(from: try fixture("uv_python_list.json"))
    #expect(versions.map(\.version) == ["3.14.7", "3.13.15", "3.12.14", "3.11.16", "3.10.21", "3.9.25", "3.8.20"])
  }

  @Test func prefersTheCopyInsideUvsDirectoryOverALinkToIt() throws {
    let versions = try RuntimeListParser.pythonVersions(from: try fixture("uv_python_list.json"))
    let newest = try #require(versions.first)
    #expect(newest.isInstalled)
    #expect(newest.path == "/Users/someone/.local/share/uv/python/cpython-3.14-macos-aarch64-none/bin/python3.14")
    #expect(versions.filter(\.isInstalled).map(\.version) == ["3.14.7", "3.13.15"])
  }

  @Test func leavesOutReleaseCandidatesAndOtherVariants() throws {
    let versions = try RuntimeListParser.pythonVersions(from: try fixture("uv_python_list.json"))
    #expect(!versions.contains { $0.version.contains("rc") })
  }
}

@Suite struct VersionOrdering {
  @Test func comparesNumbersNotCharacters() {
    let versions = ["4.0.9", "4.0.10", "3.14.7", "4.1.0"].map { RuntimeVersion(version: $0, isInstalled: false, path: nil) }
    #expect(RuntimeListParser.newestFirst(versions).map(\.version) == ["4.1.0", "4.0.10", "4.0.9", "3.14.7"])
  }

  @Test func onlyThreeNumbersIsAFinalRelease() {
    #expect(RuntimeListParser.isFinalRelease("4.0.9"))
    #expect(!RuntimeListParser.isFinalRelease("4.0"))
    #expect(!RuntimeListParser.isFinalRelease("4.1.0-preview1"))
    #expect(!RuntimeListParser.isFinalRelease("3.15.0rc2"))
  }
}
