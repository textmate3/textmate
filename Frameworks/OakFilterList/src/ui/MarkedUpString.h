// A chooser row's text with the parts the filter matched marked up: a
// background and an underline on each matched range. The ranges are what the
// ranker reports, so this is C++ and lives apart from the chooser's header,
// which Swift has to be able to read.
#ifndef MARKED_UP_STRING_H_3F7A2C19
#define MARKED_UP_STRING_H_3F7A2C19

#include <string>
#include <vector>

NSMutableAttributedString* CreateAttributedStringWithMarkedUpRanges (std::string const& in, std::vector< std::pair<size_t, size_t> > const& ranges, NSLineBreakMode lineBreakMode = NSLineBreakByTruncatingMiddle);

#endif /* end of include guard: MARKED_UP_STRING_H_3F7A2C19 */
