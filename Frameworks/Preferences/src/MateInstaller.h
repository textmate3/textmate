#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

// The mate shell command: where it is installed, if it is, and the install and uninstall
// themselves, which go through the privileged helper when the destination needs it. Plain
// Objective-C, so the Terminal pane in Swift can drive it and the application can ask for the
// launch time refresh.
@interface MateInstaller : NSObject

// Where mate is installed, tilde expanded, or nil when it is not installed or has gone missing,
// in which case the record of it is forgotten too.
@property (class, readonly, nullable) NSString* installedPath;

@property (class, readonly) BOOL bundledMateExists;

// Copies the bundled mate to the path, replacing whatever is there, and remembers the path and
// the version. NO when it could not.
+ (BOOL)installAtPath:(NSString*)path;

// Removes the installed mate and forgets it. NO when it could not.
+ (BOOL)uninstall;

// At launch: an installed mate older than the bundled one is replaced, after asking when the
// replacement needs the privileged helper.
+ (void)updateIfRequired;
@end

NS_ASSUME_NONNULL_END
