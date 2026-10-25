import Foundation

/// One version a runtime manager knows: installed on this machine, with where, or only downloadable.
struct RuntimeVersion: Identifiable, Equatable, Sendable {
  let version: String
  let isInstalled: Bool
  let path: String?

  var id: String { version }
}

/// What `rv ruby list --format json` and `uv python list --output-format json` say, read into versions.
/// Pure functions over the data, so the tests feed them captured output.
/// Only final releases of the reference implementation are kept: no previews or release candidates, no JRuby, no free threaded builds.
/// What the pane shows is what the application could pin, and it pins nothing else.
enum RuntimeListParser {
  /// rv lists one object per Ruby, keyed `Installed` or `Remote`, with the version as `ruby-4.0.9`.
  static func rubyVersions(from data: Data) throws -> [RuntimeVersion] {
    let entries = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] ?? []
    let versions = entries.compactMap { entry -> RuntimeVersion? in
      let installed = entry["Installed"] as? [String: Any]
      guard let record = installed ?? entry["Remote"] as? [String: Any], let named = record["version"] as? String else { return nil }
      guard named.hasPrefix("ruby-") else { return nil }
      let version = String(named.dropFirst("ruby-".count))
      guard isFinalRelease(version) else { return nil }
      return RuntimeVersion(version: version, isInstalled: installed != nil, path: installed?["path"] as? String)
    }
    return newestFirst(versions)
  }

  /// uv lists every build it knows, installed or downloadable, with a path for the installed ones.
  /// An installed Python appears once per place uv linked it, so a version is kept once, preferring the copy inside uv's own directory over a link to it.
  static func pythonVersions(from data: Data) throws -> [RuntimeVersion] {
    let entries = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] ?? []
    var byVersion: [String: RuntimeVersion] = [:]
    for entry in entries {
      guard entry["implementation"] as? String == "cpython", entry["variant"] as? String == "default" else { continue }
      guard let version = entry["version"] as? String, isFinalRelease(version) else { continue }
      let path = entry["path"] as? String
      let candidate = RuntimeVersion(version: version, isInstalled: path != nil, path: path)
      guard let existing = byVersion[version] else {
        byVersion[version] = candidate
        continue
      }
      if candidate.isInstalled && (!existing.isInstalled || (path?.contains("/uv/python/") == true && existing.path?.contains("/uv/python/") != true)) {
        byVersion[version] = candidate
      }
    }
    return newestFirst(Array(byVersion.values))
  }

  /// Three numbers and nothing else: `4.0.9` yes, `4.1.0-preview1` and `3.15.0rc2` no.
  static func isFinalRelease(_ version: String) -> Bool {
    let parts = version.split(separator: ".", omittingEmptySubsequences: false)
    return parts.count == 3 && parts.allSatisfy { !$0.isEmpty && $0.allSatisfy(\.isNumber) }
  }

  /// Newest first, comparing the three numbers as numbers, so 4.0.10 is newer than 4.0.9.
  static func newestFirst(_ versions: [RuntimeVersion]) -> [RuntimeVersion] {
    versions.sorted { numbers($0.version).lexicographicallyPrecedes(numbers($1.version)) == false && numbers($0.version) != numbers($1.version) }
  }

  /// Whether the first version is newer than the second, by the numbers.
  static func isNewer(_ version: String, than other: String) -> Bool {
    numbers(other).lexicographicallyPrecedes(numbers(version))
  }

  private static func numbers(_ version: String) -> [Int] {
    version.split(separator: ".").map { Int($0) ?? 0 }
  }
}

/// rv or uv on this machine, found the way the resolvers find them: the person's own first, the bundle's last.
/// Runs the manager and reads its answer, which is work for a background task since a list can ask the network.
struct RuntimeManager: Sendable {
  let name: String
  let executable: URL

  var path: String { executable.path }

  static func find(_ name: String, bundleSupportPath: String?) -> RuntimeManager? {
    let home = FileManager.default.homeDirectoryForCurrentUser.path
    var candidates = ["/opt/homebrew/bin/\(name)", "\(home)/.local/bin/\(name)", "\(home)/.cargo/bin/\(name)", "/usr/local/bin/\(name)"]
    if let bundleSupportPath {
      candidates.append("\(bundleSupportPath)/bin/\(name)")
    }
    guard let found = candidates.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) else { return nil }
    return RuntimeManager(name: name, executable: URL(fileURLWithPath: found))
  }

  /// The first line of `--version`, such as `rv 0.7.2` or `uv 0.13.5 (46776a95d 2026-10-21)`.
  func version() -> String? {
    guard let output = try? run(["--version"]), let line = String(data: output, encoding: .utf8)?.split(separator: "\n").first else { return nil }
    return String(line)
  }

  func rubyVersions() throws -> [RuntimeVersion] {
    try RuntimeListParser.rubyVersions(from: run(["ruby", "list", "--format", "json"]))
  }

  func pythonVersions() throws -> [RuntimeVersion] {
    try RuntimeListParser.pythonVersions(from: run(["python", "list", "--managed-python", "--output-format", "json"]))
  }

  private func run(_ arguments: [String]) throws -> Data {
    let process = Process()
    process.executableURL = executable
    process.arguments = arguments
    let output = Pipe()
    process.standardOutput = output
    process.standardError = FileHandle.nullDevice
    try process.run()
    let data = output.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()
    return data
  }
}
