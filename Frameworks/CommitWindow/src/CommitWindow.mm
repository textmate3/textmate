#import "CommitWindow.h"
#import "CommitWindowBridge.h"
#import "CommitWindow-Swift.h"
#import <io/io.h>
#import <ns/ns.h>

// The window itself is Swift, in CommitWindowController. What is left here is
// the part that cannot be: a unix socket listener, which deals in file
// descriptors and a C++ callback registry.

@protocol OakProjectIdentifier
- (NSString*)identifier;
@end

@interface OakCommitWindowServer ()
{
	socket_callback_ptr _listener;
}
@end

@implementation OakCommitWindowServer
+ (instancetype)sharedInstance
{
	static OakCommitWindowServer* sharedInstance = [self new];
	return sharedInstance;
}

// Reads a request until the tool half-closes its end, then hands the options to the server. The
// connection stays open afterwards: it is the return path the tool is blocked reading.
static bool commit_window_connection_handler (socket_t const& socket)
{
	static std::map<int, NSMutableData*> requests;

	char buf[4096];
	ssize_t len = read(socket, buf, sizeof(buf));
	if(len == -1)
	{
		if(errno == EINTR || errno == EAGAIN)
			return true;
		os_log_error(OS_LOG_DEFAULT, "Failed reading commit window request: %{public}s", strerror(errno));
		requests.erase(socket);
		return false;
	}

	if(len > 0)
	{
		NSMutableData* data = requests[socket] ?: [NSMutableData data];
		[data appendBytes:buf length:len];
		requests[socket] = data;
		return true;
	}

	// End of stream: the request is complete.
	NSData* data = requests[socket] ?: [NSData data];
	requests.erase(socket);

	NSError* error;
	NSDictionary* options = [NSPropertyListSerialization propertyListWithData:data options:NSPropertyListImmutable format:nullptr error:&error];
	if([options isKindOfClass:[NSDictionary class]])
			[OakCommitWindowServer.sharedInstance connectFromClientWithOptions:options replySocket:socket];
	else	os_log_error(OS_LOG_DEFAULT, "Malformed commit window request: %{public}@", error.localizedDescription);

	return false; // Stop watching for reads, the window owns the socket now.
}

- (id)init
{
	if(self = [super init])
	{
		NSString* socketPath = OakCommitWindowSocketPath(getpid());

		if(unlink(socketPath.fileSystemRepresentation) == -1 && errno != ENOENT)
		{
			os_log_error(OS_LOG_DEFAULT, "Failed to remove socket left from an old instance ‘%{public}@’: %{public}s", socketPath, strerror(errno));
			return self;
		}

		socket_t fd(socket(AF_UNIX, SOCK_STREAM, 0));
		if(!fd)
		{
			os_log_error(OS_LOG_DEFAULT, "Failed to create commit window socket: %{public}s", strerror(errno));
			return self;
		}

		struct sockaddr_un addr = { 0, AF_UNIX };
		if(strlcpy(addr.sun_path, socketPath.fileSystemRepresentation, sizeof(addr.sun_path)) >= sizeof(addr.sun_path))
		{
			os_log_error(OS_LOG_DEFAULT, "Commit window socket path is too long: %{public}@", socketPath);
			return self;
		}
		addr.sun_len = SUN_LEN(&addr);

		if(bind(fd, (sockaddr*)&addr, sizeof(addr)) == -1)
			os_log_error(OS_LOG_DEFAULT, "Failed to bind commit window socket ‘%{public}@’: %{public}s", socketPath, strerror(errno));
		else if(listen(fd, SOMAXCONN) == -1)
			os_log_error(OS_LOG_DEFAULT, "Failed to listen on commit window socket: %{public}s", strerror(errno));
		else
			_listener = std::make_shared<socket_callback_t>([](socket_t const& serverFd){
				socket_t clientFd(accept(serverFd, nullptr, nullptr));
				if(clientFd)
					new socket_callback_t(&commit_window_connection_handler, clientFd);
				return true;
			}, fd);
	}
	return self;
}

- (void)connectFromClientWithOptions:(NSDictionary*)someOptions
{
	[self connectFromClientWithOptions:someOptions replySocket:socket_t()];
}

- (void)connectFromClientWithOptions:(NSDictionary*)someOptions replySocket:(socket_t const&)replySocket
{
	NSWindow* projectWindow = [NSApp mainWindow];
	if(NSString* identifier = [someOptions valueForKeyPath:@"environment.TM_PROJECT_UUID"])
	{
		for(NSWindow* window in [NSApp orderedWindows])
		{
			if([window.delegate respondsToSelector:@selector(identifier)])
			{
				if([identifier isEqualToString:[id <OakProjectIdentifier>(window.delegate) identifier]])
				{
					projectWindow = window;
					break;
				}
			}
		}
	}

	// The reply takes the descriptor over, so the socket_t here gives up
	// ownership rather than closing it when this scope ends.
	int fileDescriptor = replySocket ? dup(replySocket) : -1;
	CommitWindowReply* reply = [[CommitWindowReply alloc] initWithFileDescriptor:fileDescriptor];

	OakCommitWindowController* controller = [[OakCommitWindowController alloc] initWithArguments:someOptions[kOakCommitWindowArguments] environment:someOptions[kOakCommitWindowEnvironment] reply:reply];
	[controller beginSheetModalForWindow:projectWindow];
}
@end
