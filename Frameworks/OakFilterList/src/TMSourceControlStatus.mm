#import "TMSourceControlStatus.h"
#import <scm/scm.h>
#import <ns/ns.h>

@interface TMSourceControlStatus ()
{
	scm::info_ptr _info;
}
@end

@implementation TMSourceControlStatus
+ (instancetype)statusForPath:(NSString*)path
{
	scm::info_ptr info = scm::info(to_s(path));
	if(!info)
		return nil;

	TMSourceControlStatus* res = [[TMSourceControlStatus alloc] init];
	res->_info = info;

	__weak TMSourceControlStatus* weakSelf = res;
	info->push_callback(^(scm::info_t const&){
		if(TMSourceControlStatus* status = weakSelf)
		{
			if(status.updateHandler)
				status.updateHandler();
		}
	});
	return res;
}

- (NSArray<NSString*>*)uncommittedPaths
{
	NSMutableArray<NSString*>* res = [NSMutableArray array];
	for(auto const& pair : _info->status())
	{
		if(pair.second & (scm::status::modified|scm::status::added|scm::status::deleted|scm::status::conflicted))
			[res addObject:to_ns(pair.first)];
	}
	return res;
}
@end
