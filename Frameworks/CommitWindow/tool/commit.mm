#include <CommitWindow/CommitWindow.h>
#include <oak/oak.h>
#include <sys/socket.h>
#include <sys/un.h>

static double const AppVersion = 1.2;

// Reads until the peer closes its end. The reply is small and the editor sends it in one go, but a
// short read is always legal, so this cannot assume a single read suffices.
static NSData* ReadToEndOfStream (int fd)
{
	NSMutableData* res = [NSMutableData data];
	char buf[4096];
	while(ssize_t len = read(fd, buf, sizeof(buf)))
	{
		if(len == -1)
		{
			if(errno == EINTR)
				continue;
			perror("commit: read");
			return nil;
		}
		[res appendBytes:buf length:len];
	}
	return res;
}

static bool WriteAll (int fd, NSData* data)
{
	char const* bytes = (char const*)data.bytes;
	size_t left       = data.length;
	while(left)
	{
		ssize_t len = write(fd, bytes, left);
		if(len == -1)
		{
			if(errno == EINTR)
				continue;
			perror("commit: write");
			return false;
		}
		bytes += len;
		left  -= len;
	}
	return true;
}

int main (int argc, char* argv[])
{
	if(argc == 2 && (strcmp(argv[1], "-v") == 0 || strcmp(argv[1], "--version") == 0))
	{
		fprintf(stderr, "%1$s %2$.1f (" __DATE__ ")\n", getprogname(), AppVersion);
		return EX_OK;
	}

	@autoreleasepool {
		NSString* socketPath = OakCommitWindowSocketPath((pid_t)NSProcessInfo.processInfo.environment[@"TM_PID"].intValue);

		int fd = socket(AF_UNIX, SOCK_STREAM, 0);
		if(fd == -1)
		{
			perror("commit: socket");
			return EX_OSERR;
		}

		struct sockaddr_un addr = { 0, AF_UNIX };
		if(strlcpy(addr.sun_path, socketPath.fileSystemRepresentation, sizeof(addr.sun_path)) >= sizeof(addr.sun_path))
		{
			fprintf(stderr, "%s: socket path too long: %s\n", getprogname(), socketPath.UTF8String);
			return EX_OSERR;
		}
		addr.sun_len = SUN_LEN(&addr);

		if(connect(fd, (sockaddr*)&addr, sizeof(addr)) == -1)
		{
			fprintf(stderr, "%s: failed connecting to ‘%s’: %s\n", getprogname(), socketPath.UTF8String, strerror(errno));
			return EX_UNAVAILABLE;
		}

		NSMutableArray* arguments = [NSMutableArray array];
		for(size_t i = 0; i < argc; ++i)
			[arguments addObject:@(argv[i])];

		NSDictionary* request = @{
			kOakCommitWindowArguments:   arguments,
			kOakCommitWindowEnvironment: NSProcessInfo.processInfo.environment,
		};

		NSError* error;
		NSData* requestData = [NSPropertyListSerialization dataWithPropertyList:request format:NSPropertyListBinaryFormat_v1_0 options:0 error:&error];
		if(!requestData || !WriteAll(fd, requestData))
		{
			fprintf(stderr, "%s: failed sending request: %s\n", getprogname(), error.localizedDescription.UTF8String ?: "");
			return EX_IOERR;
		}

		// Half-closing is what tells the editor the request is complete. The connection stays open
		// for reading, and that is the return path: this blocks here until the sheet is dismissed.
		shutdown(fd, SHUT_WR);

		NSData* replyData = ReadToEndOfStream(fd);
		close(fd);

		if(!replyData.length)
			return EX_UNAVAILABLE; // The editor closed without answering, treat as cancelled.

		NSDictionary* reply = [NSPropertyListSerialization propertyListWithData:replyData options:NSPropertyListImmutable format:nullptr error:&error];
		if(![reply isKindOfClass:[NSDictionary class]])
		{
			fprintf(stderr, "%s: malformed reply: %s\n", getprogname(), error.localizedDescription.UTF8String ?: "");
			return EX_PROTOCOL;
		}

		if(NSString* err = reply[kOakCommitWindowStandardError])
			fprintf(stderr, "%s", err.UTF8String);

		if(NSString* out = reply[kOakCommitWindowStandardOutput])
		{
			fprintf(stdout, "%s", out.UTF8String);

			if([reply[kOakCommitWindowContinue] boolValue])
				fprintf(stdout, "TM_SCM_COMMIT_CONTINUE=1\n");
		}

		return [reply[kOakCommitWindowReturnCode] intValue];
	}
}
