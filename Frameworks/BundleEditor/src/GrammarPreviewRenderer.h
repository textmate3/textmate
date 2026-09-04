#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

// The attribute a rendered run carries: the scope, as text, of the rule that
// matched there.
extern NSAttributedStringKey const TMGrammarPreviewScopeAttributeName;

// Runs sample text through the parser and colors the result with a theme.
// Either side can be the thing being edited: a grammar that exists only in
// memory, colored with the theme a document would get, or a theme that
// exists only in memory, coloring text parsed with an installed grammar.
// Nothing is saved or looked up by identifier for the edited side: it goes
// in as the dictionary the editor holds, and includes of other grammars
// resolve through the bundle index as they would for a real document.
@interface TMGrammarPreviewRenderer : NSObject

// Colors with the theme a document would get for the appearance.
- (instancetype)initWithDarkAppearance:(BOOL)darkAppearance;

// Colors with a theme held in memory.
- (instancetype)initWithThemeDictionary:(NSDictionary*)theme;

// The theme's page colors, for the view showing the rendered text.
@property (nonatomic, readonly) NSColor* backgroundColor;
@property (nonatomic, readonly) NSColor* foregroundColor;

// Parses with a grammar held in memory.
- (NSAttributedString*)render:(NSString*)text grammar:(NSDictionary*)grammar;

// Parses with an installed grammar, by scope name.
- (NSAttributedString*)render:(NSString*)text grammarScope:(NSString*)scope;

// The scope names of every installed grammar, sorted, for choosing one.
+ (NSArray<NSString*>*)installedGrammarScopes;

@end

NS_ASSUME_NONNULL_END
