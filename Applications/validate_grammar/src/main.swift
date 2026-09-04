import BundleSchema
import Foundation

/// Checks grammar files against the grammar schema and prints what it finds,
/// one line per issue with the path to the rule. Exits nonzero when any file
/// has an issue or cannot be read, so a bundle's tests can run it.
@main struct ValidateGrammar {
  static func main() {
    let paths = Array(CommandLine.arguments.dropFirst())
    if paths.isEmpty {
      FileHandle.standardError.write(Data("usage: validate_grammar <grammar.tmLanguage> ...\n".utf8))
      exit(64)
    }

    let validator = GrammarValidator()
    var clean = 0
    var flagged = 0
    var unreadable = 0

    for path in paths {
      guard let data = FileManager.default.contents(atPath: path),
        let plist = try? PropertyListSerialization.propertyList(from: data, format: nil),
        let grammar = plist as? [String: Any]
      else {
        print("\(path): not a property list dictionary")
        unreadable += 1
        continue
      }

      let issues = validator.issues(in: grammar)
      if issues.isEmpty {
        clean += 1
        continue
      }

      flagged += 1
      print(path)
      for issue in issues {
        print("  \(issue)")
      }
    }

    print("\(paths.count) grammars: \(clean) clean, \(flagged) with issues, \(unreadable) unreadable")
    exit(flagged == 0 && unreadable == 0 ? 0 : 1)
  }
}
