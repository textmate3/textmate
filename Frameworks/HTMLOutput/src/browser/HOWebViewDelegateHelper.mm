#import "HOWebViewDelegateHelper.h"
#import "HOBrowserView.h"
#import <OakAppKit/NSAlert Additions.h>
#import <OakFoundation/NSString Additions.h>
#import <io/path.h>
#import <oak/debug.h>

static NSString* const kUserDefaultsDefaultURLProtocolKey = @"defaultURLProtocol";

@implementation HOWebViewDelegateHelper
+ (void)initialize
{
	[NSUserDefaults.standardUserDefaults registerDefaults:@{
		kUserDefaultsDefaultURLProtocolKey: @"https",
	}];
}

// =====================
// = WebViewUIDelegate =
// =====================

// The status bar previewed a link's target while the pointer was over it, through
// setStatusText: and mouseDidMoveOverElement:. WKUIDelegate has neither, so that
// preview is gone. Reinstating it means a script that reports mouseover events.

- (void)webView:(WKWebView*)webView runJavaScriptAlertPanelWithMessage:(NSString*)message initiatedByFrame:(WKFrameInfo*)frame completionHandler:(void(^)(void))completionHandler
{
	NSAlert* alert = [NSAlert tmAlertWithMessageText:NSLocalizedString(@"Script Message", @"JavaScript alert title") informativeText:message buttons:NSLocalizedString(@"OK", @"JavaScript alert confirmation"), nil];
	[alert beginSheetModalForWindow:webView.window completionHandler:^(NSModalResponse response){
		completionHandler();
	}];
}

- (void)webView:(WKWebView*)webView runJavaScriptConfirmPanelWithMessage:(NSString*)message initiatedByFrame:(WKFrameInfo*)frame completionHandler:(void(^)(BOOL result))completionHandler
{
	NSAlert* alert        = [[NSAlert alloc] init];
	alert.messageText     = NSLocalizedString(@"Script Message", @"JavaScript alert title");
	alert.informativeText = message;
	[alert addButtons:NSLocalizedString(@"OK", @"JavaScript alert confirmation"), NSLocalizedString(@"Cancel", @"JavaScript alert cancel"), nil];
	[alert beginSheetModalForWindow:webView.window completionHandler:^(NSModalResponse response){
		completionHandler(response == NSAlertFirstButtonReturn);
	}];
}

- (void)webView:(WKWebView*)webView runOpenPanelWithParameters:(WKOpenPanelParameters*)parameters initiatedByFrame:(WKFrameInfo*)frame completionHandler:(void(^)(NSArray<NSURL*>* URLs))completionHandler
{
	NSOpenPanel* panel = [NSOpenPanel openPanel];
	panel.directoryURL          = [NSURL fileURLWithPath:NSHomeDirectory()];
	panel.allowsMultipleSelection = parameters.allowsMultipleSelection;
	[panel beginSheetModalForWindow:webView.window completionHandler:^(NSModalResponse response){
		completionHandler(response == NSModalResponseOK ? panel.URLs : nil);
	}];
}

- (WKWebView*)webView:(WKWebView*)webView createWebViewWithConfiguration:(WKWebViewConfiguration*)configuration forNavigationAction:(WKNavigationAction*)navigationAction windowFeatures:(WKWindowFeatures*)windowFeatures
{
	NSPoint origin = [webView.window cascadeTopLeftFromPoint:NSMakePoint(NSMinX(webView.window.frame), NSMaxY(webView.window.frame))];
	origin.y -= NSHeight(webView.window.frame);

	HOBrowserView* view = [HOBrowserView new];
	NSWindow* window = [[NSWindow alloc] initWithContentRect:(NSRect){origin, NSMakeSize(750, 800)}
														  styleMask:(NSWindowStyleMaskTitled|NSWindowStyleMaskClosable|NSWindowStyleMaskResizable|NSWindowStyleMaskMiniaturizable)
															 backing:NSBackingStoreBuffered
																defer:NO];
	[window bind:NSTitleBinding toObject:view.webView withKeyPath:@"title" options:nil];
	[window setContentView:view];
	[window makeKeyAndOrderFront:self];

	__attribute__ ((unused)) CFTypeRef dummy = CFBridgingRetain(window);
	[window setReleasedWhenClosed:YES];

	// Returning the new view is what tells WebKit to load the navigation into it. Nothing else has
	// to request the load.
	return view.webView;
}

- (void)webViewDidClose:(WKWebView*)webView
{
	if(![webView tryToPerform:@selector(toggleHTMLOutput:) with:self])
		[webView tryToPerform:@selector(performClose:) with:self];
	self.needsNewWebView = YES;
}

// There is no hook for rewriting arbitrary subresource requests. Link clicks can be intercepted, in
// the navigation delegate, but the requests a page makes for its own assets cannot.
//
// Link clicks can be handled in decidePolicyForNavigationAction, which
// OakHTMLOutputView implements. Subresources cannot.

@end

@interface HTMLTMFileDummyProtocol : NSURLProtocol { }
@end

@implementation HTMLTMFileDummyProtocol
+ (void)load                                                                                                                                      { [self registerClass:self]; }
+ (BOOL)canInitWithRequest:(NSURLRequest*)request                                                                                                 { return [[[request URL] scheme] isEqualToString:@"tm-file"]; }
+ (NSURLRequest*)canonicalRequestForRequest:(NSURLRequest*)request                                                                                { return request; }
+ (BOOL)requestIsCacheEquivalent:(NSURLRequest*)a toRequest:(NSURLRequest*)b                                                                      { return NO; }
@end
