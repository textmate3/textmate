#import "OakHTMLOutputView.h"
#import "browser/HOStatusBar.h"
#import "helpers/HOAutoScroll.h"
#import "helpers/HOJSBridge.h"
#import <OakFoundation/OakFoundation.h>
#import <OakFoundation/NSString Additions.h>
#import <OakAppKit/NSAlert Additions.h>
#import <oak/debug.h>

@interface HOStatusBar (BusyAndProgressProperties) <HOJSBridgeDelegate>
@end

@interface OakHTMLOutputView ()
@property (nonatomic, getter = isRunningCommand, readwrite) BOOL runningCommand;
@property (nonatomic) HOAutoScroll* autoScrollHelper;
@property (nonatomic) std::map<std::string, std::string> environment;
@property (nonatomic) NSRect pendingVisibleRect;
@property (nonatomic) NSURLRequest* loadedRequest;   // WKWebView does not expose the request it loaded
@property (nonatomic, getter = isVisible) BOOL visible;
@end

@implementation OakHTMLOutputView
+ (NSSet*)keyPathsForValuesAffectingMainFrameTitle
{
	return [NSSet setWithObjects:@"webView.mainFrameTitle", nil];
}

- (instancetype)initWithFrame:(NSRect)aRect
{
	if(self = [super initWithFrame:aRect])
	{
		_reusable = YES;
	}
	return self;
}

- (void)loadRequest:(NSURLRequest*)aRequest environment:(std::map<std::string, std::string> const&)anEnvironment autoScrolls:(BOOL)flag
{
	if(flag)
	{
		self.autoScrollHelper = [HOAutoScroll new];
		self.autoScrollHelper.webView = self.webView;
	}

	self.environment = anEnvironment;
	self.commandIdentifier = [NSURLProtocol propertyForKey:@"commandIdentifier" inRequest:aRequest];
	self.runningCommand = self.commandIdentifier != nil;

	self.loadedRequest = aRequest;

	[self willChangeValueForKey:@"mainFrameTitle"];
	[self.webView loadRequest:aRequest];
	[self didChangeValueForKey:@"mainFrameTitle"];
}

- (void)stopLoadingWithUserInteraction:(BOOL)askUserFlag completionHandler:(void(^)(BOOL didStop))handler
{
	NSURLRequest* request = self.loadedRequest;
	if(id command = [NSURLProtocol propertyForKey:@"command" inRequest:request])
	{
		NSAlert* alert = askUserFlag ? [NSAlert tmAlertWithMessageText:[NSString stringWithFormat:@"Stop “%@”?", [NSURLProtocol propertyForKey:@"processName" inRequest:request]] informativeText:@"The job that the task is performing will not be completed." buttons:@"Stop", @"Cancel", nil] : nil;

		__weak __block id token = [NSNotificationCenter.defaultCenter addObserverForName:@"OakCommandDidTerminateNotification" object:command queue:nil usingBlock:^(NSNotification* notification){
			if(alert)
				[self.window endSheet:alert.window returnCode:NSAlertFirstButtonReturn];
			handler(YES);
			[NSNotificationCenter.defaultCenter removeObserver:token];
		}];

		if(alert)
		{
			[alert beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse returnCode){
				if(returnCode == NSAlertFirstButtonReturn) /* "Stop" */
				{
					[self.webView stopLoading];
				}
				else
				{
					handler(NO);
					[NSNotificationCenter.defaultCenter removeObserver:token];
				}
			}];
		}
		else
		{
			[self.webView stopLoading];
		}
	}
	else
	{
		handler(YES);
	}
}

// The web view is what should take focus, but callers should not have to know
// that, nor which class it is. Returning it as a plain NSView keeps the web
// engine an implementation detail.
- (NSView*)contentView
{
	return self.webView;
}

// A page calling window.close() reaches the UI delegate, which knows how to
// fold the output away. Callers that want the same effect asked for it through
// the web view before; now they ask this.
- (void)closeAsIfRequestedByPage
{
	if(id delegate = self.webView.UIDelegate)
		[delegate performSelector:@selector(webViewClose:) withObject:self.webView];
}

- (void)setContent:(NSString*)someHTML
{
	[self.webView loadHTMLString:someHTML baseURL:[NSURL fileURLWithPath:NSHomeDirectory()]];
}

- (NSString*)mainFrameTitle
{
	if(OakIsEmptyString(self.webView.title))
	{
		if(NSURLRequest* request = self.loadedRequest)
			return [NSURLProtocol propertyForKey:@"processName" inRequest:request] ?: @"";
	}
	return self.webView.title ?: @"";
}

