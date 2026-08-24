#import <WebKit/WebKit.h>

@protocol HOJSBridgeDelegate
@property (nonatomic, getter = isBusy) BOOL busy;
@property (nonatomic) double progress;
@end

// The application half of the TextMate object that HTML output pages call.
//
// The page half is resources/TextMateBridge.js, injected as a user script. Calls
// arrive here as messages and are answered through a reply handler, because
// WKWebView offers no synchronous path from JavaScript into the application.
@interface HOJSBridge : NSObject <WKScriptMessageHandlerWithReply>
@property (nonatomic, weak) id <HOJSBridgeDelegate> delegate;
@property (nonatomic, weak) WKWebView* webView;   // for pushing streamed output back

- (void)setEnvironment:(const std::map<std::string, std::string>&)variables;
- (std::map<std::string, std::string> const&)environment;

// The name the page posts to, and the script that defines the object.
+ (NSString*)messageHandlerName;
+ (NSString*)userScriptSource;
@end
