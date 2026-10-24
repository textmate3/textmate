#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

// Posted by the Runtimes pane to ask the application to resolve a runtime again, after a bundle was
// installed or the pinned version asked for, with the language in userInfo under "language" as
// "Ruby" or "Python". The application answers with the second once the environment is remade, so
// the pane can read what settled.
extern NSString* const TMRuntimeActivationRequestedNotification;
extern NSString* const TMRuntimeDidActivateNotification;

// Plain Objective-C over the compiled runtime facts for the Runtimes pane: what the application
// pins, what it settled on at launch, which bundle carries each runtime and where that bundle is
// when installed. The headers behind these carry C++ and cannot be seen from Swift.
@interface RuntimeInfo : NSObject
@property (class, readonly) NSString* rubyPinnedVersion;
@property (class, readonly) NSString* pythonPinnedVersion;

// The Ruby directory and the Python interpreter bundle commands run on, nil until one has settled.
@property (class, readonly, nullable) NSString* rubyInUse;
@property (class, readonly, nullable) NSString* pythonInUse;

@property (class, readonly) NSUUID* rubyBundleIdentifier;
@property (class, readonly) NSUUID* pythonBundleIdentifier;

// The installed bundle's Support directory, where its manager and resolver are, nil when it is not installed.
@property (class, readonly, nullable) NSString* rubyBundleSupportPath;
@property (class, readonly, nullable) NSString* pythonBundleSupportPath;

+ (void)requestActivationForLanguage:(NSString*)language;
@end

NS_ASSUME_NONNULL_END
