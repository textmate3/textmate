#import "HOSchemeHandlerSupport.h"
#import "helpers/asset_policy.h"
#import <OakSystem/process.h>
#import <bundles/bundles.h>
#import <ns/ns.h>

@implementation HOSchemeHandlerSupport
+ (NSArray<NSString*>*)bundleAssetRoots
{
	NSMutableArray<NSString*>* res = [NSMutableArray array];
	for(auto const& root : html_output::asset_roots(bundles::locations()))
		[res addObject:to_ns(root)];
	return res;
}

+ (BOOL)isPath:(NSString*)path allowedUnderAnyOf:(NSArray<NSString*>*)roots
{
	std::vector<std::string> cxxRoots;
	for(NSString* root in roots)
		cxxRoots.push_back(to_s(root));
	return html_output::is_asset_allowed(to_s(path), cxxRoots);
}

+ (void)killProcessGroupInBackground:(pid_t)processGroup
{
	oak::kill_process_group_in_background(processGroup);
}
@end
