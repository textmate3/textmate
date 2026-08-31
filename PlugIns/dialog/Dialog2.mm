//
//  Dialog2.mm
//  Dialog2
//
//  Created by Ciaran Walsh on 19/11/2007.
//

#import "Dialog2.h"
#import "TMDCommand.h"
#import "CLIProxy.h"

@protocol TMPlugInController
- (CGFloat)version;
@end

@interface Dialog2 : NSObject <DialogServerProtocol>
{
	dispatch_source_t _listener;
}
- (id)initWithPlugInController:(id <TMPlugInController>)aController;
@end


@implementation Dialog2

// Reads one request, answers it, and hands the options to the main thread. The read runs off the main
// thread because it blocks until the tool half-closes, and the plug-in lives inside the editor.
- (void)acceptConnection:(int)clientFd
{
	dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
		NSMutableData* data = [NSMutableData data];

		char buf[4096];
		ssize_t len;
		while((len = read(clientFd, buf, sizeof(buf))) != 0)
		{
			if(len == -1)
			{
				if(errno == EINTR)
					continue;
				break;
			}
			[data appendBytes:buf length:len];
		}

		id options = data.length ? [NSPropertyListSerialization propertyListWithData:data options:NSPropertyListImmutable format:nullptr error:nullptr] : nil;

		char answer = [options isKindOfClass:[NSDictionary class]] ? kDialogRequestAccepted : kDialogRequestRejected;
		write(clientFd, &answer, 1);
		close(clientFd);

		if(answer == kDialogRequestAccepted)
			dispatch_async(dispatch_get_main_queue(), ^{ [self dispatch:options]; });
	});
}

- (BOOL)listenOnSocketPath:(NSString*)socketPath
{
	if(unlink(socketPath.fileSystemRepresentation) == -1 && errno != ENOENT)
		return NSLog(@"dialog: unable to remove socket left from an old instance ‘%@’: %s", socketPath, strerror(errno)), NO;

	int fd = socket(AF_UNIX, SOCK_STREAM, 0);
	if(fd == -1)
		return NSLog(@"dialog: unable to create socket: %s", strerror(errno)), NO;

	fcntl(fd, F_SETFD, FD_CLOEXEC);

	struct sockaddr_un addr = { 0, AF_UNIX };
	if(strlcpy(addr.sun_path, socketPath.fileSystemRepresentation, sizeof(addr.sun_path)) >= sizeof(addr.sun_path))
		return close(fd), NSLog(@"dialog: socket path is too long: %@", socketPath), NO;
	addr.sun_len = SUN_LEN(&addr);

	if(bind(fd, (sockaddr*)&addr, sizeof(addr)) == -1)
		return close(fd), NSLog(@"dialog: unable to bind ‘%@’: %s", socketPath, strerror(errno)), NO;

	if(listen(fd, SOMAXCONN) == -1)
		return close(fd), NSLog(@"dialog: unable to listen: %s", strerror(errno)), NO;

	_listener = dispatch_source_create(DISPATCH_SOURCE_TYPE_READ, fd, 0, dispatch_get_main_queue());
	dispatch_source_set_event_handler(_listener, ^{
		int clientFd = accept(fd, nullptr, nullptr);
		if(clientFd != -1)
			[self acceptConnection:clientFd];
	});
	dispatch_source_set_cancel_handler(_listener, ^{ close(fd); });
	dispatch_resume(_listener);

	return YES;
}

- (id)initWithPlugInController:(id <TMPlugInController>)aController
{
	NSApp = NSApplication.sharedApplication;
	if(self = [self init])
	{
		NSString* socketPath = DialogSocketPath(getpid());
		if(![self listenOnSocketPath:socketPath])
			NSBeep();
		else if(NSString* path = [[NSBundle bundleForClass:[self class]] pathForResource:@"tm_dialog2" ofType:nil])
		{
			char* oldDialog = getenv("DIALOG");
			if(oldDialog == NULL || ![@(oldDialog) isEqualToString:path])
			{
				if(oldDialog)
					setenv("DIALOG_1", oldDialog, 1);
				setenv("DIALOG", [path UTF8String], 1);
			}

			setenv("DIALOG_SOCKET_PATH", socketPath.fileSystemRepresentation, 1);
		}
	}

	return self;
}

- (void)dispatch:(id)options
{
	CLIProxy* interface = [CLIProxy proxyWithOptions:options];

	NSString* command = [interface numberOfArguments] <= 1 ? @"help" : [interface argumentAtIndex:1];

	if(id target = [TMDCommand objectForCommand:command])
			[target performSelector:@selector(handleCommand:) withObject:interface];
	else	[interface writeStringToError:@"unknown command, try help.\n"];
}

- (void)connectFromClientWithOptions:(id)options
{
	[self performSelector:@selector(dispatch:) withObject:options afterDelay:0.0];
}

@end
/*
echo '{ menuItems = ({title = 'foo';});}' | "$DIALOG" menu
*/
