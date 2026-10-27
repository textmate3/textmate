// The scope the bundle item chooser filters by: the scope to the left of the
// caret and the one to the right, each as the dotted string the grammar
// assigns. The C++ scope type stays in scope/scope.h, and this plain
// Objective-C carries the two strings across to the Swift and back.
#ifndef TM_SCOPE_CONTEXT_H_7F1D4A86
#define TM_SCOPE_CONTEXT_H_7F1D4A86

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface TMScopeContext : NSObject
// Matches every scope, for when there is no text view to ask.
@property (class, readonly) TMScopeContext* wildcard;
+ (instancetype)contextWithLeft:(NSString*)left right:(NSString*)right;
@property (nonatomic, readonly) NSString* left;
@property (nonatomic, readonly) NSString* right;
@end

NS_ASSUME_NONNULL_END

#endif /* end of include guard: TM_SCOPE_CONTEXT_H_7F1D4A86 */
