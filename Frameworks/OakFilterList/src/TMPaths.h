// Paths the choosers need from C++: where the application keeps its own
// files, and two path operations whose rules live in io/path.h. Plain
// Objective-C so that a chooser written in Swift can ask.
#ifndef TM_PATHS_H_6E2B9D04
#define TM_PATHS_H_6E2B9D04

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface TMPaths : NSObject
// A path under the application's folder in Application Support.
+ (NSString*)supportPath:(NSString*)relativePath;
// The path as seen from the base: "a/b" for "/base/a/b", ".." steps when it
// sits beside the base, and the path itself when there is no base.
+ (NSString*)relativePath:(NSString*)path toBase:(nullable NSString*)base;
// The directory the path is in, with the root its own parent.
+ (NSString*)parentOfPath:(NSString*)path;
@end

NS_ASSUME_NONNULL_END

#endif /* end of include guard: TM_PATHS_H_6E2B9D04 */
