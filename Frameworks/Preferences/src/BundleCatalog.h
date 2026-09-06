#import <Foundation/Foundation.h>
#import "CatalogBundle.h"

NS_ASSUME_NONNULL_BEGIN

// Plain Objective-C over the bundles manager for the Bundles pane: the catalog as snapshots, the
// install and uninstall actions, and one callback for any change, whether a new index arriving, an
// install finishing or the activity text moving on. The manager's own header carries C++ and cannot
// be seen from Swift.
@interface BundleCatalog : NSObject
@property (class, readonly) BundleCatalog* sharedInstance;

@property (nonatomic, readonly) NSArray<CatalogBundle*>* bundles;
@property (nonatomic, readonly) NSArray<NSString*>* categories; // Every category in the catalog, by name.
@property (nonatomic, readonly) BOOL isBusy;                    // An install is under way.
@property (nonatomic, readonly) NSString* activityText;         // What just happened, or when the index was last updated.
@property (nonatomic, copy, nullable) void (^changeHandler)(void);

- (void)install:(NSUUID*)identifier;
- (void)uninstall:(NSUUID*)identifier;

// Forgets what just happened, so the activity text goes back to the index date.
- (void)clearActivity;
@end

NS_ASSUME_NONNULL_END
