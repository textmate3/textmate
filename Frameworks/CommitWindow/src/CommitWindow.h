static NSString* const kOakCommitWindowArguments            = @"arguments";
static NSString* const kOakCommitWindowEnvironment          = @"environment";
static NSString* const kOakCommitWindowStandardOutput       = @"stdout";
static NSString* const kOakCommitWindowStandardError        = @"stderr";
static NSString* const kOakCommitWindowReturnCode           = @"returnCode";
static NSString* const kOakCommitWindowContinue             = @"continue";

// The application listens on this path and CommitWindowTool connects to it. Both derive it from the
// editor's process id, which the tool inherits as TM_PID, so a tool always reaches the editor that
// launched it rather than whichever one happens to be running.
//
// It lives under TMPDIR because that is per-user and private, unlike /tmp. Keep it short: sockaddr_un
// allows 104 bytes for the whole path, and a deeper directory would silently fail to bind.
static inline NSString* OakCommitWindowSocketPath (pid_t pid)
{
	NSString* directory = NSProcessInfo.processInfo.environment[@"TMPDIR"] ?: @"/tmp";
	return [[directory stringByAppendingPathComponent:[NSString stringWithFormat:@"textmate-commit-%d.sock", pid]] stringByStandardizingPath];
}

@protocol OakCommitWindowServerProtocol <NSObject>
- (void)connectFromClientWithOptions:(NSDictionary*)someOptions;
@end

@interface OakCommitWindowServer : NSObject <OakCommitWindowServerProtocol>
@property (class, readonly) OakCommitWindowServer* sharedInstance;
@end
