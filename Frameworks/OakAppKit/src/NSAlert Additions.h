#import <oak/print_system_error.h>

@interface NSAlert (Other)
+ (NSAlert*)tmAlertWithMessageText:(NSString*)messageText informativeText:(NSString*)informativeText buttons:(NSString*)firstTitle, ...;
- (void)addButtons:(NSString*)firstTitle, ...;
@end
