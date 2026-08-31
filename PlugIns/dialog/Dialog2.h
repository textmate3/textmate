// The plug-in listens on this path and tm_dialog2 connects to it. Both derive it from the editor's
// process id, so a tool always reaches the editor that launched it rather than whichever one happens
// to be running.
//
// It lives under TMPDIR because that is per-user and private, unlike /tmp. Keep it short: sockaddr_un
// allows 104 bytes for the whole path, and a deeper directory would silently fail to bind.
static inline NSString* DialogSocketPath (pid_t pid)
{
	NSString* directory = NSProcessInfo.processInfo.environment[@"TMPDIR"] ?: @"/tmp";
	return [[directory stringByAppendingPathComponent:[NSString stringWithFormat:@"textmate-dialog-%d.sock", pid]] stringByStandardizingPath];
}

// Written back to the tool once a request has been accepted. The tool blocks opening its FIFOs
// straight afterwards, and without an answer here a plug-in that failed to read the request would
// leave it blocked forever rather than reporting anything.
enum { kDialogRequestAccepted = 'K', kDialogRequestRejected = 'X' };

@protocol DialogServerProtocol
- (void)connectFromClientWithOptions:(id)anArgument;
@end
