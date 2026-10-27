// What the scheme handler, in Swift, needs from C++: the asset policy, which
// decides what a page may read from disk, the bundle locations that policy
// starts from, and the kill of a stopped command's process group. Plain
// Objective-C, so the Swift side can see it; the C++ stays behind it.
#ifndef HO_SCHEME_HANDLER_SUPPORT_H_2B8F61C4
#define HO_SCHEME_HANDLER_SUPPORT_H_2B8F61C4

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface HOSchemeHandlerSupport : NSObject
// The roots every page may read from: each bundle location, and the target of
// every link placed in its Bundles directory.
+ (NSArray<NSString*>*)bundleAssetRoots;
// Whether the path sits under one of the roots, by normalized path component,
// so a .. cannot climb out and /a/b does not admit /a/bc/x.
+ (BOOL)isPath:(NSString*)path allowedUnderAnyOf:(NSArray<NSString*>*)roots;
+ (void)killProcessGroupInBackground:(pid_t)processGroup NS_SWIFT_NAME(killProcessGroup(inBackground:));
@end

NS_ASSUME_NONNULL_END

#endif /* end of include guard: HO_SCHEME_HANDLER_SUPPORT_H_2B8F61C4 */
