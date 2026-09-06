#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

// A grammar a new or unknown document can open as: the name a person reads and the scope the
// setting stores.
@interface PreferencesGrammar : NSObject
@property (nonatomic, readonly) NSString* name;
@property (nonatomic, readonly) NSString* scope;
@end

// The settings behind the preferences that are not defaults: the global .tm_properties values the
// Files and Projects panes edit. Plain Objective-C over the settings framework, so the Swift panes
// can read and write them without seeing C++. A key with no value reads as nil, and setting nil
// stores the settings framework's own null, the way the Objective-C panes did.
@interface PreferencesSettings : NSObject
@property (class, readonly) NSString* binaryKey;
@property (class, readonly) NSString* encodingKey;
@property (class, readonly) NSString* excludeKey;
@property (class, readonly) NSString* fileTypeKey;
@property (class, readonly) NSString* includeKey;
@property (class, readonly) NSString* lineEndingsKey;

+ (nullable NSString*)stringForKey:(NSString*)key;
+ (nullable NSString*)stringForKey:(NSString*)key section:(NSString*)section;
+ (void)setString:(nullable NSString*)value forKey:(NSString*)key;
+ (void)setString:(nullable NSString*)value forKey:(NSString*)key fileType:(NSString*)fileType;

// Every grammar shown to people, by name.
+ (NSArray<PreferencesGrammar*>*)grammars;
@end

NS_ASSUME_NONNULL_END
