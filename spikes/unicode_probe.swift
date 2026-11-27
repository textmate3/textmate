// Spike: which Unicode data Core Foundation, ICU and Swift carry on this macOS.
//
// Core Foundation has no call that names its Unicode version, so its grapheme
// counts on strings whose rules changed between versions are the evidence.
// ICU does name its versions, and its break iterator is counted beside it.
// Swift's String counts graphemes with the standard library's own tables.

import CoreFoundation
import Foundation

struct Probe {
  let name: String
  let text: String
}

let probes: [Probe] = [
  Probe(name: "e + combining acute", text: "e\u{301}"),
  Probe(name: "CR LF", text: "\r\n"),
  Probe(name: "Hangul jamo L V T", text: "\u{1100}\u{1161}\u{11A8}"),
  Probe(name: "keycap 1", text: "1\u{FE0F}\u{20E3}"),
  Probe(name: "waving hand, medium skin tone", text: "\u{1F44B}\u{1F3FD}"),
  Probe(name: "family, four people joined", text: "\u{1F468}\u{200D}\u{1F469}\u{200D}\u{1F467}\u{200D}\u{1F466}"),
  Probe(name: "flag of Scotland, tag sequence", text: "\u{1F3F4}\u{E0067}\u{E0062}\u{E0073}\u{E0063}\u{E0074}\u{E007F}"),
  Probe(name: "two flags, US then France", text: "\u{1F1FA}\u{1F1F8}\u{1F1EB}\u{1F1F7}"),
  Probe(name: "phoenix, Emoji 15.1 sequence", text: "\u{1F426}\u{200D}\u{1F525}"),
  Probe(name: "Devanagari ksha + i (conjunct)", text: "\u{0915}\u{094D}\u{0937}\u{093F}"),
  Probe(name: "Bengali ksha (conjunct)", text: "\u{0995}\u{09CD}\u{09B7}"),
  Probe(name: "Telugu ksha (conjunct)", text: "\u{0C15}\u{0C4D}\u{0C37}"),
  Probe(name: "Malayalam kka (conjunct)", text: "\u{0D15}\u{0D4D}\u{0D15}"),
]

func coreFoundationCount(_ text: String) -> Int {
  let string = text as CFString
  let length = CFStringGetLength(string)
  var index: CFIndex = 0
  var count = 0
  while index < length {
    let range = CFStringGetRangeOfComposedCharactersAtIndex(string, index)
    index = range.location + range.length
    count += 1
  }
  return count
}

// libicucore ships in macOS without headers, so its functions are looked up by name.
let icu = dlopen("/usr/lib/libicucore.A.dylib", RTLD_NOW)

func icuFunction<T>(_ name: String, as type: T.Type) -> T? {
  guard let icu, let symbol = dlsym(icu, name) else { return nil }
  return unsafeBitCast(symbol, to: type)
}

typealias VersionFunction = @convention(c) (UnsafeMutablePointer<UInt8>) -> Void
typealias BreakOpen = @convention(c) (Int32, UnsafePointer<CChar>?, UnsafePointer<UInt16>?, Int32, UnsafeMutablePointer<Int32>) -> OpaquePointer?
typealias BreakNext = @convention(c) (OpaquePointer?) -> Int32
typealias BreakClose = @convention(c) (OpaquePointer?) -> Void

func icuVersion(_ name: String) -> String {
  guard let function = icuFunction(name, as: VersionFunction.self) else { return "missing" }
  var version = [UInt8](repeating: 0, count: 4)
  version.withUnsafeMutableBufferPointer { function($0.baseAddress!) }
  return version.map(String.init).joined(separator: ".")
}

let breakOpen = icuFunction("ubrk_open", as: BreakOpen.self)
let breakNext = icuFunction("ubrk_next", as: BreakNext.self)
let breakClose = icuFunction("ubrk_close", as: BreakClose.self)

func icuCount(_ text: String) -> String {
  guard let breakOpen, let breakNext, let breakClose else { return "missing" }
  let units = Array(text.utf16)
  var status: Int32 = 0
  let characterBreaks: Int32 = 0
  let iterator = units.withUnsafeBufferPointer { breakOpen(characterBreaks, "", $0.baseAddress, Int32($0.count), &status) }
  guard status <= 0, iterator != nil else { return "error \(status)" }
  defer { breakClose(iterator) }
  var count = 0
  while breakNext(iterator) != -1 {
    count += 1
  }
  return String(count)
}

let os = ProcessInfo.processInfo.operatingSystemVersionString
print("macOS: \(os)")
print("ICU library version: \(icuVersion("u_getVersion"))")
print("ICU Unicode version: \(icuVersion("u_getUnicodeVersion"))")
print("")
print("| Probe | Code points | Core Foundation | ICU | Swift String |")
print("| --- | ---: | ---: | ---: | ---: |")
for probe in probes {
  let codePoints = probe.text.unicodeScalars.count
  print("| \(probe.name) | \(codePoints) | \(coreFoundationCount(probe.text)) | \(icuCount(probe.text)) | \(probe.text.count) |")
}
