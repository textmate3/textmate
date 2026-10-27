#import "TMBundleItems.h"
#import <OakSystem/application.h>
#import <TMFileReference/TMFileReference.h>
#import <bundles/bundles.h>
#import <settings/settings.h>
#import <regexp/format_string.h>
#import <io/path.h>
#import <text/ctype.h>
#import <ns/event.h>
#import <ns/ns.h>

scope::context_t TMScopeContextToCxx (TMScopeContext* context);

// A property list value on one line, with single quoted strings and the
// whitespace collapsed, the way the row shows a setting's value.
static std::string FormatValue (plist::any_t const& plist)
{
	return format_string::replace(to_s(plist, plist::kPreferSingleQuotedStrings|plist::kSingleLine), "\\A\\s+|\\s+\\z|(\\s+)", "${1:+ }");
}

static std::string DisplayPathForFile (std::string const& path)
{
	return path::is_child(path, oak::application_t::path()) ? "TextMate.app ‣ " + path::name(path) : path::with_tilde(path);
}

@interface TMBundleItemRecord ()
@property (nonatomic) NSString* name;
@property (nonatomic) NSString* location;
@property (nonatomic) NSString* uuid;
@property (nonatomic) NSString* scopeSelector;
@property (nonatomic) NSString* keyEquivalent;
@property (nonatomic) NSString* tabTrigger;
@property (nonatomic) NSString* semanticClass;
@property (nonatomic) NSString* value;
@property (nonatomic) BOOL eclipsed;
@property (nonatomic) BOOL isSettings;
@end

@implementation TMBundleItemRecord
@end

@interface TMSettingRecord ()
@property (nonatomic) NSString* name;
@property (nonatomic) NSString* value;
@property (nonatomic) NSString* location;
@property (nonatomic) NSString* file;
@property (nonatomic) NSString* line;
@end

@implementation TMSettingRecord
@end

@interface TMKeyBindingRecord ()
@property (nonatomic) NSString* name;
@property (nonatomic) NSString* location;
@property (nonatomic) NSString* file;
@property (nonatomic) NSString* keyEquivalent;
@property (nonatomic) NSString* selectorName;
@end

@implementation TMKeyBindingRecord
@end

@implementation TMBundleItems
+ (NSArray<TMBundleItemRecord*>*)recordsInScope:(TMScopeContext*)scope hasSelection:(BOOL)hasSelection sources:(TMBundleItemSources)sources everyScope:(BOOL)everyScope
{
	int mask = 0;
	if(sources & TMBundleItemSourceActions)
		mask |= bundles::kItemTypeCommand|bundles::kItemTypeMacro|bundles::kItemTypeSnippet;
	if(sources & TMBundleItemSourceSettings)
		mask |= bundles::kItemTypeSettings;
	if(sources & TMBundleItemSourceGrammars)
		mask |= bundles::kItemTypeGrammar;
	if(sources & TMBundleItemSourceThemes)
		mask |= bundles::kItemTypeTheme;
	if(sources & TMBundleItemSourceDragCommands)
		mask |= bundles::kItemTypeDragCommand;

	NSMutableArray<TMBundleItemRecord*>* res = [NSMutableArray array];
	std::set<std::string> previousSettings, previousVariables;

	for(auto const& bundleItem : bundles::query(bundles::kFieldAny, NULL_STR, TMScopeContextToCxx(scope), mask, oak::uuid_t(), false))
	{
		std::string const name = bundles::name_with_selection(bundleItem, hasSelection);
		std::string const path = bundles::menu_path(bundleItem);
		NSString* const uuid   = to_ns(to_s(bundleItem->uuid()));
		NSString* const scopeSelector = to_ns(to_s(bundleItem->scope_selector()));

		if(bundleItem->kind() != bundles::kItemTypeSettings)
		{
			std::string suffix;
			if(bundleItem->kind() == bundles::kItemTypeGrammar)
				suffix = " ‣ Language Grammars";
			else if(bundleItem->kind() == bundles::kItemTypeTheme)
				suffix = " ‣ Themes";

			TMBundleItemRecord* record = [[TMBundleItemRecord alloc] init];
			record.name          = to_ns(name);
			record.location      = to_ns(path + suffix);
			record.uuid          = uuid;
			record.scopeSelector = scopeSelector;
			record.keyEquivalent = to_ns(bundles::key_equivalent(bundleItem));
			record.tabTrigger    = to_ns(bundleItem->value_for_field(bundles::kFieldTabTrigger));
			record.semanticClass = to_ns(text::join(bundleItem->values_for_field(bundles::kFieldSemanticClass), ", "));
			[res addObject:record];
			continue;
		}

		plist::dictionary_t settings;
		if(!plist::get_key_path(bundleItem->plist(), bundles::kFieldSettingName, settings))
			continue;

		for(auto const& pair : settings)
		{
			if(pair.first != "shellVariables")
			{
				TMBundleItemRecord* record = [[TMBundleItemRecord alloc] init];
				record.name          = to_ns(pair.first);
				record.value         = to_ns(FormatValue(pair.second));
				record.location      = to_ns(path + " ‣ " + name);
				record.uuid          = uuid;
				record.eclipsed      = !everyScope && !previousSettings.insert(pair.first).second;
				record.scopeSelector = scopeSelector;
				record.isSettings    = YES;
				[res addObject:record];
				continue;
			}

			auto const shellVariables = bundles::shell_variables(bundleItem);

			BOOL eclipsed = NO;
			if(!everyScope)
			{
				for(auto const& variable : shellVariables)
					eclipsed = !previousVariables.insert(variable.first).second || eclipsed;
			}

			for(auto const& variable : shellVariables)
			{
				TMBundleItemRecord* record = [[TMBundleItemRecord alloc] init];
				record.name          = to_ns(variable.first);
				record.value         = to_ns(FormatValue(variable.second));
				record.location      = to_ns(path + " ‣ " + name + " ‣ " + "shellVariables");
				record.uuid          = uuid;
				record.eclipsed      = eclipsed;
				record.scopeSelector = scopeSelector;
				record.isSettings    = YES;
				[res addObject:record];
			}
		}
	}
	return res;
}

