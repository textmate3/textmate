#include "convert.h"
#include "parser.h"
#include "keys.h"
#include <io/path.h>
#include <text/format.h>
#include <oak/oak.h>

namespace settings
{
	// The settings the application reads as a boolean or a number, taken from
	// the default value each caller passes rather than from a schema, because
	// there is no schema yet. A key absent from both lists converts to a
	// string, which is what the old format made everything anyway.
	static std::set<std::string> const& boolean_settings ()
	{
		static std::set<std::string> const keys = {
			kSettingsDisableExtendedAttributesKey,
			kSettingsExcludeSCMDeletedKey,
			kSettingsFollowSymbolicLinksKey,
			kSettingsSaveOnBlurKey,
			kSettingsSCMStatusKey,
			kSettingsShowIndentGuidesKey,
			kSettingsShowInvisiblesKey,
			kSettingsShowWrapColumnKey,
			kSettingsSoftTabsKey,
			kSettingsSoftWrapKey,
			kSettingsSpellCheckingKey,
		};
		return keys;
	}

	static std::set<std::string> const& number_settings ()
	{
		static std::set<std::string> const keys = {
			kSettingsFontSizeKey,
			kSettingsTabSizeKey,
			kSettingsWrapColumnKey,
		};
		return keys;
	}

	// A variable rather than a setting, by the rule the old format used: the
	// first letter's case. TM_GIT is a variable, tabSize is a setting.
	static bool is_variable (std::string const& name)
	{
		return !name.empty() && isupper((unsigned char)name.front());
	}

	static std::string json_string (std::string const& str)
	{
		std::string res = "\"";
		for(char ch : str)
		{
			switch(ch)
			{
				case '"':  res += "\\\"";  break;
				case '\\': res += "\\\\";  break;
				case '\n': res += "\\n";   break;
				case '\r': res += "\\r";   break;
				case '\t': res += "\\t";   break;
				default:
					// The control characters JSON refuses unescaped. Everything
					// above them, UTF-8 included, passes through as its bytes.
					if((unsigned char)ch < 0x20)
							res += text::format("\\u%04x", ch);
					else	res += ch;
			}
		}
		return res + "\"";
	}

	// The old format quoted a value when it wanted to, and the parser keeps the
	// quotes. A converted value should carry the string the expander would have
	// been handed, not the quoting that got it there.
	static std::string unquoted (std::string const& value)
	{
		if(value.size() >= 2 && (value.front() == '"' || value.front() == '\'') && value.back() == value.front())
			return value.substr(1, value.size() - 2);
		return value;
	}

	static std::string json_value (std::string const& name, std::string const& rawValue)
	{
		std::string const value = unquoted(rawValue);

		if(boolean_settings().find(name) != boolean_settings().end())
		{
			if(value == "true" || value == "false")
				return value;
			// A boolean setting written as something else keeps its text, since
			// the application's own reader treats anything but true as false and
			// a converter should not decide that for it.
			return json_string(value);
		}

		if(number_settings().find(name) != number_settings().end())
		{
			char* end = nullptr;
			double const number = strtod(value.c_str(), &end);
			if(end && *end == '\0' && !value.empty())
			{
				std::string const printed = text::format("%g", number);
				return printed;
			}
			return json_string(value);
		}

		return json_string(value);
	}

	static void write_pairs (std::string& res, std::vector<std::pair<std::string, std::string>> const& pairs, std::string const& indent)
	{
		for(size_t i = 0; i < pairs.size(); ++i)
		{
			res += indent + json_string(pairs[i].first) + ": " + json_value(pairs[i].first, pairs[i].second);
			res += i + 1 < pairs.size() ? ",\n" : "\n";
		}
	}

	std::string to_json (std::string const& content, std::string const& path)
	{
		ini_file_t iniFile(path);
		parse_ini(content.data(), content.data() + content.size(), iniFile);

		std::vector<std::pair<std::string, std::string>> rootSettings, rootVariables;
		struct scoped_t { std::vector<std::string> match; std::vector<std::pair<std::string, std::string>> settings, variables; };
		std::vector<scoped_t> scoped;

		for(auto const& section : iniFile.sections)
		{
			bool const isRoot = section.names.empty();
			scoped_t entry;
			entry.match = section.names;

			for(auto const& value : section.values)
			{
				auto& into = is_variable(value.name)
					? (isRoot ? rootVariables : entry.variables)
					: (isRoot ? rootSettings  : entry.settings);
				into.emplace_back(value.name, value.value);
			}

			if(!isRoot && !(entry.settings.empty() && entry.variables.empty()))
				scoped.push_back(entry);
		}

		std::string res;
		res += "// Converted from " + path::name(path) + ".\n";
		res += "// Settings are the ones TextMate itself reads. Variables are handed to bundle commands.\n";
		res += "{\n";

		res += "\t\"settings\": {\n";
		write_pairs(res, rootSettings, "\t\t");
		res += "\t},\n";

		res += "\t\"variables\": {\n";
		write_pairs(res, rootVariables, "\t\t");
		res += "\t}";

		if(!scoped.empty())
		{
			res += ",\n\t\"scoped\": [\n";
			for(size_t i = 0; i < scoped.size(); ++i)
			{
				res += "\t\t{\n\t\t\t\"match\": [";
				for(size_t j = 0; j < scoped[i].match.size(); ++j)
					res += (j ? ", " : "") + json_string(scoped[i].match[j]);
				res += "]";

				if(!scoped[i].settings.empty())
				{
					res += ",\n\t\t\t\"settings\": {\n";
					write_pairs(res, scoped[i].settings, "\t\t\t\t");
					res += "\t\t\t}";
				}
				if(!scoped[i].variables.empty())
				{
					res += ",\n\t\t\t\"variables\": {\n";
					write_pairs(res, scoped[i].variables, "\t\t\t\t");
					res += "\t\t\t}";
				}

				res += "\n\t\t}";
				res += i + 1 < scoped.size() ? ",\n" : "\n";
			}
			res += "\t]";
		}

		res += "\n}\n";
		return res;
	}

	std::string to_json_for_path (std::string const& path)
	{
		std::string const content = path::content(path);
		if(content == NULL_STR)
			return NULL_STR;
		return to_json(content, path);
	}

} /* settings */
