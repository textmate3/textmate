#import "CommitMessageView.h"
#import <OakTextView/OakDocumentView.h>
#import <document/OakDocument.h>
#import <bundles/bundles.h>
#import <ns/ns.h>

@interface CommitMessageView () <OakTextViewDelegate>
@property (nonatomic) OakDocumentView* documentView;
@property (nonatomic, copy) NSString* projectDirectory;
@end

@implementation CommitMessageView
+ (NSString*)fileTypeForSCMName:(NSString*)scmName
{
	if(scmName.length == 0)
		return @"text.plain";

	std::string const grammar = "text." + to_s(scmName) + "-commit";
	for(auto item : bundles::query(bundles::kFieldGrammarScope, grammar, scope::wildcard, bundles::kItemTypeGrammar))
		return to_ns(item->value_for_field(bundles::kFieldGrammarScope));

	return @"text.plain";
}

- (instancetype)initWithFrame:(NSRect)frame
{
	if(self = [super initWithFrame:frame])
	{
		_documentView = [[OakDocumentView alloc] initWithFrame:NSZeroRect];
		_documentView.hideStatusBar = YES;
		_documentView.textView.delegate = self;
		_documentView.translatesAutoresizingMaskIntoConstraints = NO;

		[self addSubview:_documentView];
		[NSLayoutConstraint activateConstraints:@[
			[_documentView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
			[_documentView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
			[_documentView.topAnchor constraintEqualToAnchor:self.topAnchor],
			[_documentView.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],
		]];
	}
	return self;
}

- (NSString*)content
{
	return _documentView.document.content ?: @"";
}

- (void)setContent:(NSString*)content
{
	[self setContent:content fileType:_documentView.document.fileType ?: @"text.plain" virtualPath:_documentView.document.virtualPath];
}

- (void)setContent:(NSString*)content fileType:(NSString*)fileType virtualPath:(NSString*)virtualPath
{
	OakDocument* document = [OakDocument documentWithString:content ?: @"" fileType:fileType customName:@"Commit Message"];
	document.virtualPath = virtualPath;
	_documentView.document = document;
	_projectDirectory = virtualPath.stringByDeletingLastPathComponent;
}

- (void)makeFirstResponder
{
	[self.window makeFirstResponder:_documentView.textView];
}

- (NSSize)intrinsicContentSize
{
	return NSMakeSize(NSViewNoIntrinsicMetric, NSViewNoIntrinsicMetric);
}

// A bundle item run from this window sees the project it is committing to.
- (std::map<std::string, std::string>)variables
{
	std::map<std::string, std::string> res;
	if(_projectDirectory)
		res["TM_PROJECT_DIRECTORY"] = to_s(_projectDirectory);
	return res;
}
@end
