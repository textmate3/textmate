// Where the application keeps its own files, in plain Objective-C so that a
// chooser written in Swift can ask. The paths are C++ in OakSystem's
// application.h and stay there.
#ifndef TM_APPLICATION_PATHS_H_6E2B9D04
#define TM_APPLICATION_PATHS_H_6E2B9D04

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface TMApplicationPaths : NSObject
// A path under the application's folder in Application Support.
+ (NSString*)supportPath:(NSString*)relativePath;
@end

NS_ASSUME_NONNULL_END

#endif /* end of include guard: TM_APPLICATION_PATHS_H_6E2B9D04 */
