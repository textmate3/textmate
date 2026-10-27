// Stands in for the Find window: answers with the operation and options it was
// given, and keeps what it is told was found. The class is declared and
// implemented here because the test runner places each test body inside a
// namespace, where an Objective-C class cannot be declared, and lifts only
// the imports out of it.
#import <OakFoundation/OakFindProtocol.h>

@interface HOTestFindServer : NSObject <OakFindServerProtocol>
@property (nonatomic) find_operation_t findOperation;
@property (nonatomic) NSString* findString;
@property (nonatomic) NSString* replaceString;
@property (nonatomic) find::options_t findOptions;
@property (nonatomic) NSUInteger reportedCount;
@property (nonatomic) NSString* reportedString;
@property (nonatomic) BOOL reportedPositionIsUndefined;
@end

@implementation HOTestFindServer
- (void)didFind:(NSUInteger)aNumber occurrencesOf:(NSString*)aFindString atPosition:(text::pos_t const&)aPosition wrapped:(BOOL)didWrap
{
	self.reportedCount = aNumber;
	self.reportedString = aFindString;
	self.reportedPositionIsUndefined = !aPosition;
}

- (void)didReplace:(NSUInteger)aNumber occurrencesOf:(NSString*)aFindString with:(NSString*)aReplacementString
{
}
@end
