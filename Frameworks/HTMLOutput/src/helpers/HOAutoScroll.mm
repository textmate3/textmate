#import "HOAutoScroll.h"
#import <oak/debug.h>

// Keep a streaming command's output pinned to the bottom while the user has not
// scrolled away from it.
//
// The previous implementation observed NSViewFrameDidChangeNotification on the
// web view's document view and called scrollRectToVisible: when the content grew.
// WKWebView renders in another process and exposes no document view, so there is
// nothing to observe from here. The same rule is expressed inside the page: watch
// the document for mutations, and if the viewport was already at the bottom before
// the mutation, put it back there afterwards.
static NSString* const kAutoScrollScript = @""
	"(function() {"
	"  if (window.__tmAutoScroll) return;"
	"  var threshold = 2;"
	"  var atBottom = function() {"
	"    var doc = document.documentElement;"
	"    return (window.innerHeight + window.scrollY) >= (doc.scrollHeight - threshold);"
	"  };"
	"  var wasAtBottom = true;"
	"  var observer = new MutationObserver(function() {"
	"    if (wasAtBottom) window.scrollTo(0, document.documentElement.scrollHeight);"
	"    wasAtBottom = atBottom();"
	"  });"
	"  window.addEventListener('scroll', function() { wasAtBottom = atBottom(); });"
	"  observer.observe(document.documentElement, { childList: true, subtree: true, characterData: true });"
	"  window.__tmAutoScroll = observer;"
	"})();";

@implementation HOAutoScroll
- (void)setWebView:(WKWebView*)aWebView
{
	if(aWebView == _webView)
		return;

	if(_webView = aWebView)
		[_webView evaluateJavaScript:kAutoScrollScript completionHandler:nil];
}
@end
