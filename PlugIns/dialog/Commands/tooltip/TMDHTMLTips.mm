//
//  TMDHTMLTips.mm
//
//  Created by Ciarán Walsh on 2007-08-19.
//

#import "TMDHTMLTips.h"

/*
"$DIALOG" tooltip --text '‘foobar’'
"$DIALOG" tooltip --html '<h1>‘foobar’</h1>'
*/

@interface TMDHTMLTip () <WKNavigationDelegate>
{
	WKWebView* webView;

	NSPoint anchorPoint;    // where the caller asked the tooltip to appear
	NSRect screenFrame;     // the visible frame of the screen that point falls on
	NSSize measuredContentSize;

	NSDate* didOpenAtDate; // ignore mouse moves for the next second
	NSPoint mousePositionWhenOpened;
}
- (void)setContent:(NSString*)content transparent:(BOOL)transparent;
- (void)runUntilUserActivity:(id)sender;
@end

@implementation TMDHTMLTip
// ==================
// = Setup/teardown =
// ==================
+ (void)showWithContent:(NSString*)content atLocation:(NSPoint)point transparent:(BOOL)transparent
{
	TMDHTMLTip* tip = [TMDHTMLTip new];
	[tip setFrameTopLeftPoint:point];
	[tip setContent:content transparent:transparent]; // The tooltip will show itself automatically when the HTML is loaded
}

