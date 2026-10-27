#import "TMScopeContext.h"
#import <scope/scope.h>
#import <ns/ns.h>

@interface TMScopeContext ()
@property (nonatomic) NSString* left;
@property (nonatomic) NSString* right;
@end

@implementation TMScopeContext
+ (TMScopeContext*)wildcard
{
	return [self contextWithLeft:to_ns(to_s(scope::wildcard)) right:to_ns(to_s(scope::wildcard))];
}

+ (instancetype)contextWithLeft:(NSString*)left right:(NSString*)right
{
	TMScopeContext* res = [[self alloc] init];
	res.left  = left;
	res.right = right;
	return res;
}
@end

scope::context_t TMScopeContextToCxx (TMScopeContext* context)
{
	return scope::context_t(scope::scope_t(to_s(context.left)), scope::scope_t(to_s(context.right)));
}
