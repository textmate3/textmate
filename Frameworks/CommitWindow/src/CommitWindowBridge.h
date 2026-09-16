// What the Swift side of the commit window needs from C++, as plain
// Objective-C. Everything here wraps something in `io`, `path` or
// `format_string`, none of whose headers the Swift compiler can read.

NS_ASSUME_NONNULL_BEGIN

@interface CommitWindowBridge : NSObject
// Runs `command` through `/bin/sh` in the project directory, with the
// environment the tool was invoked with. Answers what it wrote on standard
// output, or nil when it could not be run.
+ (nullable NSString*)runShellCommand:(NSString*)command environment:(NSDictionary<NSString*, NSString*>*)environment;

// The first argument of a command is a tool name, which may or may not be a
// path. Answers it resolved against the environment's own PATH rather than
// this process's, since the tool runs in the project's world and not ours.
+ (NSString*)absolutePathForTool:(NSString*)tool environment:(NSDictionary<NSString*, NSString*>*)environment;

// Quoting for a shell command line, which is what `path::escape` does.
+ (NSString*)escapedPath:(NSString*)path;

// The name a person would recognize the file by, which is not always its last
// path component.
+ (NSString*)displayNameForPath:(NSString*)path;

// Expands `${TM_DISPLAYNAME}` and the rest of the value mini language in an
// action command's name, so a menu item can read "Revert ${TM_DISPLAYNAME}".
+ (NSString*)expandedString:(NSString*)string withVariables:(NSDictionary<NSString*, NSString*>*)variables;

// A fresh identifier for the diffs this window opens, so they land in a window
// of their own rather than in the project being committed.
+ (NSString*)newProjectIdentifier;
@end

// The socket the waiting tool is blocked reading. The window answers through
// it exactly once, and closing it is what lets the tool continue, so it has to
// happen even when the write failed.
@interface CommitWindowReply : NSObject
- (instancetype)initWithFileDescriptor:(int)fileDescriptor;
@property (nonatomic, readonly) BOOL isOpen;
- (void)sendStandardOutput:(NSString*)output shouldContinue:(BOOL)shouldContinue;
- (void)sendCancelled;
@end

NS_ASSUME_NONNULL_END
