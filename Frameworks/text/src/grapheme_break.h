#ifndef TEXT_GRAPHEME_BREAK_H
#define TEXT_GRAPHEME_BREAK_H

#include <cstdint>

// Grapheme cluster boundaries by Unicode's own rules, UAX #29 extended grapheme
// clusters, from tables script/generate_grapheme_tables writes out of the
// Unicode Character Database into grapheme_table.cc.
//
// The rules are templates over a code point iterator such as utf8::iterator_t,
// so they read the UTF-8 where it is with nothing copied or converted. Between
// two ASCII characters there is always a boundary, other than inside CR LF, so
// ASCII never reaches the table.

namespace grapheme
{
	// The grapheme cluster break value, in a code point's low four bits.
	enum : uint8_t { kOther, kCR, kLF, kControl, kExtend, kZWJ, kRegionalIndicator, kPrepend, kSpacingMark, kL, kV, kT, kLV, kLVT };

	uint8_t const kBreakMask            = 0x0F;
	uint8_t const kExtendedPictographic = 0x10;

	// The Indic conjunct break value, in bits 5 and 6.
	uint8_t const kConjunctMask      = 0x60;
	uint8_t const kConjunctConsonant = 0x20;
	uint8_t const kConjunctExtend    = 0x40;
	uint8_t const kConjunctLinker    = 0x60;

	extern char const* const kUnicodeVersion;
	extern uint8_t const kBlockIndex[];
	extern uint8_t const kBlocks[];

	inline uint8_t properties (uint32_t ch)
	{
		return ch < 0x110000 ? kBlocks[kBlockIndex[ch >> 8] * 256 + (ch & 0xFF)] : kOther;
	}

	inline uint8_t break_value (uint8_t props) { return props & kBreakMask; }
	inline uint8_t conjunct_value (uint8_t props) { return props & kConjunctMask; }
	inline bool is_control (uint8_t value) { return value == kCR || value == kLF || value == kControl; }

	namespace detail
	{
		// GB9c: a consonant, then marks and at least one linker, joins the consonant after it.
		// The code point before is an Indic conjunct extend or linker, and the one after a consonant.
		template <typename _Iter>
		bool joins_conjunct (_Iter const& first, _Iter before)
		{
			bool seenLinker = false;
			while(true)
			{
				uint8_t const conjunct = conjunct_value(properties(*before));
				if(conjunct == kConjunctLinker)
					seenLinker = true;
				else if(conjunct != kConjunctExtend)
					return conjunct == kConjunctConsonant && seenLinker;
				if(before == first)
					return false;
				--before;
			}
		}

		// GB11: an extended pictographic character, any extending marks, and a zero width joiner
		// join the extended pictographic character after them. The code point before is the joiner.
		template <typename _Iter>
		bool joins_pictographic (_Iter const& first, _Iter before)
		{
			while(before != first)
			{
				--before;
				uint8_t const props = properties(*before);
				if(break_value(props) != kExtend)
					return props & kExtendedPictographic;
			}
			return false;
		}

		// GB12 and GB13: regional indicators pair up from the start of the run. The code point
		// before is a regional indicator, and the one after joins it when the run so far is odd.
		template <typename _Iter>
		bool joins_regional_indicator (_Iter const& first, _Iter before)
		{
			size_t run = 1;
			while(before != first)
			{
				--before;
				if(break_value(properties(*before)) != kRegionalIndicator)
					break;
				++run;
			}
			return run % 2 == 1;
		}
	}

	// Whether a grapheme boundary falls between two code points inside the text: `lhs`, which
	// `before` points at, and `rhs` after it. The text begins at `first`, which the rules that
	// look further back stop at. A loop that has both code points at hand saves decoding them twice.
	template <typename _Iter>
	bool is_boundary_between (_Iter const& first, _Iter const& before, uint32_t lhs, uint32_t rhs)
	{
		// Below U+0300 the rules single out only the controls, which break anyway, and © and ®,
		// which are pictographic but join only after a zero width joiner, U+200D. So there is a
		// boundary everywhere but inside CR LF.
		if(lhs < 0x300 && rhs < 0x300)
			return lhs != '\r' || rhs != '\n';

		uint8_t const lhsProps = properties(lhs), rhsProps = properties(rhs);
		uint8_t const lhsBreak = break_value(lhsProps), rhsBreak = break_value(rhsProps);

		if(lhsBreak == kCR && rhsBreak == kLF) // GB3
			return false;
		if(is_control(lhsBreak) || is_control(rhsBreak)) // GB4, GB5
			return true;
		if(lhsBreak == kL && (rhsBreak == kL || rhsBreak == kV || rhsBreak == kLV || rhsBreak == kLVT)) // GB6
			return false;
		if((lhsBreak == kLV || lhsBreak == kV) && (rhsBreak == kV || rhsBreak == kT)) // GB7
			return false;
		if((lhsBreak == kLVT || lhsBreak == kT) && rhsBreak == kT) // GB8
			return false;
		if(rhsBreak == kExtend || rhsBreak == kZWJ || rhsBreak == kSpacingMark) // GB9, GB9a
			return false;
		if(lhsBreak == kPrepend) // GB9b
			return false;
		if(conjunct_value(rhsProps) == kConjunctConsonant && (conjunct_value(lhsProps) == kConjunctExtend || conjunct_value(lhsProps) == kConjunctLinker) && detail::joins_conjunct(first, before)) // GB9c
			return false;
		if(lhsBreak == kZWJ && (rhsProps & kExtendedPictographic) && detail::joins_pictographic(first, before)) // GB11
			return false;
		if(lhsBreak == kRegionalIndicator && rhsBreak == kRegionalIndicator && detail::joins_regional_indicator(first, before)) // GB12, GB13
			return false;
		return true; // GB999
	}

	// Whether a grapheme boundary falls before the code point at `at`, in the text from `first` to `last`.
	template <typename _Iter>
	bool is_boundary (_Iter const& first, _Iter const& at, _Iter const& last)
	{
		if(at == first || at == last) // GB1, GB2
			return true;

		_Iter before = at;
		--before;
		return is_boundary_between(first, before, *before, *at);
	}

} /* grapheme */

#endif /* end of include guard: TEXT_GRAPHEME_BREAK_H */
