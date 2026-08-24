#import "HOWebViewDelegateHelper.h"
#import "HOBrowserView.h"
#import <OakAppKit/NSAlert Additions.h>
#import <OakFoundation/NSString Additions.h>
#import <io/path.h>
#import <oak/debug.h>

static NSString* const kUserDefaultsDefaultURLProtocolKey = @"defaultURLProtocol";

static BOOL IsProtocolRelativeURL (NSURL* url)
{
	if([url.scheme hasPrefix:@"x-txmt"] && ![url.host isEqualToString:@"job"])
		return YES;

	if([url.scheme isEqualToString:@"file"] && url.host)
	{
		// If host has a dot and does not exist on disk then treat as protocol-relative URL
		if([url.host containsString:@"."] && ![NSFileManager.defaultManager fileExistsAtPath:[@"/" stringByAppendingPathComponent:url.host]])
			return YES;
	}

	return NO;
}

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

- (void)webView:(WebView*)sender setStatusText:(NSString*)text
{
	[_delegate setStatusText:(text ?: @"")];
}

- (NSString*)webViewStatusText:(WebView*)sender
{
	return [_delegate statusText];
}

- (void)webView:(WebView*)sender mouseDidMoveOverElement:(NSDictionary*)elementInformation modifierFlags:(NSUInteger)modifierFlags
{
	NSURL* url = [elementInformation objectForKey:@"WebElementLinkURL"];
	[self webView:sender setStatusText:[[url absoluteString] stringByRemovingPercentEncoding]];
}

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

	// Returning the new view tells WebKit to load the navigation into it, so unlike
	// the old delegate there is no separate loadRequest: here.
	return view.webView;
}

- (void)webViewDidClose:(WKWebView*)webView
{
	if(![webView tryToPerform:@selector(toggleHTMLOutput:) with:self])
		[webView tryToPerform:@selector(performClose:) with:self];
	self.needsNewWebView = YES;
}

// This is an undocumented WebView delegate method
- (void)webView:(WebView*)webView addMessageToConsole:(NSDictionary*)dictionary;
{
	if([dictionary respondsToSelector:@selector(objectForKey:)])
		os_log(OS_LOG_DEFAULT, "%{public}@: %{public}@ on line %d\n", webView.mainFrame.dataSource.request.URL.absoluteString, [dictionary objectForKey:@"message"], [[dictionary objectForKey:@"lineNumber"] intValue]);
}

// =====================================================
// = WebResourceLoadDelegate: Redirect tm-file to file =
// =====================================================

- (NSURLRequest*)webView:(WebView*)sender resource:(id)identifier willSendRequest:(NSURLRequest*)request redirectResponse:(NSURLResponse*)redirectResponse fromDataSource:(WebDataSource*)dataSource
{
	if([[[request URL] scheme] isEqualToString:@"tm-file"])
	{
		NSString* fragment = [[request URL] fragment];
		request = [NSURLRequest requestWithURL:[NSURL URLWithString:[NSString stringWithFormat:@"file://localhost%@%s%@", [[[request URL] path] stringByAddingPercentEncodingWithAllowedCharacters:NSCharacterSet.URLPathAllowedCharacterSet], fragment ? "#" : "", fragment ?: @""]]];
	}

	if(IsProtocolRelativeURL([request URL]))
	{
		NSURLComponents* components = [NSURLComponents componentsWithURL:[request URL] resolvingAgainstBaseURL:YES];
		components.scheme = [NSUserDefaults.standardUserDefaults stringForKey:kUserDefaultsDefaultURLProtocolKey];
		request = [NSURLRequest requestWithURL:components.URL];
	}

	if([[request URL] isFileURL])
	{
		NSURL* redirectURL = [NSURL URLWithString:[NSString stringWithFormat:@"file://localhost%@?path=%@&error=1", [[[NSBundle bundleForClass:[self class]] pathForResource:@"error_not_found" ofType:@"html"] stringByAddingPercentEncodingWithAllowedCharacters:NSCharacterSet.URLPathAllowedCharacterSet], [[[request URL] path] stringByAddingPercentEncodingWithAllowedCharacters:NSCharacterSet.URLQueryAllowedCharacterSet]]];
		char const* path = [[request URL] fileSystemRepresentation];

		struct stat buf;
		if(path && stat(path, &buf) == 0)
		{
			if(S_ISREG(buf.st_mode) || S_ISLNK(buf.st_mode))
			{
				redirectURL = nil;
			}
			else if(S_ISDIR(buf.st_mode))
			{
				if(path::exists(path::join(path, "index.html")))
				{
					NSString* urlString = [[NSURL URLWithString:@"index.html" relativeToURL:[request URL]] absoluteString];
					if(NSString* query = [[request URL] query])
						urlString = [urlString stringByAppendingFormat:@"?%@", query];
					if(NSString* fragment = [[request URL] fragment])
						urlString = [urlString stringByAppendingFormat:@"#%@", fragment];
					redirectURL = [NSURL URLWithString:urlString];
				}
			}
		}

		if(redirectURL)
			request = [NSURLRequest requestWithURL:redirectURL];
	}

	return request;
}
@end

@interface HTMLTMFileDummyProtocol : NSURLProtocol { }
@end

@implementation HTMLTMFileDummyProtocol
+ (void)load                                                                                                                                      { [self registerClass:self]; }
+ (BOOL)canInitWithRequest:(NSURLRequest*)request                                                                                                 { return [[[request URL] scheme] isEqualToString:@"tm-file"]; }
+ (NSURLRequest*)canonicalRequestForRequest:(NSURLRequest*)request                                                                                { return request; }
+ (BOOL)requestIsCacheEquivalent:(NSURLRequest*)a toRequest:(NSURLRequest*)b                                                                      { return NO; }
@end
