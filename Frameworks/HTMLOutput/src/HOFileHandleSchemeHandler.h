#import <WebKit/WebKit.h>

// The scheme that carries a running command's HTML output, and the page's own
// assets alongside it.
extern NSString* const HOFileHandleURLScheme;
void SchemeTrace (NSString* format, ...);

// The legacy web view took the output pipe as an NSURLProtocol property on the
// request. Those do not survive the crossing into WKWebView's content process,
// so a job is registered here by URL before loading and looked up when the
// content process asks for it.
@interface HOFileHandleSchemeHandler : NSObject <WKURLSchemeHandler>
// The allowed directories are where the page may load its own assets from, on
// top of the bundle locations every page may use: the directory of the document
// and the project the command ran against.
+ (void)registerFileHandle:(NSFileHandle*)fileHandle processIdentifier:(pid_t)processIdentifier allowedDirectories:(NSArray<NSString*>*)allowedDirectories forURL:(NSURL*)url;
+ (void)unregisterURL:(NSURL*)url;
// Marks the page's output as delivered while keeping its directories, since the
// page goes on loading assets after that.
+ (void)finishURL:(NSURL*)url;

// Whether a page's asset request may be read from disk: the path must sit
// under a bundle location, or under a directory registered for the page the
// request belongs to, identified by the request's main document URL.
- (BOOL)isAssetPathAllowed:(NSString*)path forMainDocumentURL:(NSURL*)mainDocumentURL;
@end