+ (NSArray<TMSettingRecord*>*)settingsForPath:(NSString*)path scope:(TMScopeContext*)scope everyScope:(BOOL)everyScope directory:(NSString*)directory
{
	NSMutableArray<TMSettingRecord*>* res = [NSMutableArray array];
	scope::scope_t const right = everyScope ? scope::wildcard : scope::scope_t(to_s(scope.right));
	for(auto const& info : settings_info_for_path(path ? to_s(path) : NULL_STR, right, directory ? to_s(directory) : NULL_STR))
	{
		std::string location = info.path == NULL_STR ? "TextMate.app ‣ Preferences" : DisplayPathForFile(info.path) + (info.section == NULL_STR ? "" : " ‣ " + info.section);

		TMSettingRecord* record = [[TMSettingRecord alloc] init];
		record.name     = to_ns(info.variable);
		record.value    = to_ns(FormatValue(info.value));
		record.location = to_ns(location);
		record.file     = to_ns(info.path);
		record.line     = [NSString stringWithFormat:@"%zu", info.line_number];
		[res addObject:record];
	}
	return res;
}

+ (NSArray<TMKeyBindingRecord*>*)keyBindingRecords
{
	static std::string const KeyBindingLocations[] =
	{
		oak::application_t::support("KeyBindings.dict"),
		oak::application_t::path("Contents/Resources/KeyBindings.dict"),
		path::join(path::home(), "Library/KeyBindings/DefaultKeyBinding.dict"),
		"/Library/KeyBindings/DefaultKeyBinding.dict",
		"/System/Library/Frameworks/AppKit.framework/Resources/StandardKeyBinding.dict",
	};

	NSMutableArray<TMKeyBindingRecord*>* res = [NSMutableArray array];
	for(auto const& path : KeyBindingLocations)
	{
		std::string const location = DisplayPathForFile(path);
		for(auto const& pair : plist::load(path))
		{
			TMKeyBindingRecord* record = [[TMKeyBindingRecord alloc] init];
			record.location      = to_ns(location);
			record.file          = to_ns(path);
			record.keyEquivalent = to_ns(ns::normalize_event_string(pair.first));

			if(std::string const* selector = plist::get_if<std::string>(&pair.second))
			{
				if(*selector == "noop:")
					continue;

				std::string name = format_string::replace(*selector, "[a-z](?=[A-Z])", "$0 ");
				name = format_string::replace(name, "(.+):\\z", "${1:/capitalize}");
				name = format_string::replace(name, "\\bsub Word\\b", "Sub-word");

				record.name         = to_ns(name);
				record.selectorName = to_ns(*selector);
			}
			else
			{
				record.name = to_ns(FormatValue(pair.second));
			}
			[res addObject:record];
		}
	}
	return res;
}

+ (NSString*)kindNameOfItemWithUUID:(NSString*)uuid
{
	static std::map<bundles::kind_t, NSString*> const map = {
		{ bundles::kItemTypeCommand,     @"Command"      },
		{ bundles::kItemTypeDragCommand, @"Drag Command" },
		{ bundles::kItemTypeSnippet,     @"Snippet"      },
		{ bundles::kItemTypeSettings,    @"Settings"     },
		{ bundles::kItemTypeGrammar,     @"Grammar"      },
		{ bundles::kItemTypeProxy,       @"Proxy"        },
		{ bundles::kItemTypeTheme,       @"Theme"        },
		{ bundles::kItemTypeMacro,       @"Macro"        },
	};

	if(bundles::item_ptr item = bundles::lookup(to_s(uuid)))
	{
		auto it = map.find(item->kind());
		if(it != map.end())
			return it->second;
	}
	return nil;
}

+ (NSImage*)iconForFile:(NSString*)path
{
	if(path::is_child(to_s(path), oak::application_t::path()))
		return [NSImage imageNamed:NSImageNameApplicationIcon];
	return [TMFileReference imageForURL:[NSURL fileURLWithPath:path] size:NSMakeSize(16, 16)];
}

+ (NSAttributedString*)attributedStringForEventString:(NSString*)eventString font:(NSFont*)font
{
	return OakAttributedStringForEventString(eventString, font);
}
@end
