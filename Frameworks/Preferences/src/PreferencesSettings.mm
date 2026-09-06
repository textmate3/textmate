#import "PreferencesSettings.h"
#import <OakFoundation/NSString Additions.h>
#import <settings/settings.h>
#import <bundles/bundles.h>
#import <ns/ns.h>
#import <text/ctype.h>
#import <oak/oak.h>

@interface PreferencesGrammar ()
- (instancetype)initWithName:(NSString*)name scope:(NSString*)scope;
@end

@implementation PreferencesGrammar
- (instancetype)initWithName:(NSString*)name scope:(NSString*)scope
{
	if(self = [super init])
	{
		_name  = name;
		_scope = scope;
	}
	return self;
}
@end

@implementation PreferencesSettings
+ (NSString*)binaryKey      { return [NSString stringWithCxxString:kSettingsBinaryKey]; }
+ (NSString*)encodingKey    { return [NSString stringWithCxxString:kSettingsEncodingKey]; }
+ (NSString*)excludeKey     { return [NSString stringWithCxxString:kSettingsExcludeKey]; }
+ (NSString*)fileTypeKey    { return [NSString stringWithCxxString:kSettingsFileTypeKey]; }
+ (NSString*)includeKey     { return [NSString stringWithCxxString:kSettingsIncludeKey]; }
+ (NSString*)lineEndingsKey { return [NSString stringWithCxxString:kSettingsLineEndingsKey]; }

+ (NSString*)stringForKey:(NSString*)key
{
	return [self stringForKey:key section:@""];
}

+ (NSString*)stringForKey:(NSString*)key section:(NSString*)section
{
	std::string const value = settings_t::raw_get(to_s(key), to_s(section));
	return value == NULL_STR ? nil : [NSString stringWithCxxString:value];
}

+ (void)setString:(NSString*)value forKey:(NSString*)key
{
	settings_t::set(to_s(key), to_s(value));
}

+ (void)setString:(NSString*)value forKey:(NSString*)key fileType:(NSString*)fileType
{
	settings_t::set(to_s(key), to_s(value), to_s(fileType));
}

+ (NSArray<PreferencesGrammar*>*)grammars
{
	std::multimap<std::string, bundles::item_ptr, text::less_t> grammars;
	for(auto const& item : bundles::query(bundles::kFieldAny, NULL_STR, scope::wildcard, bundles::kItemTypeGrammar))
	{
		if(!item->hidden_from_user())
			grammars.emplace(item->name(), item);
	}

	NSMutableArray<PreferencesGrammar*>* res = [NSMutableArray array];
	for(auto const& pair : grammars)
	{
		std::string const& scope = pair.second->value_for_field(bundles::kFieldGrammarScope);
		if(scope != NULL_STR)
			[res addObject:[[PreferencesGrammar alloc] initWithName:[NSString stringWithCxxString:pair.first] scope:[NSString stringWithCxxString:scope]]];
	}
	return res;
}
@end
