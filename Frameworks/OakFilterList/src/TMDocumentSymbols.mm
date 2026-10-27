#import "TMDocumentSymbols.h"
#import <document/OakDocument.h>
#import <ns/ns.h>

@interface TMTextPosition ()
- (instancetype)initWithPosition:(text::pos_t const&)position;
@end

@implementation TMTextPosition
- (instancetype)initWithPosition:(text::pos_t const&)position
{
	if(self = [super init])
	{
		_line   = position.line;
		_column = position.column;
		_string = to_ns(position);
	}
	return self;
}

- (NSComparisonResult)compare:(TMTextPosition*)other
{
	if(_line != other.line)
		return _line < other.line ? NSOrderedAscending : NSOrderedDescending;
	if(_column != other.column)
		return _column < other.column ? NSOrderedAscending : NSOrderedDescending;
	return NSOrderedSame;
}
@end

@interface TMDocumentSymbol ()
@property (nonatomic) TMTextPosition* position;
@property (nonatomic) NSString* name;
@end

@implementation TMDocumentSymbol
@end

@implementation TMDocumentSymbols
+ (NSArray<TMDocumentSymbol*>*)symbolsInDocument:(id)document
{
	NSMutableArray<TMDocumentSymbol*>* res = [NSMutableArray array];
	if([document isKindOfClass:OakDocument.class])
	{
		[(OakDocument*)document enumerateSymbolsUsingBlock:^(text::pos_t const& position, NSString* name){
			TMDocumentSymbol* symbol = [[TMDocumentSymbol alloc] init];
			symbol.position = [[TMTextPosition alloc] initWithPosition:position];
			symbol.name     = name;
			[res addObject:symbol];
		}];
	}
	return res;
}

+ (NSArray<TMTextPosition*>*)rangeStartsInSelectionString:(NSString*)selectionString
{
	NSMutableArray<TMTextPosition*>* res = [NSMutableArray array];
	for(text::range_t const& range : text::selection_t(to_s(selectionString)))
		[res addObject:[[TMTextPosition alloc] initWithPosition:range.min()]];
	return res;
}

@end
