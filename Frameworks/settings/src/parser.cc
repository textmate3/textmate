// file:          ( «line» )*
// line:          ( «comment» | ( «section» | «assignment» )? ( «comment» )? ) ( '\n' | EOF )
// section:       '[' «name» ( ( ";" | "," ) «name» )* ']'
// name:          ( /[^\] \t\n]/ | /\\[\] \t\n\\]/ )+
// assignment:    «key» '=' «value»
// key:           ( /[^= \t\n]/ | /\\[= \t\n\\]/ )+
// value:         ( «single_string» | «double_string» | «bare_string» )
// single_string: "'" ( /[^']/ | /\\['\\]/ )* "'"
// double_string: '"' ( /[^"]/ | /\\["\\]/ )* '"'
// bare_string:   ( /[^ \t\n]/ | /\\[ \t\n\\]/ )+
// comment:       '#' ( /[^\n]/ )*

#include "parser.h"

static bool backtrack (char const*& p, char const* bt)
{
	return (p = bt), false;
}

static bool parse_ws (char const*& p, char const* pe)
{
	while(p != pe && strchr(" \t", *p))
		++p;
	return true;
}

static bool parse_char (char const*& p, char const*& pe, char const* ch)
{
	return parse_ws(p, pe) && p != pe && strchr(ch, *p) ? (++p, true) : false;
}

static bool parse_until (char const*& p, char const*& pe, char const* stopChars, std::string& res)
{
	res.clear();
	for(; p != pe && !strchr(stopChars, *p); ++p)
	{
		if(*p == '\\' && p+1 != pe && (p[1] == '\\' || strchr(stopChars, p[1])))
			++p;
		res += *p;
	}
	return true;
}

static bool parse_comment (char const*& p, char const*& pe)
{
	std::string commentString;
	if(parse_char(p, pe, "#") && !parse_until(p, pe, "\n", commentString))
		p = pe; // failed to find ‘\n’ (at EOF) so ‘parse_until’ backtracked to start of comment
	return true;
}

static bool parse_string_single (char const*& p, char const* pe, std::string& res)
{
	char const* bt = p;
	return parse_ws(p, pe) && parse_char(p, pe, "'") && parse_until(p, pe, "'\n", res) && parse_char(p, pe, "'") || backtrack(p, bt);
}

static bool parse_string_double (char const*& p, char const* pe, std::string& res)
{
	char const* bt = p;
	return parse_ws(p, pe) && parse_char(p, pe, "\"") && parse_until(p, pe, "\"\n", res) && parse_char(p, pe, "\"") || backtrack(p, bt);
}

static bool parse_string_unquoted (char const*& p, char const* pe, std::string& res)
{
	char const* bt = p;
	return parse_ws(p, pe) && p != pe && *p != '\n' && parse_until(p, pe, " \t\n", res) && !res.empty() || backtrack(p, bt);
}

static bool parse_string (char const*& p, char const* pe, std::string& res)
{
	return parse_string_single(p, pe, res) || parse_string_double(p, pe, res) || parse_string_unquoted(p, pe, res);
}

static bool parse_key (char const*& p, char const* pe, std::string& res)
{
	char const* bt = p;
	bool match = parse_ws(p, pe) && p != pe && *p != '\n' && parse_until(p, pe, "= \t\n", res) && !res.empty() || backtrack(p, bt);
	return match;
}

static bool parse_assignment (char const*& p, char const* pe, std::pair<std::string, std::string>& res)
{
	char const* bt = p;
	return parse_key(p, pe, res.first) && parse_char(p, pe, "=") && parse_string(p, pe, res.second) || backtrack(p, bt);
}

// A name in a header: a quoted string, which keeps everything inside its
// quotes and is how a scope selector carries its own commas, or a bare run
// up to a separator, a semicolon or a comma, the closing bracket, or
// whitespace. A comma inside braces is kept, since a glob writes its
// alternatives that way, tests/t_*.{cc,mm}. A backslash escapes a stop
// character, as it does elsewhere in the file.
static bool parse_header_name (char const*& p, char const* pe, std::string& res)
{
	if(parse_string_single(p, pe, res) || parse_string_double(p, pe, res))
		return true;

	parse_ws(p, pe);
	res.clear();
	size_t depth = 0;
	for(; p != pe; ++p)
	{
		if(*p == '\\' && p+1 != pe && (p[1] == '\\' || strchr(";,] \t\n{}", p[1])))
		{
			res += *++p;
			continue;
		}

		if(*p == '{')
			++depth;
		else if(*p == '}' && depth != 0)
			--depth;
		else if(depth == 0 && strchr(";,] \t\n", *p))
			break;
		res += *p;
	}
	return true;
}

// Names are separated by a semicolon or a comma. The semicolon is the one
// the format always had. The comma is accepted because it is what people
// write, since a scope selector and a glob both use commas of their own, and
// an unquoted comma between names can mean nothing else in a header.
static bool parse_header (char const*& p, char const* pe, std::vector<std::string>& res)
{
	char const* bt = p;
	if(parse_char(p, pe, "["))
	{
		std::string name;
		while(parse_header_name(p, pe, name))
		{
			res.push_back(name);
			if(parse_char(p, pe, "]"))
				return true;
			if(!parse_char(p, pe, ";") && !parse_char(p, pe, ","))
				break;
		}
	}
	res.clear();
	return backtrack(p, bt);
}

static bool parse_line (char const*& p, char const* pe, ini_file_t& res, int n = 0)
{
	std::vector<std::string> header;
	std::pair<std::string, std::string> assignment;

	char const* bt = p;
	parse_ws(p, pe);
	parse_comment(p, pe);

	if(parse_header(p, pe, header))
		res.new_section(header);
	else if(parse_assignment(p, pe, assignment))
		res.insert_value(assignment.first, assignment.second, n);
	else if(p != pe && *p == '[')
	{
		// A header that could not be read still opens a section, one that
		// applies nowhere. Otherwise the settings under it would land in
		// whatever section came before, which for a header near the top of
		// a file is the root, and they would apply to every file. The error
		// below says what was wrong with it, and the header is kept so the
		// application can say so where the person will see it.
		char const* lineEnd = strchr(p, '\n') ?: pe;
		std::string header(p, lineEnd);
		while(!header.empty() && isspace(header.back()))
			header.pop_back();
		res.new_malformed_section(header, n);
	}

	if(parse_comment(p, pe) && (p == pe || parse_char(p, pe, "\n")))
		return true;

	std::string trailing;
	parse_until(p, pe, "\n", trailing);
	os_log_error(OS_LOG_DEFAULT, "%{public}s:%d: error: incorrect syntax ‘%.*s’", res.path.c_str(), n, (int)((strchr(bt, '\n') ?: pe) - bt), bt);
	parse_char(p, pe, "\n");
	return false;
}

char const* parse_ini (char const* p, char const* pe, ini_file_t& res)
{
	for(int n = 1; p != pe; ++n)
	{
		// fprintf(stderr, "parse line %d: ‘%.*s’ (%s)\n", n, (strchr(p, '\n') ?: pe) - p, p, res.path.c_str());
		parse_line(p, pe, res, n);
	}
	return p;
}
