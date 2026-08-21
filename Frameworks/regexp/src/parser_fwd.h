#ifndef PARSER_FWD_H_T20BLRIP
#define PARSER_FWD_H_T20BLRIP

namespace parser
{
	// node_t is a std::variant over the node structs. std::variant cannot
	// hold incomplete alternatives (boost::variant used recursive_wrapper
	// for that), so the variant itself is defined in parser.h after the
	// structs are complete; here only the name and the node list exist.
	// std::vector supports incomplete element types since C++17.
	struct node_t;
	typedef std::vector<node_t> nodes_t;

} /* parser */

#endif /* end of include guard: PARSER_FWD_H_T20BLRIP */
