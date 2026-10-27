#import "HOFindSupport.h"
#import <OakAppKit/OakPasteboard.h>
#import <OakFoundation/OakFindProtocol.h>
#import <document/OakDocument.h>
#import <document/OakDocumentController.h>

@interface HOFindRequest ()
@property (nonatomic) id <OakFindServerProtocol> findServer;
@end

@implementation HOFindRequest
+ (instancetype)requestForFindServer:(id)findServer
{
	if(![findServer conformsToProtocol:@protocol(OakFindServerProtocol)])
		return nil;

	id <OakFindServerProtocol> server = findServer;
	switch(server.findOperation)
	{
		case kFindOperationFind:
		case kFindOperationFindInSelection:
		{
			HOFindRequest* res = [[HOFindRequest alloc] init];
			res.findServer = server;
			return res;
		}
		default:
			return nil;
	}
}

- (NSString*)findString { return self.findServer.findString ?: @""; }
- (BOOL)backwards       { return (self.findServer.findOptions & find::backwards) != 0; }
- (BOOL)ignoresCase     { return (self.findServer.findOptions & find::ignore_case) != 0; }
- (BOOL)wrapsAround     { return (self.findServer.findOptions & find::wrap_around) != 0; }

- (void)reportFound:(BOOL)found text:(NSString*)text
{
	[self.findServer didFind:(found ? 1 : 0) occurrencesOf:text atPosition:text::pos_t::undefined wrapped:NO];
}
@end

@implementation HOFindSupport
+ (NSString*)currentFindString
{
	NSString* string = [OakPasteboard.findPasteboard current].string;
	return string.length == 0 ? nil : string;
}

+ (BOOL)findIgnoresCase
{
	return [NSUserDefaults.standardUserDefaults boolForKey:kUserDefaultsFindIgnoreCase];
}

+ (BOOL)findWrapsAround
{
	return [NSUserDefaults.standardUserDefaults boolForKey:kUserDefaultsFindWrapAround];
}

+ (void)addFindPasteboardEntry:(NSString*)string
{
	[OakPasteboard.findPasteboard addEntryWithString:string];
}

+ (void)addReplacePasteboardEntry:(NSString*)string
{
	[OakPasteboard.replacePasteboard addEntryWithString:string];
}

+ (void)showHTMLSource:(NSString*)html named:(NSString*)name
{
	OakDocument* document = [OakDocument documentWithString:html fileType:@"text.html.basic" customName:name];
	[OakDocumentController.sharedInstance showDocument:document inProject:nil bringToFront:YES];
}
@end
