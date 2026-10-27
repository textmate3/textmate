#import "HODocumentSupport.h"
#import <document/OakDocument.h>
#import <document/OakDocumentController.h>
#import <ns/ns.h>

@implementation HODocumentSupport
+ (void)openFile:(NSString*)path withOptions:(id)options
{
	text::range_t range = text::range_t::undefined;
	if([options isKindOfClass:NSNumber.class])
		range = text::pos_t([options intValue]-1, 0);
	else if([options isKindOfClass:NSString.class])
		range = to_s(options);

	if(OakDocument* document = [OakDocumentController.sharedInstance documentWithPath:path])
		[OakDocumentController.sharedInstance showDocument:document andSelect:range inProject:nil bringToFront:YES];
}
@end
