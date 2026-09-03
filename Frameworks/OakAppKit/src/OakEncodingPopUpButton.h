@interface OakEncodingPopUpButton : NSPopUpButton
@property (nonatomic) NSString* encoding;

// The encodings the user has chosen to see, in the order the pop up lists them:
// each an iconv name and the name a person reads, so other choosers can offer
// the same list without being a pop up.
+ (NSArray<NSString*>*)availableEncodingCodes;
+ (NSArray<NSString*>*)availableEncodingNames;
@end