- (id)init;
{
	if(self = [self initWithContentRect:NSMakeRect(0, 0, 1, 1) styleMask:NSWindowStyleMaskBorderless backing:NSBackingStoreBuffered defer:NO])
	{
		// Since we are relying on `setReleaseWhenClosed:`, we need to ensure that we are over-retained.
		CFBridgingRetain(self);
		[self setReleasedWhenClosed:YES];
		[self setAlphaValue:0.97];
		[self setOpaque:NO];
		[self setBackgroundColor:[NSColor colorWithDeviceRed:1.0 green:0.96 blue:0.76 alpha:1.0]];
		[self setBackgroundColor:[NSColor clearColor]];
		[self setHasShadow:YES];
		[self setLevel:NSStatusWindowLevel];
		[self setHidesOnDeactivate:YES];
		[self setIgnoresMouseEvents:YES];

		// There is nothing here to configure fonts with: setContent:transparent: writes the editor
		// font into the document's own style sheet instead. Nor is there anything to tune about
		// caching, which does not matter, since a single loadHTMLString: never consults the shared
		// cache.
		WKWebViewConfiguration* configuration = [WKWebViewConfiguration new];
		configuration.defaultWebpagePreferences.allowsContentJavaScript = YES;

		webView = [[WKWebView alloc] initWithFrame:NSZeroRect configuration:configuration];
		[webView setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
		[webView setNavigationDelegate:self];

		// WKWebView paints an opaque page background unless this is turned off, which is the same
		// lever the About window and the HTML output view already pull.
		[webView setValue:@NO forKey:@"drawsBackground"];

		[self setContentView:webView];
	}
	return self;
}

// ===========
// = Webview =
// ===========
- (void)setContent:(NSString*)content transparent:(BOOL)transparent
{
	// The font rules live in the style sheet because a WKWebView offers no way to set them.
	//
	// The body rule carries the editor's font family and size. The monospace rule sets only a size
	// and deliberately leaves the family alone, so <pre> content renders in WebKit's own fixed
	// font rather than the editor's. That distinction matters more than it looks: the --text form
	// of this command wraps everything it is given in <pre>.
	NSString* fullContent =	@"<html>"
				@"<head>"
				@"  <style type='text/css' media='screen'>"
				@"      body {"
				@"          background: %@;"
				@"          font-family: '%@';"
				@"          font-size: %dpx;"
				@"          margin: 0;"
				@"          padding: 2px;"
				@"          overflow: hidden;"
				@"          display: table-cell;"
				@"          max-width: 800px;"
				@"      }"
				@"      pre, code, kbd, samp, tt { font-family: monospace; font-size: %dpx; }"
				@"      pre { white-space: pre-wrap; }"
				@"  </style>"
				@"</head>"
				@"<body>%@</body>"
				@"</html>";

	NSString* fontName = [NSUserDefaults.standardUserDefaults stringForKey:@"fontName"];
	int fontSize = [NSUserDefaults.standardUserDefaults integerForKey:@"fontSize"] ?: 11;
	NSFont* font = fontName ? [NSFont fontWithName:fontName size:fontSize] : [NSFont userFixedPitchFontOfSize:fontSize];

	fullContent = [NSString stringWithFormat:fullContent, transparent ? @"transparent" : @"#F6EDC3", [font familyName], fontSize, fontSize, content];

	// The window is still at its one by one pixel starting size, so its top left corner is the
	// point the caller asked for. Remember that point, and the screen it falls on, before the web
	// view grows, because both are needed once the content has been measured.
	anchorPoint = NSMakePoint(NSMinX(self.frame), NSMaxY(self.frame));
	screenFrame = [[NSScreen mainScreen] visibleFrame];
	for(NSScreen* candidate in [NSScreen screens])
	{
		if(NSPointInRect(anchorPoint, [candidate frame]))
		{
			screenFrame = [candidate visibleFrame];
			break;
		}
	}

	// The web view is laid out at a large size and then sized down to fit, so that the body's
	// max-width decides where the text wraps rather than the starting window frame. Growing it
	// before the load, rather than after, keeps the measurement below from racing the resize.
	[self setContentSize:NSMakeSize(NSWidth(screenFrame) - NSWidth(screenFrame) / 3.0, NSHeight(screenFrame))];

	[webView loadHTMLString:fullContent baseURL:nil];
}

- (void)sizeToContent
{
	NSPoint pos = anchorPoint;

	[webView setFrameSize:measuredContentSize];

	NSRect frame      = [self frameRectForContentRect:[webView frame]];
	frame.size.width  = std::min(NSWidth(frame), NSWidth(screenFrame));
	frame.size.height = std::min(NSHeight(frame), NSHeight(screenFrame));
	[self setFrame:frame display:NO];

	pos.x = std::max(NSMinX(screenFrame), std::min(pos.x, NSMaxX(screenFrame)-NSWidth(frame)));
	pos.y = std::min(std::max(NSMinY(screenFrame)+NSHeight(frame), pos.y), NSMaxY(screenFrame));

	[self setFrameTopLeftPoint:pos];
}

- (void)delayedSizeAndShow:(id)sender
{
	[self sizeToContent];
	[self orderFront:self];
	[self runUntilUserActivity:self];
}

- (void)webView:(WKWebView*)sender didFinishNavigation:(WKNavigation*)navigation
{
	// WKWebView runs scripts in a separate process, so the content cannot be measured inline.
	// Nothing can be sized, positioned or shown until the completion handler arrives.
	[webView evaluateJavaScript:@"(function() { var rect = document.body.getBoundingClientRect(); return [rect.right, rect.bottom]; })()" completionHandler:^(id result, NSError* error){
		NSArray<NSNumber*>* rect = [result isKindOfClass:[NSArray class]] ? result : nil;
		if([rect count] != 2)
		{
			os_log_error(OS_LOG_DEFAULT, "Unable to measure tooltip content: %{public}@", error.localizedDescription);
			[self close]; // balances the over-retain taken in init
			return;
		}

		self->measuredContentSize = NSMakeSize(ceil([rect[0] doubleValue]), ceil([rect[1] doubleValue]));
		[self performSelector:@selector(delayedSizeAndShow:) withObject:self afterDelay:0];
	}];
}

// ==================
// = Event handling =
// ==================
- (BOOL)shouldCloseForMousePosition:(NSPoint)aPoint
{
	CGFloat ignorePeriod = [NSUserDefaults.standardUserDefaults floatForKey:@"OakToolTipMouseMoveIgnorePeriod"];
	if(-[didOpenAtDate timeIntervalSinceNow] < ignorePeriod)
		return NO;

	if(NSEqualPoints(mousePositionWhenOpened, NSZeroPoint))
	{
		mousePositionWhenOpened = aPoint;
		return NO;
	}

	NSPoint const& p = mousePositionWhenOpened;
	CGFloat deltaX = p.x - aPoint.x;
	CGFloat deltaY = p.y - aPoint.y;
	CGFloat dist = sqrt(deltaX * deltaX + deltaY * deltaY);

	CGFloat moveThreshold = [NSUserDefaults.standardUserDefaults floatForKey:@"OakToolTipMouseDistanceThreshold"];
	return dist > moveThreshold;
}

- (void)runUntilUserActivity:(id)sender
{
	[self setValue:[NSDate date] forKey:@"didOpenAtDate"];
	mousePositionWhenOpened = NSZeroPoint;

	NSWindow* keyWindow = [NSApp keyWindow];
	BOOL didAcceptMouseMovedEvents = [keyWindow acceptsMouseMovedEvents];
	[keyWindow setAcceptsMouseMovedEvents:YES];

	BOOL slowFadeOut = NO;
	while(NSEvent* event = [NSApp nextEventMatchingMask:NSEventMaskAny untilDate:[NSDate distantFuture] inMode:NSDefaultRunLoopMode dequeue:YES])
	{
		[NSApp sendEvent:event];

		if([event type] == NSEventTypeLeftMouseDown || [event type] == NSEventTypeRightMouseDown || [event type] == NSEventTypeOtherMouseDown || [event type] == NSEventTypeKeyDown || [event type] == NSEventTypeScrollWheel)
			break;

		if([event type] == NSEventTypeMouseMoved && [self shouldCloseForMousePosition:[NSEvent mouseLocation]])
		{
			slowFadeOut = YES;
			break;
		}

		if(keyWindow != [NSApp keyWindow] || ![NSApp isActive])
			break;
	}

	[keyWindow setAcceptsMouseMovedEvents:didAcceptMouseMovedEvents];


	[self fadeOutSlowly:slowFadeOut];
}

// =============
// = Animation =
// =============
- (void)fadeOutSlowly:(BOOL)slowly
{
	[NSAnimationContext beginGrouping];

	[NSAnimationContext currentContext].duration = slowly ? 0.5 : 0.25;
	[NSAnimationContext currentContext].completionHandler = ^{
		[self orderOut:self];
	};

	[self.animator setAlphaValue:0];

	[NSAnimationContext endGrouping];
}
@end