- (void)viewDidMoveToWindow
{
	[NSNotificationCenter.defaultCenter removeObserver:self name:NSWindowWillCloseNotification object:nil];
	if(self.window)
		[NSNotificationCenter.defaultCenter addObserver:self selector:@selector(windowWillClose:) name:NSWindowWillCloseNotification object:self.window];
	self.visible = self.window ? YES : NO;
}

- (void)windowWillClose:(NSNotification*)aNotification
{
	self.visible = NO;
}

// =======================
// = Frame Load Delegate =
// =======================

- (void)webView:(WebView*)sender didStartProvisionalLoadForFrame:(WebFrame*)frame
{
	self.statusBar.busy = YES;
	[self setUpdatesProgress:!self.isRunningCommand];
}

- (void)webView:(WebView*)sender didClearWindowObject:(WebScriptObject*)windowScriptObject forFrame:(WebFrame*)frame
{
	if(self.disableJavaScriptAPI)
		return;

	NSString* scheme = self.webView.URL.scheme;
	if(self.isRunningCommand || [@[ @"tm-file", @"file" ] containsObject:scheme])
	{
		HOJSBridge* bridge = [HOJSBridge new];
		[bridge setDelegate:self.statusBar];
		[bridge setEnvironment:_environment];
		[windowScriptObject setValue:bridge forKey:@"TextMate"];
	}
}

- (void)webView:(WKWebView*)webView didFinishNavigation:(WKNavigation*)navigation
{
	self.runningCommand = NO;
	self.autoScrollHelper = nil;

	// The JavaScript bridge was installed here, through didClearWindowObject:, which
	// has no equivalent. WKWebView injects scripts through its configuration's user
	// content controller instead, at construction rather than per navigation.

	// This happens when we redirect to a PDF file
	if(self.window.firstResponder == self.window)
	{
		NSRect rect = webView.frame;
		for(NSView* view = [webView hitTest:NSMakePoint(NSMidX(rect), NSMidY(rect))]; view; view = view.superview)
		{
			if(view.acceptsFirstResponder)
			{
				[self.window makeFirstResponder:view];
				break;
			}
		}
	}

	// Scroll restoration across reloads is not carried over yet. The old code read
	// the document view's visible rect directly, which WKWebView does not expose
	// because the content lives in another process. Restoring it means asking the
	// page for window.scrollY and setting it back through JavaScript.

	[super webView:webView didFinishNavigation:navigation];
}

- (void)webView:(WKWebView*)webView didFailProvisionalNavigation:(WKNavigation*)navigation withError:(NSError*)error
{
	self.runningCommand = NO;
	self.autoScrollHelper = nil;
	[super webView:webView didFailProvisionalNavigation:navigation withError:error];
}

- (void)webView:(WKWebView*)webView didFailNavigation:(WKNavigation*)navigation withError:(NSError*)error
{
	self.runningCommand = NO;
	self.autoScrollHelper = nil;
	[super webView:webView didFailNavigation:navigation withError:error];
}

// =========================================
// = WebPolicyDelegate : Intercept txmt:// =
// =========================================

- (void)webView:(WebView*)sender decidePolicyForNavigationAction:(NSDictionary*)actionInformation request:(NSURLRequest*)request frame:(WebFrame*)frame decisionListener:(id <WebPolicyDecisionListener>)listener
{
	if([NSURLConnection canHandleRequest:request])
	{
		[listener use];
	}
	else
	{
		[listener ignore];
		NSURL* url = request.URL;
		if([[url scheme] isEqualToString:@"txmt"])
		{
			auto projectUUID = _environment.find("TM_PROJECT_UUID");
			if(projectUUID != _environment.end())
				url = [NSURL URLWithString:[[url absoluteString] stringByAppendingFormat:@"&project=%@", [NSString stringWithCxxString:projectUUID->second]]];
			[NSApp sendAction:@selector(handleTxMtURL:) to:nil from:url];
		}
		else
		{
			[NSWorkspace.sharedWorkspace openURL:url];
		}
	}
}

// ====================
// = Printing Support =
// ====================

- (IBAction)printDocument:(id)sender
{
	NSPrintOperation* printer = [NSPrintOperation printOperationWithView:self.webView];
	[[printer printPanel] setOptions:[[printer printPanel] options] | NSPrintPanelShowsPaperSize | NSPrintPanelShowsOrientation];

	NSPrintInfo* info = [printer printInfo];

	NSRect display = NSIntersectionRect(info.imageablePageBounds, (NSRect){ NSZeroPoint, info.paperSize });
	info.leftMargin   = NSMinX(display);
	info.rightMargin  = info.paperSize.width - NSMaxX(display);
	info.topMargin    = info.paperSize.height - NSMaxY(display);
	info.bottomMargin = NSMinY(display);

	[printer runOperationModalForWindow:self.window delegate:nil didRunSelector:NULL contextInfo:nil];
}
@end
