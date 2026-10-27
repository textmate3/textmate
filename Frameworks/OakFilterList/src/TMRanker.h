// The ranker that scores a candidate against what the person typed, in plain
// Objective-C so that a chooser written in Swift can ask it. The scoring is
// C++ in text/ranker.h, with its own tests, and stays there.
#ifndef TM_RANKER_H_4C8D2A61
#define TM_RANKER_H_4C8D2A61

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

// A candidate that matched: how well, and where. The ranges are byte offsets
// into the candidate's UTF-8, which is what the ranker works in.
@interface TMRankedMatch : NSObject
@property (nonatomic, readonly) double score;
@property (nonatomic, readonly) NSArray<NSValue*>* byteRanges;
@end

@interface TMRanker : NSObject
// The filter as the ranker wants it: lowercased, with the spaces removed.
+ (NSString*)normalizeFilter:(NSString*)filter;
// The match, or nil when the candidate does not contain the filter.
+ (nullable TMRankedMatch*)rankFilter:(NSString*)filter candidate:(NSString*)candidate;
@end

NS_ASSUME_NONNULL_END

#endif /* end of include guard: TM_RANKER_H_4C8D2A61 */
