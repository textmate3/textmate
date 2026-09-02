#import "SoftwareUpdatePreferences.h"
#import "Keys.h"
#import <OakAppKit/NSImage Additions.h>
#import <OakAppKit/OakUIConstructionFunctions.h>
#import <MenuBuilder/MenuBuilder.h>

// Sparkle reads these user defaults, so the pane binds straight to them and no reference to the
// updater object is needed here. The check itself is a nil-target action that travels the responder
// chain to the updater controller.
static NSString* const kSparkleEnableAutomaticChecksKey = @"SUEnableAutomaticChecks";
static NSString* const kSparkleAutomaticallyUpdateKey   = @"SUAutomaticallyUpdate";
static NSString* const kSparkleLastCheckTimeKey         = @"SULastCheckTime";

@interface SoftwareUpdatePreferences ()
{
	id _relativeDateUserDefaultsObserver;
	NSTimer* _relativeDateUpdateTimer;
}
@property (nonatomic) NSString* relativeStringForLastCheck;
@end

@implementation SoftwareUpdatePreferences
+ (NSSet*)keyPathsForValuesAffectingLastCheckDescription { return [NSSet setWithObjects:@"relativeStringForLastCheck", nil]; }

- (id)init
{
	return self = [super initWithNibName:nil label:@"Software Update" image:[NSImage imageNamed:@"Software Update" inSameBundleAsClass:[self class]]];
}

- (NSString*)lastCheckDescription
{
	return _relativeStringForLastCheck ?: @"Never";
}

- (void)performUpdateCheck:(id)sender
{
	[NSApp sendAction:@selector(checkForUpdates:) to:nil from:sender];
}

- (NSString*)relativeStringForDate:(NSDate*)date
{
	if(!date)
		return nil;

	return -[date timeIntervalSinceNow] < 5 ? @"Just now" : [[[NSRelativeDateTimeFormatter alloc] init] localizedStringForDate:date relativeToDate:NSDate.now];
}

- (void)viewWillAppear
{
	_relativeDateUserDefaultsObserver = [NSNotificationCenter.defaultCenter addObserverForName:NSUserDefaultsDidChangeNotification object:NSUserDefaults.standardUserDefaults queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification* notification){
		self.relativeStringForLastCheck = [self relativeStringForDate:[NSUserDefaults.standardUserDefaults objectForKey:kSparkleLastCheckTimeKey]];
	}];

	_relativeDateUpdateTimer = [NSTimer scheduledTimerWithTimeInterval:60 repeats:YES block:^(NSTimer* timer){
		self.relativeStringForLastCheck = [self relativeStringForDate:[NSUserDefaults.standardUserDefaults objectForKey:kSparkleLastCheckTimeKey]];
	}];

	self.relativeStringForLastCheck = [self relativeStringForDate:[NSUserDefaults.standardUserDefaults objectForKey:kSparkleLastCheckTimeKey]];
}

- (void)viewDidDisappear
{
	[_relativeDateUpdateTimer invalidate];
	[NSNotificationCenter.defaultCenter removeObserver:_relativeDateUserDefaultsObserver];
}

- (void)loadView
{
	NSButton* watchForUpdatesCheckBox      = OakCreateCheckBox(@"Check for updates automatically");
	NSButton* askBeforeDownloadingCheckBox = OakCreateCheckBox(@"Ask before downloading updates");

	NSTextField* lastCheckTextField        = OakCreateLabel(@"Some time ago");
	NSButton* checkNowButton               = [NSButton buttonWithTitle:@"Check Now" target:self action:@selector(performUpdateCheck:)];

	NSGridView* gridView = [NSGridView gridViewWithViews:@[
		@[ OakCreateLabel(@"Software update:"),        watchForUpdatesCheckBox           ],
		@[ NSGridCell.emptyContentView,                askBeforeDownloadingCheckBox      ],
		@[ ],
		@[ OakCreateLabel(@"Last check:"),             lastCheckTextField                ],
		@[ NSGridCell.emptyContentView,                checkNowButton                    ],
	]];

	self.view = OakSetupGridViewWithSeparators(gridView, { 2 });

	[watchForUpdatesCheckBox      bind:NSValueBinding   toObject:NSUserDefaultsController.sharedUserDefaultsController withKeyPath:[NSString stringWithFormat:@"values.%@", kSparkleEnableAutomaticChecksKey]            options:nil];
	[askBeforeDownloadingCheckBox bind:NSValueBinding   toObject:NSUserDefaultsController.sharedUserDefaultsController withKeyPath:[NSString stringWithFormat:@"values.%@", kSparkleAutomaticallyUpdateKey]              options:@{ NSValueTransformerNameBindingOption: NSNegateBooleanTransformerName }];
	[lastCheckTextField           bind:NSValueBinding   toObject:self                                                  withKeyPath:@"lastCheckDescription"                                                              options:nil];

	[askBeforeDownloadingCheckBox bind:NSEnabledBinding toObject:NSUserDefaultsController.sharedUserDefaultsController withKeyPath:[NSString stringWithFormat:@"values.%@", kSparkleEnableAutomaticChecksKey]            options:nil];
}
@end
