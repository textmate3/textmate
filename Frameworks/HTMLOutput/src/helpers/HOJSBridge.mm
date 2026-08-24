#import "HOJSBridge.h"
#import "add_to_buffer.h"
#import <OakAppKit/NSAlert Additions.h>
#import <OakFoundation/NSString Additions.h>
#import <oak/debug.h>
#import <document/OakDocument.h>
#import <document/OakDocumentController.h>
#import <text/utf8.h>
#import <ns/ns.h>
#import <io/exec.h>

// A command started by TextMate.system(). Output is streamed to the page as it
// arrives, and the completion block carries the final result back to the reply
// handler that the page is awaiting.
@interface HOJSShellCommand : NSObject
{
	io::process_t process;
	std::string output, error;
}
@property (nonatomic, copy) void(^streamHandler)(NSString* text, BOOL isError);
@property (nonatomic) NSString* command;
@property (nonatomic, copy) void(^completionHandler)(NSString* output, NSString* error, int status);
- (id)initShellCommand:(NSString*)aCommand withEnvironment:(const std::map<std::string, std::string>&)someEnvironment;
- (BOOL)start;
- (void)cancelCommand;
- (void)writeToInput:(NSString*)someData;
- (void)closeInput;
@end

@implementation HOJSBridge
{
	std::map<std::string, std::string> environment;
	NSMutableDictionary<NSNumber*, HOJSShellCommand*>* _tasks;
}

+ (NSString*)messageHandlerName
{
	return @"textmate";
}

+ (NSString*)userScriptSource
{
	NSString* path = [[NSBundle bundleForClass:self] pathForResource:@"TextMateBridge" ofType:@"js"];
	NSString* source = path ? [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nullptr] : nil;
	if(!source)
		os_log_error(OS_LOG_DEFAULT, "HTMLOutput: unable to load TextMateBridge.js");
	return source ?: @"";
}

- (instancetype)init
{
	if(self = [super init])
		_tasks = [NSMutableDictionary new];
	return self;
}

- (std::map<std::string, std::string> const&)environment
{
	return environment;
}

- (void)setEnvironment:(const std::map<std::string, std::string>&)variables
{
	environment = variables;
}

// ===================
// = Message Handler =
// ===================

- (void)userContentController:(WKUserContentController*)controller didReceiveScriptMessage:(WKScriptMessage*)message replyHandler:(void(^)(id reply, NSString* errorMessage))replyHandler
{
	if(![message.body isKindOfClass:NSDictionary.class])
		return replyHandler(nil, @"TextMate bridge: malformed message");

	NSDictionary* body = message.body;
	NSString* method   = body[@"method"];
	NSNumber* taskId   = body[@"taskId"];

	if([method isEqualToString:@"system"])
		return [self startCommand:body[@"command"] taskId:taskId replyHandler:replyHandler];

	if([method isEqualToString:@"cancel"])
	{
		[_tasks[taskId] cancelCommand];
		[_tasks removeObjectForKey:taskId];
		return replyHandler(nil, nil);
	}

	if([method isEqualToString:@"write"])
	{
		[_tasks[taskId] writeToInput:body[@"string"]];
		return replyHandler(nil, nil);
	}

	if([method isEqualToString:@"close"])
	{
		[_tasks[taskId] closeInput];
		return replyHandler(nil, nil);
	}

	if([method isEqualToString:@"log"])
	{
		NSLog(@"JavaScript Log: %@", body[@"message"]);
		return replyHandler(nil, nil);
	}

	if([method isEqualToString:@"openFile"])
	{
		[self openFile:body[@"path"] withOptions:body[@"options"]];
		return replyHandler(nil, nil);
	}

	if([method isEqualToString:@"setBusy"])
	{
		_delegate.busy = [body[@"value"] boolValue];
		return replyHandler(nil, nil);
	}

	if([method isEqualToString:@"setProgress"])
	{
		_delegate.progress = [body[@"value"] doubleValue];
		return replyHandler(nil, nil);
	}

	replyHandler(nil, [NSString stringWithFormat:@"TextMate bridge: unknown method ‘%@’", method]);
}

- (void)startCommand:(NSString*)command taskId:(NSNumber*)taskId replyHandler:(void(^)(id reply, NSString* errorMessage))replyHandler
{
	if(!command || !taskId)
		return replyHandler(nil, @"TextMate.system: missing command");

	HOJSShellCommand* task = [[HOJSShellCommand alloc] initShellCommand:command withEnvironment:environment];
	_tasks[taskId] = task;

	__weak HOJSBridge* weakSelf = self;
	task.streamHandler = ^(NSString* text, BOOL isError){
		[weakSelf emitForTask:taskId which:(isError ? @"error" : @"output") text:text];
	};

	task.completionHandler = ^(NSString* out, NSString* err, int status){
		[weakSelf removeTask:taskId];
		replyHandler(@{ @"outputString": out ?: @"", @"errorString": err ?: @"", @"status": @(status) }, nil);
	};

	if(![task start])
	{
		[self removeTask:taskId];
		replyHandler(nil, [NSString stringWithFormat:@"TextMate.system: unable to run ‘%@’", command]);
	}
}

