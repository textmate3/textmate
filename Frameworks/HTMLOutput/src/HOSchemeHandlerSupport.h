// What the scheme handler, in Swift, needs from C++: the bundle locations its
// asset policy starts from, and the kill of a stopped command's process group.
// Plain Objective-C, so the Swift side can see it; the C++ stays behind it.
#ifndef HO_SCHEME_HANDLER_SUPPORT_H_2B8F61C4
#define HO_SCHEME_HANDLER_SUPPORT_H_2B8F61C4

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface HOSchemeHandlerSupport : NSObject
// Every directory bundles are loaded from.
+ (NSArray<NSString*>*)bundleLocations;
+ (void)killProcessGroupInBackground:(pid_t)processGroup NS_SWIFT_NAME(killProcessGroup(inBackground:));
@end

NS_ASSUME_NONNULL_END

#endif /* end of include guard: HO_SCHEME_HANDLER_SUPPORT_H_2B8F61C4 */
