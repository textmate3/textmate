#import "TMGlob.h"
#import <regexp/glob.h>
#import <ns/ns.h>
#import <optional>

@interface TMGlob ()
{
	// Optional because the glob has no empty form and is built from the pattern.
	std::optional<path::glob_t> _glob;
}
@end

@implementation TMGlob
- (instancetype)initWithPattern:(NSString*)pattern
{
	if(self = [super init])
		_glob.emplace(to_s(pattern), false, false);
	return self;
}

- (BOOL)matches:(NSString*)path
{
	return _glob->does_match(to_s(path));
}
@end
