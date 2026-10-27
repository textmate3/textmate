#ifndef INI_PARSER_H_LJ9XOMJG
#define INI_PARSER_H_LJ9XOMJG

struct ini_file_t
{
	struct section_t
	{
		section_t (std::vector<std::string> const& names) : names(names) { }

		struct value_t
		{
			value_t (std::string const& name, std::string const& value, size_t lineNumber) : name(name), value(value), line_number(lineNumber) { }
			std::string name, value;
			size_t line_number;
		};

		std::vector<std::string> names;
		std::vector<value_t> values;

		// A header that could not be read. The values under it are kept here so
		// that they apply nowhere, rather than to whatever section came before.
		// The header's text and line are kept so the person can be told which one.
		bool malformed = false;
		std::string header;
		size_t line_number = 0;
	};

	ini_file_t (std::string const& path) : path(path) { }

	void new_section (std::vector<std::string> const& names)
	{
		sections.emplace_back(names);
	}

	void new_malformed_section (std::string const& header, size_t lineNumber)
	{
		sections.emplace_back(std::vector<std::string>());
		sections.back().malformed   = true;
		sections.back().header      = header;
		sections.back().line_number = lineNumber;
	}

	void insert_value (std::string const& name, std::string const& value, size_t lineNumber)
	{
		if(sections.empty())
			new_section(std::vector<std::string>());
		sections.back().values.emplace_back(name, value, lineNumber);
	}

	std::string path;
	std::vector<section_t> sections;
};

char const* parse_ini (char const* p, char const* pe, ini_file_t& iniFile);

#endif /* end of include guard: INI_PARSER_H_LJ9XOMJG */
