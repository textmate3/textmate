#import "../src/FileBrowserViewController.h"

// Writes exactly the shapes encodeRestorableStateWithCoder: writes, with a
// secure archiver, and reads them back with a secure unarchiver through the
// controller's own decoders. If a decode ever stops naming a class that can
// appear, this fails loudly instead of the file browser quietly losing its
// history at launch.
static NSData* ArchivedState ()
{
	NSKeyedArchiver* coder = [[NSKeyedArchiver alloc] initRequiringSecureCoding:YES];
	[coder encodeObject:@[
		@{ @"url": [NSURL fileURLWithPath:@"/tmp/one"], @"scrollOffset": @42.5 },
		@{ @"url": [NSURL fileURLWithPath:@"/tmp/two"] },
	] forKey:@"history"];
	[coder encodeInteger:1 forKey:@"historyIndex"];
	[coder encodeObject:@[ [NSURL fileURLWithPath:@"/tmp/two/a"] ] forKey:@"selectedURLs"];
	[coder encodeObject:@[ [NSURL fileURLWithPath:@"/tmp/two"], [NSURL fileURLWithPath:@"/tmp/two/sub"] ] forKey:@"expandedURLs"];
	[coder finishEncoding];
	return coder.encodedData;
}

void test_restoration_archive_round_trips_under_secure_coding ()
{
	NSError* error;
	NSKeyedUnarchiver* coder = [[NSKeyedUnarchiver alloc] initForReadingFromData:ArchivedState() error:&error];
	OAK_ASSERT(coder != nil);
	OAK_ASSERT(coder.requiresSecureCoding);

	NSArray<NSDictionary*>* history = [FileBrowserViewController historyFromRestorableState:coder];
	OAK_ASSERT_EQ(history.count, 2);
	OAK_ASSERT([history[0][@"url"] isEqual:[NSURL fileURLWithPath:@"/tmp/one"]]);
	OAK_ASSERT_EQ([history[0][@"scrollOffset"] doubleValue], 42.5);
	OAK_ASSERT([history[1][@"url"] isEqual:[NSURL fileURLWithPath:@"/tmp/two"]]);
	OAK_ASSERT_EQ([coder decodeIntegerForKey:@"historyIndex"], 1);

	NSArray<NSURL*>* selected = [FileBrowserViewController URLsForKey:@"selectedURLs" fromRestorableState:coder];
	NSArray<NSURL*>* expanded = [FileBrowserViewController URLsForKey:@"expandedURLs" fromRestorableState:coder];
	OAK_ASSERT_EQ(selected.count, 1);
	OAK_ASSERT_EQ(expanded.count, 2);
	OAK_ASSERT([expanded[1] isEqual:[NSURL fileURLWithPath:@"/tmp/two/sub"]]);

	// Nothing above threw, and the coder reports no decoding failure.
	OAK_ASSERT(coder.error == nil);
}

void test_decoding_refuses_an_unexpected_class ()
{
	// A history entry carrying a class the decoder does not name must be
	// refused rather than instantiated.
	NSKeyedArchiver* archiver = [[NSKeyedArchiver alloc] initRequiringSecureCoding:YES];
	[archiver encodeObject:@[ @{ @"url": [NSDate date] } ] forKey:@"history"];
	[archiver finishEncoding];

	NSKeyedUnarchiver* coder = [[NSKeyedUnarchiver alloc] initForReadingFromData:archiver.encodedData error:nil];
	coder.decodingFailurePolicy = NSDecodingFailurePolicySetErrorAndReturn;
	NSArray* history = [FileBrowserViewController historyFromRestorableState:coder];
	OAK_ASSERT(history == nil || coder.error != nil);
}
