#include <oak/misc.h>

@interface OakHTMLOutputView : NSView
- (void)loadRequest:(NSURLRequest*)aRequest environment:(std::map<std::string, std::string> const&)anEnvironment autoScrolls:(BOOL)flag;
- (void)stopLoadingWithUserInteraction:(BOOL)askUserFlag completionHandler:(void(^)(BOOL didStop))handler;
- (void)setContent:(NSString*)someHTML;

@property (nonatomic) NSUUID* commandIdentifier; // UUID from initial load request
@property (nonatomic, getter = isRunningCommand, readonly) BOOL runningCommand;
@property (nonatomic, getter = isVisible, readonly) BOOL visible;
@property (nonatomic, getter = isReusable) BOOL reusable;
@property (nonatomic) BOOL disableJavaScriptAPI;

// The view that should take keyboard focus when this output is shown.
@property (nonatomic, readonly) NSView* contentView;

// Ask the output to close itself the way the user closing it would.
- (void)closeAsIfRequestedByPage;
@property (nonatomic, readonly) BOOL needsNewWebView;
@end
