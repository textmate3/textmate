#import "GrammarPreviewRenderer.h"
#import <OakFoundation/NSString Additions.h>
#import <bundles/bundles.h>
#import <parse/grammar.h>
#import <parse/parse.h>
#import <plist/plist.h>
#import <scope/scope.h>
#import <settings/settings.h>
#import <theme/theme.h>
#import <ns/ns.h>

NSAttributedStringKey const TMGrammarPreviewScopeAttributeName = @"TMGrammarPreviewScope";

// A bundle item that exists only to carry a dictionary to the parser or the
// theme code, which read items rather than dictionaries. Never in the index.
static bundles::item_ptr TransientItem (NSDictionary* dictionary, bundles::kind_t kind)
{
	auto item = std::make_shared<bundles::item_t>(oak::uuid_t().generate(), bundles::item_ptr(), kind, true);
	item->set_plist(plist::convert((__bridge CFPropertyListRef)dictionary));
	return item;
}

@implementation TMGrammarPreviewRenderer
{
	BOOL _darkAppearance;
	theme_ptr _theme;
}

- (instancetype)initWithDarkAppearance:(BOOL)darkAppearance
{
	if(self = [super init])
		_darkAppearance = darkAppearance;
	return self;
}

- (instancetype)initWithThemeDictionary:(NSDictionary*)theme
{
	if(self = [super init])
		_theme = parse_theme(TransientItem(theme, bundles::kItemTypeTheme));
	return self;
}

// The theme a document would get, resolved the way the text view resolves
// it: a theme named by a scoped setting wins, otherwise the one chosen for
// the appearance, dark or light, with the appearance preference deciding
// which of the two applies.
- (theme_ptr)theme
{
	if(!_theme)
	{
		std::string themeUUID = settings_for_path().get(kSettingsThemeKey);
		if(themeUUID == NULL_STR)
		{
			NSString* appearance = [NSUserDefaults.standardUserDefaults stringForKey:@"themeAppearance"];
			BOOL darkMode = [appearance isEqualToString:@"dark"] || (![appearance isEqualToString:@"light"] && _darkAppearance);
			themeUUID = to_s([NSUserDefaults.standardUserDefaults stringForKey:darkMode ? @"darkModeThemeUUID" : @"universalThemeUUID"]);
		}

		bundles::item_ptr themeItem = bundles::lookup(themeUUID) ?: bundles::lookup(kTwilightThemeUUID);
		if(themeItem)
			_theme = parse_theme(themeItem);
	}
	return _theme;
}

- (NSColor*)backgroundColor
{
	theme_ptr theme = [self theme];
	return theme && theme->background() ? [NSColor colorWithCGColor:theme->background()] : NSColor.textBackgroundColor;
}

- (NSColor*)foregroundColor
{
	theme_ptr theme = [self theme];
	return theme && theme->foreground() ? [NSColor colorWithCGColor:theme->foreground()] : NSColor.textColor;
}

- (NSAttributedString*)render:(NSString*)text grammar:(NSDictionary*)grammar
{
	std::string scopeName;
	plist::get_key_path(plist::convert((__bridge CFPropertyListRef)grammar), "scopeName", scopeName);
	return [self render:text item:TransientItem(grammar, bundles::kItemTypeGrammar) scopeName:scopeName];
}

- (NSAttributedString*)render:(NSString*)text grammarScope:(NSString*)scope
{
	for(auto item : bundles::query(bundles::kFieldGrammarScope, to_s(scope), scope::wildcard, bundles::kItemTypeGrammar))
		return [self render:text item:item scopeName:to_s(scope)];
	return [[NSAttributedString alloc] initWithString:text attributes:@{ NSFontAttributeName: [NSFont userFixedPitchFontOfSize:0], NSForegroundColorAttributeName: self.foregroundColor }];
}

+ (NSArray<NSString*>*)installedGrammarScopes
{
	NSMutableArray<NSString*>* scopes = [NSMutableArray array];
	for(auto item : bundles::query(bundles::kFieldAny, NULL_STR, scope::wildcard, bundles::kItemTypeGrammar))
	{
		std::string const scope = item->value_for_field(bundles::kFieldGrammarScope);
		if(scope != NULL_STR && !scope.empty())
			[scopes addObject:to_ns(scope)];
	}
	return [scopes sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
}

- (NSAttributedString*)render:(NSString*)text item:(bundles::item_ptr const&)item scopeName:(std::string const&)scopeName
{
	parse::grammar_t parser(item);
	theme_ptr theme = [self theme];

	NSMutableAttributedString* result = [[NSMutableAttributedString alloc] init];
	NSFont* baseFont = [NSFont userFixedPitchFontOfSize:0];

	std::string const source = to_s(text);
	parse::stack_ptr stack = parser.seed();
	scope::scope_t scope(scopeName);

	bool firstLine = true;
	size_t from = 0;
	while(from < source.size())
	{
		size_t to = source.find('\n', from);
		to = to == std::string::npos ? source.size() : to + 1;
		char const* first = source.data() + from;
		char const* last  = source.data() + to;

		std::map<size_t, scope::scope_t> scopes;
		stack = parse::parse(first, last, stack, scopes, firstLine);
		firstLine = false;

		size_t lastPos = 0;
		auto append = [&](size_t upTo){
			if(upTo <= lastPos)
				return;
			NSString* run = [NSString stringWithUTF8String:first + lastPos length:upTo - lastPos] ?: @"";
			NSMutableDictionary* attributes = [NSMutableDictionary dictionary];
			attributes[NSFontAttributeName] = baseFont;
			attributes[NSForegroundColorAttributeName] = self.foregroundColor;
			attributes[TMGrammarPreviewScopeAttributeName] = to_ns(to_s(scope));
			if(theme)
			{
				styles_t const& styles = theme->styles_for_scope(scope);
				if(CGColorRef foreground = styles.foreground())
					attributes[NSForegroundColorAttributeName] = [NSColor colorWithCGColor:foreground];
				if(CTFontRef font = styles.font())
					attributes[NSFontAttributeName] = (__bridge NSFont*)font;
				if(styles.underlined())
					attributes[NSUnderlineStyleAttributeName] = @(NSUnderlineStyleSingle);
			}
			[result appendAttributedString:[[NSAttributedString alloc] initWithString:run attributes:attributes]];
			lastPos = upTo;
		};

		for(auto const& pair : scopes)
		{
			append(pair.first);
			scope = pair.second;
		}
		append(last - first);

		from = to;
	}

	return result;
}
@end
