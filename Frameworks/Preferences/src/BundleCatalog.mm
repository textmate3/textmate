#import "BundleCatalog.h"
#import <BundlesManager/BundlesManager.h>

// Declared in Bundle.mm without a place in its header.
@interface Bundle (Summary)
- (NSString*)textSummary;
@end

// ==================
// = CatalogBundle =
// ==================

@interface CatalogBundle ()
- (instancetype)initWithBundle:(Bundle*)bundle installing:(BOOL)installing;
@end

@implementation CatalogBundle
- (instancetype)initWithBundle:(Bundle*)bundle installing:(BOOL)installing
{
	if(self = [super init])
	{
		_identifier   = bundle.identifier;
		_name         = bundle.name ?: @"";
		_category     = bundle.category;
		_summary      = bundle.textSummary ?: @"";
		_updated      = bundle.downloadLastUpdated;
		_link         = bundle.htmlURL;
		_isInstalled  = bundle.isInstalled;
		_isInstalling = installing;
		_isMandatory  = bundle.isMandatory;
	}
	return self;
}
@end

// =================
// = BundleCatalog =
// =================

static void* kBundlesContext   = &kBundlesContext;
static void* kInstalledContext = &kInstalledContext;

@interface BundleCatalog ()
@property (nonatomic) NSArray<CatalogBundle*>* bundles;
@property (nonatomic) NSArray<NSString*>* categories;
@property (nonatomic) NSMutableSet<NSUUID*>* installing;
@property (nonatomic, nullable) NSString* lastActivity;
@property (nonatomic) NSArray<Bundle*>* observedBundles;
@end

@implementation BundleCatalog
+ (instancetype)sharedInstance
{
	static BundleCatalog* sharedInstance = [self new];
	return sharedInstance;
}

- (instancetype)init
{
	if(self = [super init])
	{
		_bundles         = @[ ];
		_categories      = @[ ];
		_installing      = [NSMutableSet set];
		_observedBundles = @[ ];
		[BundlesManager.sharedInstance addObserver:self forKeyPath:@"bundles" options:NSKeyValueObservingOptionInitial context:kBundlesContext];
	}
	return self;
}

- (void)observeValueForKeyPath:(NSString*)keyPath ofObject:(id)object change:(NSDictionary*)change context:(void*)context
{
	if(context == kBundlesContext)
	{
		// The list itself changed, so the installed flags to watch changed with it.
		for(Bundle* bundle in _observedBundles)
			[bundle removeObserver:self forKeyPath:@"installed" context:kInstalledContext];
		_observedBundles = BundlesManager.sharedInstance.bundles ?: @[ ];
		for(Bundle* bundle in _observedBundles)
			[bundle addObserver:self forKeyPath:@"installed" options:0 context:kInstalledContext];
		[self refresh];
	}
	else if(context == kInstalledContext)
	{
		[self refresh];
	}
	else
	{
		[super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
	}
}

- (void)refresh
{
	NSMutableArray<CatalogBundle*>* bundles = [NSMutableArray array];
	NSMutableSet<NSString*>* categories = [NSMutableSet set];
	for(Bundle* bundle in _observedBundles)
	{
		[bundles addObject:[[CatalogBundle alloc] initWithBundle:bundle installing:[_installing containsObject:bundle.identifier]]];
		if(bundle.category)
			[categories addObject:bundle.category];
	}
	self.bundles    = bundles;
	self.categories = [categories.allObjects sortedArrayUsingSelector:@selector(localizedCompare:)];

	if(_changeHandler)
	{
		if(NSThread.isMainThread)
				_changeHandler();
		else	dispatch_async(dispatch_get_main_queue(), _changeHandler);
	}
}

- (BOOL)isBusy
{
	return _installing.count != 0;
}

- (NSString*)activityText
{
	if(_lastActivity)
		return _lastActivity;

	if(NSDate* date = [NSUserDefaults.standardUserDefaults objectForKey:kUserDefaultsLastBundleUpdateCheckKey])
	{
		NSString* dateString = -[date timeIntervalSinceNow] < 5 ? @"Just now" : [[[NSRelativeDateTimeFormatter alloc] init] localizedStringForDate:date relativeToDate:NSDate.now];
		return [NSString stringWithFormat:@"Bundle index last updated: %@", dateString];
	}

	return @"";
}

- (void)clearActivity
{
	_lastActivity = nil;
}

- (Bundle*)bundleWithIdentifier:(NSUUID*)identifier
{
	for(Bundle* bundle in BundlesManager.sharedInstance.bundles)
	{
		if([bundle.identifier isEqual:identifier])
			return bundle;
	}
	return nil;
}

- (void)install:(NSUUID*)identifier
{
	Bundle* bundle = [self bundleWithIdentifier:identifier];
	if(!bundle || [_installing containsObject:identifier])
		return;

	[_installing addObject:identifier];
	_lastActivity = [NSString stringWithFormat:@"Installing ‘%@’ bundle…", bundle.name];
	[self refresh];

	[BundlesManager.sharedInstance installBundles:@[ bundle ] completionHandler:^(NSArray<Bundle*>* bundles){
		if(!bundle.installed)
			self.lastActivity = [NSString stringWithFormat:@"Error installing ‘%@’ bundle.", bundle.name];
		else if(bundles.count == 1)
			self.lastActivity = [NSString stringWithFormat:@"Installed ‘%@’ bundle.", bundle.name];
		else if(bundles.count == 2)
			self.lastActivity = [NSString stringWithFormat:@"Installed ‘%@’ bundle and one dependency.", bundle.name];
		else
			self.lastActivity = [NSString stringWithFormat:@"Installed ‘%@’ bundle and %ld dependencies.", bundle.name, bundles.count-1];

		[self.installing removeObject:identifier];
		[self refresh];
	}];
}

- (void)uninstall:(NSUUID*)identifier
{
	Bundle* bundle = [self bundleWithIdentifier:identifier];
	if(!bundle)
		return;

	[BundlesManager.sharedInstance uninstallBundle:bundle];
	_lastActivity = [NSString stringWithFormat:@"Uninstalled ‘%@’ bundle.", bundle.name];
	[self refresh];
}
@end
