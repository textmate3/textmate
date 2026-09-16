#import <oak/print_system_error.h>
#import <WebKit/WebKit.h>

@class HOStatusBar;   // Swift, in HTMLOutputStatusBar.swift

@interface HOBrowserView : NSView <WKNavigationDelegate>
@property (nonatomic, readonly) WKWebView* webView;
@property (nonatomic, readonly) BOOL needsNewWebView;
@property (nonatomic, readonly) HOStatusBar* statusBar;
- (void)setUpdatesProgress:(BOOL)flag;
@end
