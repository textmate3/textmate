#import "TMPaths.h"
#import <OakSystem/application.h>
#import <io/path.h>
#import <ns/ns.h>

@implementation TMPaths
+ (NSString*)supportPath:(NSString*)relativePath
{
	return to_ns(oak::application_t::support(to_s(relativePath)));
}

+ (NSString*)relativePath:(NSString*)path toBase:(NSString*)base
{
	return to_ns(path::relative_to(to_s(path), base ? to_s(base) : NULL_STR));
}

+ (NSString*)parentOfPath:(NSString*)path
{
	return to_ns(path::parent(to_s(path)));
}
@end
