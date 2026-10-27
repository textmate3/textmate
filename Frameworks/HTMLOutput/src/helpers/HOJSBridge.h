// A guard by name rather than by file, since this header reaches a compile unit
// twice: from the include farm, and through the Swift header, which carries the
// bridging header's imports by their source path.
#ifndef HO_JS_BRIDGE_H_9A1C3F58
#define HO_JS_BRIDGE_H_9A1C3F58

#import <WebKit/WebKit.h>

@protocol HOJSBridgeDelegate
@property (nonatomic) BOOL isBusy;
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

// The environment the page's commands run in. The Swift view that owns the
// bridge hands it over as a dictionary, since the map is C++ and Swift cannot
// see it; the C++ face stays for the tests and for the shell command.
- (void)setEnvironmentDictionary:(NSDictionary<NSString*, NSString*>*)variables;

#ifdef __cplusplus
- (void)setEnvironment:(const std::map<std::string, std::string>&)variables;
- (std::map<std::string, std::string> const&)environment;
#endif

// The name the page posts to, and the script that defines the object.
+ (NSString*)messageHandlerName;
+ (NSString*)userScriptSource;
@end

// A command started by TextMate.system(). Output is streamed to the handler as it
// arrives, and the completion block carries the whole output, the whole error
// output and the exit status once the command has finished.
@interface HOJSShellCommand : NSObject
@property (nonatomic, copy) void(^streamHandler)(NSString* text, BOOL isError);
@property (nonatomic) NSString* command;
@property (nonatomic, copy) void(^completionHandler)(NSString* output, NSString* error, int status);
#ifdef __cplusplus
- (id)initShellCommand:(NSString*)aCommand withEnvironment:(const std::map<std::string, std::string>&)someEnvironment;
#endif
- (BOOL)start;
- (void)cancelCommand;
- (void)writeToInput:(NSString*)someData;
- (void)closeInput;
@end

#endif /* end of include guard: HO_JS_BRIDGE_H_9A1C3F58 */
