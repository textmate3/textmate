#import "../src/HOFileHandleSchemeHandler.h"
#import <test/jail.h>
#import <ns/ns.h>

void test_page_directories_are_honored_through_the_main_document_url ()
{
	test::jail_t jail;
	jail.touch("project/notes/pic.png");
	jail.touch("elsewhere/x.png");

	NSURL* pageURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@://job/test/1", HOFileHandleURLScheme]];
	[HOFileHandleSchemeHandler registerFileHandle:nil processIdentifier:0 allowedDirectories:@[ to_ns(jail.path("project")) ] forURL:pageURL];

	HOFileHandleSchemeHandler* handler = [HOFileHandleSchemeHandler new];
	OAK_ASSERT([handler isAssetPathAllowed:to_ns(jail.path("project/notes/pic.png")) forMainDocumentURL:pageURL]);
	OAK_ASSERT(![handler isAssetPathAllowed:to_ns(jail.path("elsewhere/x.png")) forMainDocumentURL:pageURL]);

	// A request that does not come from that page gets none of its directories.
	NSURL* otherPageURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@://job/other/2", HOFileHandleURLScheme]];
	OAK_ASSERT(![handler isAssetPathAllowed:to_ns(jail.path("project/notes/pic.png")) forMainDocumentURL:otherPageURL]);
	OAK_ASSERT(![handler isAssetPathAllowed:to_ns(jail.path("project/notes/pic.png")) forMainDocumentURL:nil]);

	[HOFileHandleSchemeHandler unregisterURL:pageURL];
}

void test_bundle_locations_are_always_allowed ()
{
	HOFileHandleSchemeHandler* handler = [HOFileHandleSchemeHandler new];
	NSString* managed = [@"~/Library/Application Support/TextMate 3/Managed/Bundles/Any.tmbundle/Support/style.css" stringByExpandingTildeInPath];
	OAK_ASSERT([handler isAssetPathAllowed:managed forMainDocumentURL:nil]);
	OAK_ASSERT(![handler isAssetPathAllowed:@"/etc/hosts" forMainDocumentURL:nil]);
}

// Images and scripts are requested after the page's output has finished, so the
// directories outlive the output and go away only when the page is unregistered.
void test_page_directories_outlive_the_output ()
{
	test::jail_t jail;
	jail.touch("project/pic.png");

	NSURL* pageURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@://job/test/3", HOFileHandleURLScheme]];
	[HOFileHandleSchemeHandler registerFileHandle:nil processIdentifier:0 allowedDirectories:@[ to_ns(jail.path("project")) ] forURL:pageURL];
	[HOFileHandleSchemeHandler finishURL:pageURL];

	HOFileHandleSchemeHandler* handler = [HOFileHandleSchemeHandler new];
	OAK_ASSERT([handler isAssetPathAllowed:to_ns(jail.path("project/pic.png")) forMainDocumentURL:pageURL]);

	[HOFileHandleSchemeHandler unregisterURL:pageURL];
	OAK_ASSERT(![handler isAssetPathAllowed:to_ns(jail.path("project/pic.png")) forMainDocumentURL:pageURL]);
}
