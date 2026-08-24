#import <WebKit/WebKit.h>

// The scheme that carries a running command's HTML output, and the page's own
// assets alongside it.
extern NSString* const HOFileHandleURLScheme;

// The legacy web view took the output pipe as an NSURLProtocol property on the
// request. Those do not survive the crossing into WKWebView's content process,
// so a job is registered here by URL before loading and looked up when the
// content process asks for it.
@interface HOFileHandleSchemeHandler : NSObject <WKURLSchemeHandler>
+ (void)registerFileHandle:(NSFileHandle*)fileHandle processIdentifier:(pid_t)processIdentifier forURL:(NSURL*)url;
+ (void)unregisterURL:(NSURL*)url;
@end
