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
	plist::dictionary_t const plist = plist::convert((__bridge CFPropertyListRef)grammar);

	// A transient item carrying the dictionary, so the parser sees the grammar
	// as it sees any other, scope name and all. It is never in the index.
	auto item = std::make_shared<bundles::item_t>(oak::uuid_t().generate(), bundles::item_ptr(), bundles::kItemTypeGrammar, true);
	item->set_plist(plist);

	parse::grammar_t parser(item);
	theme_ptr theme = [self theme];

	NSMutableAttributedString* result = [[NSMutableAttributedString alloc] init];
	NSFont* baseFont = [NSFont userFixedPitchFontOfSize:0];

	std::string const source = to_s(text);
	parse::stack_ptr stack = parser.seed();

	std::string scopeName;
	plist::get_key_path(plist, "scopeName", scopeName);
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
