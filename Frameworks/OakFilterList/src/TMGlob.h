// A glob the way the file chooser reads one typed into its search field:
// hidden files left out and case ignored. The matching is C++ in
// regexp/glob.h and stays there.
#ifndef TM_GLOB_H_5B7E9A23
#define TM_GLOB_H_5B7E9A23

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

// Sendable: the pattern is fixed at creation and matching reads it alone, so
// the ranking can use one glob from every thread at once.
NS_SWIFT_SENDABLE
@interface TMGlob : NSObject
- (instancetype)initWithPattern:(NSString*)pattern;
- (BOOL)matches:(NSString*)path;
@end

NS_ASSUME_NONNULL_END

#endif /* end of include guard: TM_GLOB_H_5B7E9A23 */
