#import "TMRanker.h"
#import <text/ranker.h>
#import <ns/ns.h>

@interface TMRankedMatch ()
@property (nonatomic) double score;
@property (nonatomic) NSArray<NSValue*>* byteRanges;
@end

@implementation TMRankedMatch
@end

@implementation TMRanker
+ (NSString*)normalizeFilter:(NSString*)filter
{
	return to_ns(oak::normalize_filter(to_s(filter)));
}

+ (TMRankedMatch*)rankFilter:(NSString*)filter candidate:(NSString*)candidate
{
	std::vector< std::pair<size_t, size_t> > ranges;
	double score = oak::rank(to_s(filter), to_s(candidate), &ranges);
	if(score == 0)
		return nil;

	NSMutableArray<NSValue*>* byteRanges = [NSMutableArray array];
	for(auto const& range : ranges)
		[byteRanges addObject:[NSValue valueWithRange:NSMakeRange(range.first, range.second - range.first)]];

	TMRankedMatch* res = [[TMRankedMatch alloc] init];
	res.score      = score;
	res.byteRanges = byteRanges;
	return res;
}
@end
