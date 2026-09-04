#import <OakFoundation/OakFoundation-Swift.h>

// ApplicationInfo reached from Objective-C++ through the header the Swift compiler generates:
// a Swift class with an Objective-C name, constructed and read from this side.

void test_application_info_reads_the_dictionary ()
{
	OakApplicationInfo* info = [[OakApplicationInfo alloc] initWithInfoDictionary:@{
		@"CFBundleShortVersionString": @"2.1.0",
		@"NSHumanReadableCopyright":   @"© 2026",
	}];
	OAK_ASSERT_EQ(std::string(info.shortVersion.UTF8String), "2.1.0");
	OAK_ASSERT_EQ(std::string(info.copyright.UTF8String), "© 2026");
}

void test_application_info_is_empty_without_keys ()
{
	OakApplicationInfo* info = [[OakApplicationInfo alloc] initWithInfoDictionary:@{}];
	OAK_ASSERT_EQ(std::string(info.shortVersion.UTF8String), "");
	OAK_ASSERT_EQ(std::string(info.copyright.UTF8String), "");
}
