#import "EncodingView.h"
#import "document-Swift.h"
#import <OakFoundation/NSString Additions.h>
#import <OakAppKit/OakEncodingPopUpButton.h>
#import <text/hexdump.h>
#import <text/utf8.h>
#import <text/transcode.h>
#import <oak/oak.h>
#import <oak/debug.h>
#import <ns/ns.h>

template <typename _InputIter>
size_t newline_size (_InputIter first, _InputIter const& last)
{
	for(auto str : { "\r\n", "\n", "\r" })
	{
		if(oak::has_prefix(first, last, str, str + strlen(str)))
			return strlen(str);
	}
	return 0;
}

static void append (NSMutableAttributedString* dst, char const* first, char const* last, NSDictionary* styles)
{
	NSString* str = [NSString stringWithUTF8String:first length:last - first] ?: @"�";
	[dst appendAttributedString:[[NSAttributedString alloc] initWithString:str attributes:styles]];
}

static NSAttributedString* convert_and_highlight (char const* first, char const* last, std::string const& encodeFrom = "UTF-8", std::string const& encodeTo = "UTF-8", bool* success = nullptr)
{
	std::set<ptrdiff_t> offsets;
	auto lastPos = first;
	for(auto it = first; it != last; ++it)
	{
		if(*it > 0x7F)
		{
			if(++lastPos != it)
				offsets.insert(std::distance(first, it));
			lastPos = it;
		}
	}

	text::transcode_t transcode(encodeFrom, encodeTo);
	if(!transcode)
		return nil;

	std::string dst;

	std::set<size_t> decodedOffsets;
	size_t from = 0;
	for(size_t to : offsets)
	{
		transcode(first + from, first + to, back_inserter(dst));
		decodedOffsets.insert(dst.size());
		from = to;
	}
	transcode(transcode(first + from, last, back_inserter(dst)));

	if(success)
		*success = transcode.invalid_count() == 0;

	NSMutableAttributedString* output = [[NSMutableAttributedString alloc] init];

	NSDictionary* regularStyle = @{
		NSFontAttributeName:            [NSFont userFixedPitchFontOfSize:0],
		NSForegroundColorAttributeName: [NSColor grayColor],
	};
	NSDictionary* lineHighlightStyle = @{
		NSFontAttributeName:            [NSFont userFixedPitchFontOfSize:0],
		NSForegroundColorAttributeName: [NSColor grayColor],
		NSBackgroundColorAttributeName: [NSColor colorWithCalibratedWhite:0.9 alpha:1],
	};
	NSDictionary* characterHighlightStyle = @{
		NSFontAttributeName:            [NSFont userFixedPitchFontOfSize:0],
		NSBackgroundColorAttributeName: [NSColor colorWithCalibratedWhite:0.9 alpha:1],
	};

	size_t bol = 0;
	auto offset = decodedOffsets.begin();
	for(size_t eol = 0; eol < dst.size(); ++eol)
	{
		static std::string const newlines[] = { "\r\n", "\n", "\r" };

		auto it = std::find_if(std::begin(newlines), std::end(newlines), [&](std::string const& str){ return oak::has_prefix(dst.begin() + eol, dst.end(), str.begin(), str.end()); });
		if(it == std::end(newlines))
			continue;

		size_t crlf = it->size();
		if(offset != decodedOffsets.end() && *offset < eol)
		{
			while(offset != decodedOffsets.end() && *offset < eol)
			{
				if(*offset < bol)
				{
					++offset;
					continue;
				}

				append(output, dst.data() + bol, dst.data() + *offset, lineHighlightStyle);

				bol = *offset;
				while(bol != dst.size() && dst[bol] > 0x7F)
					++bol;

				append(output, dst.data() + *offset, dst.data() + bol, characterHighlightStyle);

				++offset;
			}
			append(output, dst.data() + bol, dst.data() + eol + crlf, lineHighlightStyle);
		}
		else
		{
			append(output, dst.data() + bol, dst.data() + eol + crlf, regularStyle);
		}

		bol = eol + crlf;
		eol += crlf - 1;
	}

	if(bol < dst.size())
		append(output, dst.data() + bol, dst.data() + dst.size(), regularStyle);

	return output;
}

