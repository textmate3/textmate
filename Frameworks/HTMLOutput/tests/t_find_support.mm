#import "../src/HOFindSupport.h"
#import "HOTestFindServer.h"
#import <ns/ns.h>

void test_a_search_is_read_from_the_find_server ()
{
	HOTestFindServer* server = [[HOTestFindServer alloc] init];
	server.findOperation = kFindOperationFind;
	server.findString    = @"needle";
	server.findOptions   = find::backwards | find::ignore_case;

	HOFindRequest* request = [HOFindRequest requestForFindServer:server];
	OAK_ASSERT(request);
	OAK_ASSERT_EQ(to_s(request.findString), "needle");
	OAK_ASSERT(request.backwards);
	OAK_ASSERT(request.ignoresCase);
	OAK_ASSERT(!request.wrapsAround);

	server.findOptions = find::wrap_around;
	OAK_ASSERT(!request.backwards);
	OAK_ASSERT(!request.ignoresCase);
	OAK_ASSERT(request.wrapsAround);
}

void test_a_search_within_the_selection_is_a_search ()
{
	HOTestFindServer* server = [[HOTestFindServer alloc] init];
	server.findOperation = kFindOperationFindInSelection;
	OAK_ASSERT([HOFindRequest requestForFindServer:server]);
}

void test_anything_but_a_search_is_declined ()
{
	HOTestFindServer* server = [[HOTestFindServer alloc] init];
	for(find_operation_t operation : { kFindOperationCount, kFindOperationCountInSelection, kFindOperationReplace, kFindOperationReplaceAndFind, kFindOperationReplaceAll, kFindOperationReplaceAllInSelection })
	{
		server.findOperation = operation;
		OAK_ASSERT(![HOFindRequest requestForFindServer:server]);
	}
	OAK_ASSERT(![HOFindRequest requestForFindServer:[NSObject new]]);
}

void test_what_was_found_is_reported_without_a_position ()
{
	HOTestFindServer* server = [[HOTestFindServer alloc] init];
	server.findOperation = kFindOperationFind;
	server.findString    = @"needle";

	HOFindRequest* request = [HOFindRequest requestForFindServer:server];
	[request reportFound:YES text:@"Needle"];
	OAK_ASSERT_EQ(server.reportedCount, 1);
	OAK_ASSERT_EQ(to_s(server.reportedString), "Needle");
	OAK_ASSERT(server.reportedPositionIsUndefined);

	[request reportFound:NO text:@"needle"];
	OAK_ASSERT_EQ(server.reportedCount, 0);
	OAK_ASSERT_EQ(to_s(server.reportedString), "needle");
}
