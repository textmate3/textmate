// What the bundle item chooser, in Swift, lists: the bundle items that apply
// in a scope, with the settings they carry spelled out one per row, the
// settings that apply to a file, and the key bindings from every dictionary
// the system reads. The bundle index, the settings and the property lists are
// C++, and this plain Objective-C hands over records the rows are built from.
#ifndef TM_BUNDLE_ITEMS_H_2C9E6B41
#define TM_BUNDLE_ITEMS_H_2C9E6B41

#import <Cocoa/Cocoa.h>
#import "TMScopeContext.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_OPTIONS(NSUInteger, TMBundleItemSources) {
	TMBundleItemSourceActions      = 1 << 0, // commands, macros and snippets
	TMBundleItemSourceSettings     = 1 << 1,
	TMBundleItemSourceGrammars     = 1 << 2,
	TMBundleItemSourceThemes       = 1 << 3,
	TMBundleItemSourceDragCommands = 1 << 4,
};

// A bundle item, or one setting out of a settings item.
@interface TMBundleItemRecord : NSObject
@property (nonatomic, readonly) NSString* name;
// The menu path the item sits under, "Ruby ‣ Rake", with the kind appended for a grammar or a theme.
@property (nonatomic, readonly) NSString* location;
@property (nonatomic, readonly) NSString* uuid;
@property (nonatomic, readonly) NSString* scopeSelector;
@property (nonatomic, readonly, nullable) NSString* keyEquivalent;
@property (nonatomic, readonly, nullable) NSString* tabTrigger;
@property (nonatomic, readonly, nullable) NSString* semanticClass;
// The setting's value, for a row that is one setting of a settings item.
@property (nonatomic, readonly, nullable) NSString* value;
// Whether a setting of the same name in an item that comes earlier overrides this one.
@property (nonatomic, readonly) BOOL eclipsed;
@property (nonatomic, readonly) BOOL isSettings;
@end

// A setting in force for a file, from the settings files and the preferences.
@interface TMSettingRecord : NSObject
@property (nonatomic, readonly) NSString* name;
@property (nonatomic, readonly) NSString* value;
// Where it was set: the file with its section, or the application's preferences.
@property (nonatomic, readonly) NSString* location;
@property (nonatomic, readonly, nullable) NSString* file;
@property (nonatomic, readonly) NSString* line;
@end

// One key in a key bindings dictionary.
@interface TMKeyBindingRecord : NSObject
// The action as words, "Move Word Forward", or the bound value when it is not a selector.
@property (nonatomic, readonly) NSString* name;
@property (nonatomic, readonly) NSString* location;
@property (nonatomic, readonly) NSString* file;
@property (nonatomic, readonly) NSString* keyEquivalent;
@property (nonatomic, readonly, nullable) NSString* selectorName;
@end

@interface TMBundleItems : NSObject
// The items of the kinds asked for that apply in the scope, in the order the
// bundle index ranks them. A settings item becomes one record per setting,
// and when the scope is not every scope, a setting that an earlier item also
// carries is marked eclipsed.
+ (NSArray<TMBundleItemRecord*>*)recordsInScope:(TMScopeContext*)scope hasSelection:(BOOL)hasSelection sources:(TMBundleItemSources)sources everyScope:(BOOL)everyScope;
+ (NSArray<TMSettingRecord*>*)settingsForPath:(nullable NSString*)path scope:(TMScopeContext*)scope everyScope:(BOOL)everyScope directory:(nullable NSString*)directory;
// From the application's own dictionary down to the system's, in that order, with "noop:" left out.
+ (NSArray<TMKeyBindingRecord*>*)keyBindingRecords;
// "Command", "Snippet" and so on, or nil for an unknown item.
+ (nullable NSString*)kindNameOfItemWithUUID:(NSString*)uuid NS_SWIFT_NAME(kindName(ofItemWithUUID:));
+ (nullable NSImage*)iconForFile:(NSString*)path;
// A key equivalent such as "@s" drawn as "⌘S".
+ (NSAttributedString*)attributedStringForEventString:(NSString*)eventString font:(NSFont*)font;
@end

NS_ASSUME_NONNULL_END

#endif /* end of include guard: TM_BUNDLE_ITEMS_H_2C9E6B41 */
