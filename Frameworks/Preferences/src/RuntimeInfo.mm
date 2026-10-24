#import "RuntimeInfo.h"
#import <io/ruby_runtime.h>
#import <io/python_runtime.h>
#import <io/environment.h>
#import <bundles/bundles.h>
#import <ns/ns.h>

NSString* const TMRuntimeActivationRequestedNotification = @"TMRuntimeActivationRequestedNotification";
NSString* const TMRuntimeDidActivateNotification         = @"TMRuntimeDidActivateNotification";

static NSString* OptionalString (std::string const& value)
{
	return value == NULL_STR ? nil : to_ns(value);
}

static NSString* SupportPath (std::string const& identifier)
{
	bundles::item_ptr bundle = bundles::lookup(oak::uuid_t(identifier));
	return bundle ? to_ns(bundle->support_path()) : nil;
}

@implementation RuntimeInfo
+ (NSString*)rubyPinnedVersion         { return to_ns(ruby_runtime::kPinnedVersion); }
+ (NSString*)pythonPinnedVersion       { return to_ns(python_runtime::kPinnedVersion); }
+ (NSString*)rubyInUse                 { return OptionalString(oak::application_ruby_directory()); }
+ (NSString*)pythonInUse               { return OptionalString(oak::application_python()); }
+ (NSUUID*)rubyBundleIdentifier        { return [[NSUUID alloc] initWithUUIDString:to_ns(ruby_runtime::kBundleIdentifier)]; }
+ (NSUUID*)pythonBundleIdentifier      { return [[NSUUID alloc] initWithUUIDString:to_ns(python_runtime::kBundleIdentifier)]; }
+ (NSString*)rubyBundleSupportPath     { return SupportPath(ruby_runtime::kBundleIdentifier); }
+ (NSString*)pythonBundleSupportPath   { return SupportPath(python_runtime::kBundleIdentifier); }

+ (void)requestActivationForLanguage:(NSString*)language
{
	[NSNotificationCenter.defaultCenter postNotificationName:TMRuntimeActivationRequestedNotification object:nil userInfo:@{ @"language": language }];
}
@end
