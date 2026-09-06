#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

// One bundle in the catalog, as the Bundles pane shows it: a snapshot of the bundles manager's
// record, taken whenever something changes. Swift never sees the manager's own class, whose name
// Foundation already uses for something else.
@interface CatalogBundle : NSObject
@property (nonatomic, readonly) NSUUID* identifier;
@property (nonatomic, readonly) NSString* name;
@property (nonatomic, readonly, nullable) NSString* category;
@property (nonatomic, readonly) NSString* summary; // The description with its markup and whitespace folded away.
@property (nonatomic, readonly, nullable) NSDate* updated;
@property (nonatomic, readonly, nullable) NSURL* link;
@property (nonatomic, readonly) BOOL isInstalled;
@property (nonatomic, readonly) BOOL isInstalling;
@property (nonatomic, readonly) BOOL isMandatory;
@end

NS_ASSUME_NONNULL_END