- (void)removeTask:(NSNumber*)taskId
{
	[_tasks removeObjectForKey:taskId];
}

// Streaming runs the other way, so it goes back through the page rather than a reply.
- (void)emitForTask:(NSNumber*)taskId which:(NSString*)which text:(NSString*)text
{
	NSData* json = [NSJSONSerialization dataWithJSONObject:@[ taskId, which, text ?: @"" ] options:0 error:nullptr];
	if(!json)
		return;

	NSString* args   = [[NSString alloc] initWithData:json encoding:NSUTF8StringEncoding];
	NSString* script = [NSString stringWithFormat:@"window.__tmBridgeEmit && window.__tmBridgeEmit.apply(null, %@);", args];
	[_webView evaluateJavaScript:script completionHandler:nil];
}

- (void)openFile:(NSString*)path withOptions:(id)options
{
	text::range_t range = text::range_t::undefined;
	if([options isKindOfClass:NSNumber.class])
		range = text::pos_t([options intValue]-1, 0);
	else if([options isKindOfClass:NSString.class])
		range = to_s(options);
	if(OakDocument* doc = [OakDocumentController.sharedInstance documentWithPath:path])
		[OakDocumentController.sharedInstance showDocument:doc andSelect:range inProject:nil bringToFront:YES];
}
@end

@implementation HOJSShellCommand
{
	std::map<std::string, std::string> _environment;
}
- (id)initShellCommand:(NSString*)aCommand withEnvironment:(const std::map<std::string, std::string>&)someEnvironment
{
	if(self = [super init])
	{
		_command     = aCommand;
		_environment = someEnvironment;
	}
	return self;
}

// Separate from construction so the caller can attach handlers first. Output written
// between the spawn and a handler being attached would otherwise be buffered and
// never streamed, losing the first chunk from a command that writes immediately.
- (BOOL)start
{
	if(!(process = io::spawn(std::vector<std::string>{ "/bin/sh", "-c", to_s(_command) }, _environment)))
		return NO;

	auto group = dispatch_group_create();
	dispatch_queue_t queue = dispatch_get_main_queue();

	[self exhaustFileDescriptor:process.out inQueue:queue group:group buffer:output isError:NO];
	[self exhaustFileDescriptor:process.err inQueue:queue group:group buffer:error isError:YES];

	__block int status = 0;
	dispatch_group_async(group, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
		int result = 0;
		if(waitpid(process.pid, &result, 0) != process.pid)
			perror("HOJSShellCommand: waitpid");
		process.pid = -1;
		status = WIFEXITED(result) ? WEXITSTATUS(result) : -1;
	});

	dispatch_group_notify(group, dispatch_get_main_queue(), ^{
		close(process.out);
		close(process.err);
		if(self.completionHandler)
			self.completionHandler([NSString stringWithCxxString:output], [NSString stringWithCxxString:error], status);
		self.completionHandler = nil;
		self.streamHandler     = nil;
	});

	return YES;
}

- (void)exhaustFileDescriptor:(int)fd inQueue:(dispatch_queue_t)queue group:(dispatch_group_t)group buffer:(std::string&)buf isError:(BOOL)isError
{
	dispatch_group_async(group, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
		char tmp[1024];
		while(ssize_t len = read(fd, &tmp[0], sizeof(tmp)))
		{
			if(len < 0)
				break;

			char const* bytes = &tmp[0];
			dispatch_sync(queue, ^{
				BOOL streaming = self.streamHandler != nil;
				auto range = add_bytes_to_utf8_buffer(buf, bytes, bytes + len, streaming);
				if(streaming && range.first != range.second)
					self.streamHandler([NSString stringWithCxxString:std::string(range.first, range.second)], isError);
			});
		}
	});
}

- (void)cancelCommand
{
	self.streamHandler     = nil;
	self.completionHandler = nil;

	[self closeInput];

	if(process)
		kill(process.pid, SIGINT);
}

- (void)writeToInput:(NSString*)someData
{
	if(process.in != -1)
	{
		char const* bytes = [someData UTF8String];
		write(process.in, bytes, strlen(bytes));
	}
}

- (void)closeInput
{
	if(process.in != -1)
	{
		close(process.in);
		process.in = -1;
	}
}

- (void)dealloc
{
	[self cancelCommand];
}
@end
