#import "FirstLaunchImport.h"
#import <OakSystem/application.h>
#import <io/path.h>
#import <ns/ns.h>
#import <os/log.h>

static os_log_t const kLogImport = os_log_create("com.textmate3.TextMate", "FirstLaunchImport");

// TextMate 2's identity, which is also what this application was before it
// had one of its own.
static CFStringRef const kTextMate2Identifier = CFSTR("com.macromates.TextMate");

// Every key of TextMate 2's domain, when this application's domain has none.
// The hidden keys from the TextMate 2 wiki come along, since they are keys
// like any other. Keys the application no longer reads are carried too,
// pending an audit of what it reads.
static void ImportPreferences ()
{
	CFStringRef const ownDomain = CFStringCreateWithCString(kCFAllocatorDefault, oak::kBundleIdentifier, kCFStringEncodingUTF8);

	NSArray* ownKeys = CFBridgingRelease(CFPreferencesCopyKeyList(ownDomain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost));
	NSArray* oldKeys = CFBridgingRelease(CFPreferencesCopyKeyList(kTextMate2Identifier, kCFPreferencesCurrentUser, kCFPreferencesAnyHost));
	if(ownKeys.count != 0 || oldKeys.count == 0)
	{
		CFRelease(ownDomain);
		return;
	}

	for(NSString* key in oldKeys)
	{
		if(CFPropertyListRef value = CFPreferencesCopyAppValue((__bridge CFStringRef)key, kTextMate2Identifier))
		{
			CFPreferencesSetAppValue((__bridge CFStringRef)key, value, ownDomain);
			CFRelease(value);
		}
	}
	CFPreferencesAppSynchronize(ownDomain);
	os_log(kLogImport, "Imported %lu preferences from TextMate 2", (unsigned long)oldKeys.count);
	CFRelease(ownDomain);
}

// TextMate 2's Application Support directory, bundles, session, favorites
// and all, copied rather than moved, so TextMate 2 keeps working.
static void ImportSupportDirectory ()
{
	std::string const ownPath = oak::application_t::support();
	std::string const oldPath = path::join(path::home(), "Library/Application Support/TextMate");
	if(path::exists(ownPath) || !path::exists(oldPath))
		return;

	NSError* error;
	if([NSFileManager.defaultManager copyItemAtPath:to_ns(oldPath) toPath:to_ns(ownPath) error:&error])
			os_log(kLogImport, "Imported %{public}s from TextMate 2", oldPath.c_str());
	else	os_log_error(kLogImport, "Failed to import %{public}s from TextMate 2: %{public}@", oldPath.c_str(), error.localizedDescription);
}

void ImportFromTextMate2IfNeeded ()
{
	ImportSupportDirectory();
	ImportPreferences();
}
