#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

// The Ruby the application fetches for itself when it ships without one. The catalog serves a
// signed index of runtimes at /ruby, each a signed archive, verified with the same key as the
// bundles. An installed runtime lives under the support directory as Ruby/<version>, and the
// newest one there is what bundle commands run on, through the environment.
@interface RubyRuntimeManager : NSObject
@property (class, readonly) RubyRuntimeManager* sharedInstance;

// The newest installed runtime's directory, or nil. Tells the environment about it as a side
// effect, which is why the application asks at launch.
@property (nonatomic, readonly, nullable) NSString* installedRuntimeDirectory;

// Fetches the index, downloads and verifies the newest runtime, installs it, and tells the
// environment. The handler gets the directory, or nil and the error.
- (void)installNewestRuntimeWithCompletionHandler:(void(^)(NSString* _Nullable directory, NSError* _Nullable error))handler;
@end

NS_ASSUME_NONNULL_END
