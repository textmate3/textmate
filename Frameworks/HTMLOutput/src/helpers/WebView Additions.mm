#import <OakAppKit/OakPasteboard.h>
#import <OakFoundation/OakFoundation.h>
#import <OakFoundation/OakFindProtocol.h>
#import <OakFoundation/NSString Additions.h>
#import <document/OakDocument.h>
#import <document/OakDocumentController.h>
#import <ns/ns.h>
#import <WebKit/WebKit.h>

// Find and selection for HTML output windows.
//
// The page renders in another process, so everything here is asynchronous: the selection comes back
// through JavaScript, and searching goes through findString:withConfiguration:. The callers are all
// menu actions and the find server, none of which need an answer inline.
@interface WKWebView (OakFindNextPrevious)
- (void)performFindOperation:(id <OakFindServerProtocol>)aFindServer;

- (IBAction)findNext:(id)sender;
- (IBAction)findPrevious:(id)sender;

- (IBAction)copySelectionToFindPboard:(id)sender;
- (IBAction)copySelectionToReplacePboard:(id)sender;
@end

@implementation WKWebView (OakFindNextPrevious)
- (void)getSelection:(void(^)(NSString* selection))handler
{
	[self evaluateJavaScript:@"window.getSelection().toString()" completionHandler:^(id result, NSError* error){
		NSString* str = [result isKindOfClass:NSString.class] ? result : nil;
		handler(OakIsEmptyString(str) ? nil : str);
	}];
}

- (void)copySelectionToPasteboard:(OakPasteboard*)pasteboard
{
	[self getSelection:^(NSString* selection){
		if(selection)
				[pasteboard addEntryWithString:selection];
		else	NSBeep();
	}];
}

- (IBAction)copySelectionToFindPboard:(id)sender
{
	[self copySelectionToPasteboard:OakPasteboard.findPasteboard];
}

- (IBAction)copySelectionToReplacePboard:(id)sender
{
	[self copySelectionToPasteboard:OakPasteboard.replacePasteboard];
}

- (WKFindConfiguration*)findConfigurationBackwards:(BOOL)backwards caseSensitive:(BOOL)caseSensitive wraps:(BOOL)wraps
{
	WKFindConfiguration* configuration = [WKFindConfiguration new];
	configuration.backwards     = backwards;
	configuration.caseSensitive = caseSensitive;
	configuration.wraps         = wraps;
	return configuration;
}

- (void)performFindOperation:(id <OakFindServerProtocol>)aFindServer
{
	switch(aFindServer.findOperation)
	{
		case kFindOperationFind:
		case kFindOperationFindInSelection:
		{
			BOOL backwards  = aFindServer.findOptions & find::backwards;
			BOOL ignoreCase = aFindServer.findOptions & find::ignore_case;
			BOOL wrapAround = aFindServer.findOptions & find::wrap_around;

			NSString* findString = aFindServer.findString;
			[self findString:findString withConfiguration:[self findConfigurationBackwards:backwards caseSensitive:!ignoreCase wraps:wrapAround] completionHandler:^(WKFindResult* result){
				if(!result.matchFound)
					return [aFindServer didFind:0 occurrencesOf:findString atPosition:text::pos_t::undefined wrapped:NO];

				// Report what was actually matched, which needs one more hop to the page.
				[self getSelection:^(NSString* selection){
					[aFindServer didFind:1 occurrencesOf:(selection ?: findString) atPosition:text::pos_t::undefined wrapped:NO];
				}];
			}];
		}
		break;
	}
}

- (void)findEntryBackwards:(BOOL)backwards
{
	OakPasteboardEntry* entry = [OakPasteboard.findPasteboard current];
	if(OakIsEmptyString(entry.string))
		return;

	BOOL caseSensitive = ![NSUserDefaults.standardUserDefaults boolForKey:kUserDefaultsFindIgnoreCase];
	BOOL wraps         = [NSUserDefaults.standardUserDefaults boolForKey:kUserDefaultsFindWrapAround];
	[self findString:entry.string withConfiguration:[self findConfigurationBackwards:backwards caseSensitive:caseSensitive wraps:wraps] completionHandler:^(WKFindResult* result){ }];
}

- (IBAction)findNext:(id)sender
{
	[self findEntryBackwards:NO];
}

- (IBAction)findPrevious:(id)sender
{
	[self findEntryBackwards:YES];
}

- (void)viewSource:(id)sender
{
	// Ask the page for its own markup. It arrives already decoded, so nothing here has to reason
	// about encodings.
	[self evaluateJavaScript:@"document.documentElement.outerHTML" completionHandler:^(id result, NSError* error){
		NSString* str = [result isKindOfClass:NSString.class] ? result : nil;
		if(!str)
		{
			NSAlert* alert        = [[NSAlert alloc] init];
			alert.messageText     = @"Cannot Show Source";
			alert.informativeText = error.localizedDescription ?: @"The page did not return its markup.";
			[alert addButtonWithTitle:@"Continue"];
			[alert runModal];
			return;
		}

		NSString* name = OakNotEmptyString(self.title) ? self.title : nil;
		OakDocument* doc = [OakDocument documentWithString:str fileType:@"text.html.basic" customName:name];
		[OakDocumentController.sharedInstance showDocument:doc inProject:nil bringToFront:YES];
	}];
}
@end