// The sheet's content is SwiftUI, behind OakEncodingChooserController. This
// controller owns the bytes and the transcoding: it hands the chooser the
// encodings to offer and a preview for the chosen one, and reads the answer
// back when the person opens or cancels.
@interface EncodingWindowController () <NSWindowDelegate>
{
	NSData* _data;
}
@property (nonatomic) OakEncodingChooserController* chooser;
@end

@implementation EncodingWindowController
- (instancetype)initWithData:(NSData*)data
{
	if(self = [super initWithWindow:[[NSWindow alloc] initWithContentRect:NSZeroRect styleMask:(NSWindowStyleMaskTitled|NSWindowStyleMaskClosable|NSWindowStyleMaskResizable|NSWindowStyleMaskMiniaturizable) backing:NSBackingStoreBuffered defer:NO]])
	{
		_data        = data;
		_encoding    = @"ISO-8859-1";
		_displayName = @"untitled";

		self.chooser = [[OakEncodingChooserController alloc] init];
		self.chooser.displayName      = _displayName;
		self.chooser.selectedEncoding = _encoding;
		self.chooser.trainClassifier  = YES;
		[self updateAvailableEncodings];

		__weak EncodingWindowController* weakSelf = self;
		self.chooser.selectionHandler = ^(NSString* encoding){ weakSelf.encoding = encoding; };
		self.chooser.openHandler      = ^{ [weakSelf performOpenDocument:nil]; };
		self.chooser.cancelHandler    = ^{ [weakSelf performCancelOperation:nil]; };

		self.window.contentViewController = self.chooser;
		self.window.delegate = self;

		[self updateTextView];
	}
	return self;
}

- (void)beginSheetModalForWindow:(NSWindow*)aWindow completionHandler:(void(^)(NSModalResponse))callback
{
	[self.window layoutIfNeeded];
	[aWindow beginSheet:self.window completionHandler:callback];
}

// The user's list, plus the current encoding when it is not on that list, so
// a guessed encoding can always be shown as selected.
- (void)updateAvailableEncodings
{
	NSMutableArray<NSString*>* codes = [OakEncodingPopUpButton.availableEncodingCodes mutableCopy];
	NSMutableArray<NSString*>* names = [OakEncodingPopUpButton.availableEncodingNames mutableCopy];
	if(_encoding && ![codes containsObject:_encoding])
	{
		[codes addObject:_encoding];
		[names addObject:_encoding];
	}
	[self.chooser setEncodingsWithCodes:codes names:names];
}

- (void)setDisplayName:(NSString*)aString
{
	_displayName = aString;
	self.chooser.displayName = aString;
}

- (void)updateTextView
{
	bool couldConvert = true;
	char const* bytes = (char const*)_data.bytes;
	self.chooser.preview = convert_and_highlight(bytes, bytes + MIN(_data.length, 256*1024), to_s(self.encodingNoBOM), "UTF-8", &couldConvert) ?: [[NSAttributedString alloc] init];
	self.acceptableEncoding = couldConvert;
}

- (void)setEncoding:(NSString*)anEncoding
{
	if([_encoding isEqualToString:anEncoding])
		return;
	_encoding = anEncoding;
	[self updateAvailableEncodings];
	self.chooser.selectedEncoding = anEncoding;
	[self updateTextView];
}

- (NSString*)encodingNoBOM
{
	return [_encoding stringByReplacingOccurrencesOfString:@"//BOM" withString:@""];
}

- (void)setAcceptableEncoding:(BOOL)flag
{
	_acceptableEncoding = flag;
	self.chooser.acceptableEncoding = flag;
}

- (BOOL)trainClassifier
{
	return self.chooser.trainClassifier;
}

- (void)setTrainClassifier:(BOOL)flag
{
	self.chooser.trainClassifier = flag;
}

- (void)cleanup
{
	self.chooser.selectionHandler = nil;
	self.chooser.openHandler      = nil;
	self.chooser.cancelHandler    = nil;
}

- (IBAction)performOpenDocument:(id)sender
{
	[self.window.sheetParent endSheet:self.window returnCode:NSModalResponseOK];
	[self cleanup];
}

- (IBAction)performCancelOperation:(id)sender
{
	[self.window.sheetParent endSheet:self.window returnCode:NSModalResponseCancel];
	[self cleanup];
}
@end
