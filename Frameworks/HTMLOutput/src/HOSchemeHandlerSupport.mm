#import "HOSchemeHandlerSupport.h"
#import <OakSystem/process.h>
#import <bundles/bundles.h>
#import <ns/ns.h>

@implementation HOSchemeHandlerSupport
+ (NSArray<NSString*>*)bundleLocations
{
	NSMutableArray<NSString*>* res = [NSMutableArray array];
	for(auto const& location : bundles::locations())
	{
		if(location != NULL_STR)
			[res addObject:to_ns(location)];
	}
	return res;
}

+ (void)killProcessGroupInBackground:(pid_t)processGroup
{
	oak::kill_process_group_in_background(processGroup);
}
@end
