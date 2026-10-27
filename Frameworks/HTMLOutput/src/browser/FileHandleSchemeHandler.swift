import Foundation
import OSLog
import UniformTypeIdentifiers
import WebKit

/// The scheme that carries a running command's HTML output, and the page's own assets alongside it.
///
/// The legacy web view took the output pipe as a URL protocol property on the request. Those do not survive
/// the crossing into WebKit's content process, so a job is registered here by URL before loading and looked up
/// when the content process asks for it. One registry for the process, because the content process may ask
/// through any web view that has this handler installed.
@objc(HOFileHandleSchemeHandler)
@MainActor
public final class FileHandleSchemeHandler: NSObject, @MainActor WKURLSchemeHandler {
  @objc public static let scheme = "x-txmt-filehandle"

  /// A command whose output a page is showing: the pipe its output arrives on, its process group,
  /// and the directories the page may read its own assets from, the document's and the project's.
  private final class Job: @unchecked Sendable {
    var fileHandle: FileHandle?
    let processIdentifier: pid_t
    var stopped = false
    let allowedDirectories: [String]

    init(fileHandle: FileHandle?, processIdentifier: pid_t, allowedDirectories: [String]) {
      self.fileHandle = fileHandle
      self.processIdentifier = processIdentifier
      self.allowedDirectories = allowedDirectories
    }
  }

  /// Keyed by absolute URL string. Registration happens on whichever queue the command's output handler runs on,
  /// while lookup happens on the main thread when the content process asks. Every access takes the lock: without it
  /// a job registered on one thread was not found on the other, and a frame load interrupted error took its place.
  nonisolated private static let jobsLock = NSLock()
  nonisolated(unsafe) private static var jobs: [String: Job] = [:]

  private var activeTasks = Set<ObjectIdentifier>()
  private let logger = Logger(subsystem: "com.textmate3.TextMate", category: "HTMLOutput")

  @objc(registerFileHandle:processIdentifier:allowedDirectories:forURL:)
  nonisolated public static func registerFileHandle(_ fileHandle: FileHandle?, processIdentifier: pid_t, allowedDirectories: [String], forURL url: URL) {
    let job = Job(fileHandle: fileHandle, processIdentifier: processIdentifier, allowedDirectories: allowedDirectories)
    jobsLock.withLock { jobs[url.absoluteString] = job }
  }

  nonisolated private static func job(for url: URL) -> Job? {
    jobsLock.withLock { jobs[url.absoluteString] }
  }

  @objc(unregisterURL:)
  nonisolated public static func unregister(_ url: URL) {
    jobsLock.withLock { jobs[url.absoluteString] = nil }
  }

  /// Marks the page's output as delivered while keeping its directories, since the page goes on loading assets after that.
  @objc(finishURL:)
  nonisolated public static func finish(_ url: URL) {
    jobsLock.withLock { jobs[url.absoluteString]?.fileHandle = nil }
  }

  public func webView(_ webView: WKWebView, start task: any WKURLSchemeTask) {
    activeTasks.insert(ObjectIdentifier(task))

    if let job = Self.job(for: task.request.url ?? URL(fileURLWithPath: "/")), job.fileHandle != nil {
      return start(job, for: task)
    }

    // No job for this URL, so it is one of the page's own assets: a style sheet, a script, an image.
    // Those cannot be file URLs, because a page served from a custom scheme is not permitted to load them,
    // so they come back through this scheme and are read from disk here. The read is confined to the bundle
    // locations and to the directories the page's command ran against, which the page is identified by
    // through the request's main document URL.
    if let url = task.request.url, !url.path.isEmpty {
      let path = url.path
      if !isAssetPathAllowed(path, forMainDocumentURL: task.request.mainDocumentURL) {
        logger.log("refusing to serve \(path, privacy: .public) to \(task.request.mainDocumentURL?.absoluteString ?? "no page", privacy: .public), outside every allowed directory")
      } else if let data = FileManager.default.contents(atPath: path) {
        let type = UTType(filenameExtension: (path as NSString).pathExtension)
        let response = URLResponse(url: url, mimeType: type?.preferredMIMEType ?? "application/octet-stream", expectedContentLength: data.count, textEncodingName: nil)
        finish(task, with: response, data: data)
        return
      }
    }

    let response = HTTPURLResponse(url: task.request.url ?? URL(fileURLWithPath: "/"), statusCode: 404, httpVersion: "HTTP/1.1", headerFields: nil) ?? URLResponse()
    finish(task, with: response, data: nil)
  }

  /// Whether a page's asset request may be read from disk: the path must sit under a bundle location, or under a
  /// directory registered for the page the request belongs to, identified by the request's main document URL.
  @objc(isAssetPathAllowed:forMainDocumentURL:)
  public func isAssetPathAllowed(_ path: String, forMainDocumentURL mainDocumentURL: URL?) -> Bool {
    var roots = HOSchemeHandlerSupport.bundleAssetRoots()
    if let mainDocumentURL, let job = Self.job(for: mainDocumentURL) {
      roots += job.allowedDirectories
    }
    return HOSchemeHandlerSupport.isPath(path, allowedUnderAnyOf: roots)
  }

  /// Streams the command's output to the page as it arrives: read on a background queue, delivered on the main one,
  /// and stopped the moment the task is no longer active, since WebKit raises if a task is messaged after it has been stopped.
  private func start(_ job: Job, for task: any WKURLSchemeTask) {
    guard let url = task.request.url, let fileHandle = job.fileHandle else { return }
    let response = URLResponse(url: url, mimeType: "text/html", expectedContentLength: -1, textEncodingName: "utf-8")
    guard isActive(task) else { return }
    task.didReceive(response)

    nonisolated(unsafe) let task = task
    let descriptor = fileHandle.fileDescriptor
    DispatchQueue.global(qos: .default).async { [weak self] in
      var buffer = [UInt8](repeating: 0, count: 8192)
      var length = 0
      while true {
        length = buffer.withUnsafeMutableBytes { read(descriptor, $0.baseAddress, $0.count) }
        guard length > 0 else { break }
        let data = Data(buffer[0..<length])
        var keepGoing = true
        DispatchQueue.main.sync {
          MainActor.assumeIsolated {
            keepGoing = self?.isActive(task) ?? false
            if keepGoing {
              task.didReceive(data)
            }
          }
        }
        if !keepGoing {
          break
        }
      }

      if length == -1 {
        perror("HTMLOutput: read")
      }

      try? fileHandle.close()
      Self.finish(url)
      DispatchQueue.main.sync {
        MainActor.assumeIsolated {
          guard let self, self.isActive(task) else { return }
          task.didFinish()
          self.activeTasks.remove(ObjectIdentifier(task))
        }
      }
    }
  }

  private func isActive(_ task: any WKURLSchemeTask) -> Bool {
    activeTasks.contains(ObjectIdentifier(task))
  }

  private func finish(_ task: any WKURLSchemeTask, with response: URLResponse, data: Data?) {
    guard isActive(task) else { return }
    task.didReceive(response)
    if let data {
      task.didReceive(data)
    }
    task.didFinish()
    activeTasks.remove(ObjectIdentifier(task))
  }

  public func webView(_ webView: WKWebView, stop task: any WKURLSchemeTask) {
    activeTasks.remove(ObjectIdentifier(task))

    if let url = task.request.url, let job = Self.job(for: url) {
      job.stopped = true
      if job.processIdentifier != 0 {
        HOSchemeHandlerSupport.killProcessGroup(inBackground: job.processIdentifier)
      }
    }
  }
}
