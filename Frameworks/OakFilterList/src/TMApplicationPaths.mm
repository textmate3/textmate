#import "TMApplicationPaths.h"
#import <OakSystem/application.h>
#import <ns/ns.h>

@implementation TMApplicationPaths
+ (NSString*)supportPath:(NSString*)relativePath
{
	return to_ns(oak::application_t::support(to_s(relativePath)));
}
@end
