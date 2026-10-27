// A guard by name rather than by file, since this header reaches a compile unit
// twice: from the include farm, and through a Swift header, which carries its
// bridging header's imports by their source path.
#ifndef NSCOLOR_ADDITIONS_H_8E4B1D27
#define NSCOLOR_ADDITIONS_H_8E4B1D27

NS_ASSUME_NONNULL_BEGIN

id TMMakeAttributedStringWithBackgroundStyle (id objectValue, NSBackgroundStyle backgroundStyle);

@interface NSColor (TMColorAdditions)
+ (NSColor*)tmMatchedTextBackgroundColor;
+ (NSColor*)tmMatchedTextUnderlineColor;
+ (NSColor*)tmMatchedTextSelectedBackgroundColor;
+ (NSColor*)tmMatchedTextSelectedUnderlineColor;
@end

NS_ASSUME_NONNULL_END

#endif /* end of include guard: NSCOLOR_ADDITIONS_H_8E4B1D27 */
