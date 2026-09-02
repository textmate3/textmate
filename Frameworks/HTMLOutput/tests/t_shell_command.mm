#import "../src/helpers/HOJSBridge.h"
#import <ns/ns.h>

// Runs the command and spins the main run loop until it completes, because the
// bridge delivers both streamed chunks and the completion on the main queue.
static void run_until_complete (HOJSShellCommand* task)
{
	__block BOOL done = NO;
	void(^completion)(NSString*, NSString*, int) = task.completionHandler;
	task.completionHandler = ^(NSString* output, NSString* error, int status){
		completion(output, error, status);
		done = YES;
	};
	OAK_ASSERT([task start]);

	NSDate* deadline = [NSDate dateWithTimeIntervalSinceNow:10];
	while(!done && deadline.timeIntervalSinceNow > 0)
		[NSRunLoop.mainRunLoop runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
	OAK_ASSERT(done);
}

static std::map<std::string, std::string> const Environment = { { "PATH", "/usr/bin:/bin" } };

// Well past the bridge's read size, so the output arrives in many reads.
static std::string numbers_up_to (int n)
{
	std::string res;
	for(int i = 1; i <= n; ++i)
		res += std::to_string(i) + "\n";
	return res;
}

void test_completion_gets_the_whole_output ()
{
	HOJSShellCommand* task = [[HOJSShellCommand alloc] initShellCommand:@"seq 1 3000" withEnvironment:Environment];

	__block std::string output;
	__block int status = -1;
	task.completionHandler = ^(NSString* out, NSString* err, int exitStatus){
		output = to_s(out);
		status = exitStatus;
	};

	run_until_complete(task);
	OAK_ASSERT_EQ(status, 0);
	OAK_ASSERT_EQ(output, numbers_up_to(3000));
}

void test_streamed_chunks_add_up_to_the_output ()
{
	HOJSShellCommand* task = [[HOJSShellCommand alloc] initShellCommand:@"seq 1 3000" withEnvironment:Environment];

	__block std::string streamed;
	__block std::string output;
	task.streamHandler = ^(NSString* text, BOOL isError){
		if(!isError)
			streamed += to_s(text);
	};
	task.completionHandler = ^(NSString* out, NSString* err, int exitStatus){
		output = to_s(out);
	};

	run_until_complete(task);
	OAK_ASSERT_EQ(streamed, numbers_up_to(3000));
	OAK_ASSERT_EQ(output, numbers_up_to(3000));
}

void test_error_output_is_kept_apart ()
{
	HOJSShellCommand* task = [[HOJSShellCommand alloc] initShellCommand:@"echo out; echo err 1>&2; exit 3" withEnvironment:Environment];

	__block std::string output, error;
	__block int status = -1;
	task.completionHandler = ^(NSString* out, NSString* err, int exitStatus){
		output = to_s(out);
		error  = to_s(err);
		status = exitStatus;
	};

	run_until_complete(task);
	OAK_ASSERT_EQ(output, "out\n");
	OAK_ASSERT_EQ(error, "err\n");
	OAK_ASSERT_EQ(status, 3);
}
