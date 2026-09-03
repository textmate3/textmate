// bundle_index_benchmark: times the bundle index cache in several on-disk
// formats, so the choice of format rests on numbers.
//
// The bundle index cache is what lets a warm launch skip re-reading every
// bundle item. The application stores it through Cap'n Proto, which is the
// only reason the shipped binaries load Homebrew's libcapnp and libkj at run
// time. This tool builds the same cache the application would, writes it in
// each candidate format, and times the writes, the reads back into a cache,
// and the index build from the loaded cache. It also times an index build
// from nothing, which is what a launch without a cache costs.
//
// Output is tab separated, one measurement per line, for script/benchmark_bundle_index
// to aggregate:
//
//   info       <key>    <value>
//   size       <format> <bytes>
//   roundtrip  <format> ok|mismatch
//   sample     <round>  <format|nocache>  <save|load|index>  <milliseconds>
//
// The candidate formats carry values a property list has and JSON does not,
// dates and binary data, as a single-key object: {"$date": unix seconds} and
// {"$data": base64}. Integers travel as integers and come back as int32 when
// they fit and uint64 otherwise, which is the same rule the property list
// loader applies.

#import <bundles/load.h>
#import <bundles/locations.h>
#import <plist/fs_cache.h>
#import <plist/plist.h>
#import <io/path.h>
#import <yaml.h>
#import <Foundation/Foundation.h>
#include <chrono>
#include <random>

namespace
{
	using clock_type = std::chrono::steady_clock;

	double milliseconds_since (clock_type::time_point start)
	{
		return std::chrono::duration<double, std::milli>(clock_type::now() - start).count();
	}

	std::string read_file (std::string const& path)
	{
		std::string res;
		if(FILE* fp = fopen(path.c_str(), "r"))
		{
			char buf[65536];
			while(size_t len = fread(buf, 1, sizeof(buf), fp))
				res.append(buf, len);
			fclose(fp);
		}
		return res;
	}

	void write_file (std::string const& path, std::string const& content)
	{
		if(FILE* fp = fopen(path.c_str(), "w"))
		{
			fwrite(content.data(), 1, content.size(), fp);
			fclose(fp);
		}
	}

	size_t file_size (std::string const& path)
	{
		struct stat buf;
		return stat(path.c_str(), &buf) == 0 ? buf.st_size : 0;
	}

	// ========
	// = JSON =
	// ========

	void json_escape (std::string const& str, std::string& out)
	{
		out += '"';
		for(char ch : str)
		{
			switch(ch)
			{
				case '"':  out += "\\\""; break;
				case '\\': out += "\\\\"; break;
				case '\n': out += "\\n";  break;
				case '\r': out += "\\r";  break;
				case '\t': out += "\\t";  break;
				default:
					if((unsigned char)ch < 0x20)
					{
						char buf[8];
						snprintf(buf, sizeof(buf), "\\u%04x", ch);
						out += buf;
					}
					else
					{
						out += ch;
					}
				break;
			}
		}
		out += '"';
	}

	std::string base64 (std::vector<char> const& bytes)
	{
		NSData* data = [NSData dataWithBytes:bytes.data() length:bytes.size()];
		return [data base64EncodedStringWithOptions:0].UTF8String;
	}

	std::vector<char> from_base64 (std::string const& str)
	{
		NSData* data = [[NSData alloc] initWithBase64EncodedString:[NSString stringWithUTF8String:str.c_str()] options:0];
		char const* first = (char const*)data.bytes;
		return std::vector<char>(first, first + data.length);
	}

	void json_write (plist::any_t const& value, std::string& out)
	{
		if(bool const* flag = plist::get_if<bool>(&value))
			out += *flag ? "true" : "false";
		else if(int32_t const* number = plist::get_if<int32_t>(&value))
			out += std::to_string(*number);
		else if(uint64_t const* number = plist::get_if<uint64_t>(&value))
			out += std::to_string(*number);
		else if(std::string const* str = plist::get_if<std::string>(&value))
			json_escape(*str, out);
		else if(std::vector<char> const* bytes = plist::get_if<std::vector<char>>(&value))
			out += "{\"$data\":\"" + base64(*bytes) + "\"}";
		else if(oak::date_t const* date = plist::get_if<oak::date_t>(&value))
			out += "{\"$date\":" + std::to_string((long long)date->time_value()) + "}";
		else if(plist::array_t const* array = plist::get_if<plist::array_t>(&value))
		{
			out += '[';
			bool first = true;
			for(auto const& item : *array)
			{
				if(!std::exchange(first, false))
					out += ',';
				json_write(item, out);
			}
			out += ']';
		}
		else if(plist::dictionary_t const* dictionary = plist::get_if<plist::dictionary_t>(&value))
		{
			out += '{';
			bool first = true;
			for(auto const& pair : *dictionary)
			{
				if(!std::exchange(first, false))
					out += ',';
				json_escape(pair.first, out);
				out += ':';
				json_write(pair.second, out);
			}
			out += '}';
		}
	}

	std::string json_string (plist::any_t const& value)
	{
		std::string res;
		json_write(value, res);
		return res;
	}

	plist::any_t any_from_integer (long long value)
	{
		if(std::clamp<long long>(value, INT32_MIN, INT32_MAX) == value)
			return int32_t(value);
		return uint64_t(value);
	}

	plist::any_t any_from_foundation (id object)
	{
		if([object isKindOfClass:[NSNumber class]])
		{
			if(CFGetTypeID((__bridge CFTypeRef)object) == CFBooleanGetTypeID())
				return [object boolValue] ? true : false;
			return any_from_integer([object longLongValue]);
		}
		else if([object isKindOfClass:[NSString class]])
		{
			return std::string([object UTF8String]);
		}
		else if([object isKindOfClass:[NSArray class]])
		{
			plist::array_t res;
			for(id item in object)
				res.push_back(any_from_foundation(item));
			return res;
		}
		else if([object isKindOfClass:[NSDictionary class]])
		{
			if([object count] == 1)
			{
				if(id seconds = object[@"$date"])
					return oak::date_t((time_t)[seconds longLongValue]);
				if(id encoded = object[@"$data"])
					return from_base64([encoded UTF8String]);
			}

			plist::dictionary_t res;
			for(NSString* key in object)
				res.emplace(key.UTF8String, any_from_foundation(object[key]));
			return res;
		}
		return plist::any_t();
	}

	plist::any_t json_parse (char const* bytes, size_t length)
	{
		NSData* data = [NSData dataWithBytesNoCopy:(void*)bytes length:length freeWhenDone:NO];
		id object = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
		return any_from_foundation(object);
	}

	plist::dictionary_t dictionary_from_json (std::string const& text)
	{
		plist::any_t value = json_parse(text.data(), text.size());
		if(plist::dictionary_t* dictionary = plist::get_if<plist::dictionary_t>(&value))
			return std::move(*dictionary);
		return plist::dictionary_t();
	}

	// ==============
	// = JSON Lines =
	// ==============

	std::string jsonl_string (plist::dictionary_t const& plist)
	{
		std::string res;
		for(auto const& pair : plist)
		{
			res += '{';
			json_escape(pair.first, res);
			res += ':';
			json_write(pair.second, res);
			res += "}\n";
		}
		return res;
	}

	plist::dictionary_t dictionary_from_jsonl (std::string const& text)
	{
		plist::dictionary_t res;
		size_t from = 0;
		while(from < text.size())
		{
			size_t to = text.find('\n', from);
			if(to == std::string::npos)
				to = text.size();

			plist::any_t line = json_parse(text.data() + from, to - from);
			if(plist::dictionary_t* dictionary = plist::get_if<plist::dictionary_t>(&line))
			{
				for(auto& pair : *dictionary)
					res.emplace(pair.first, std::move(pair.second));
			}
			from = to + 1;
		}
		return res;
	}

	// =======
	// = CSV =
	// =======
	//
	// One row per cache entry. The entries list and the parsed content are
	// nested values with no CSV shape of their own, so they travel as JSON
	// inside a cell. This is the crudest thing that round trips, measured so
	// the question is closed rather than because it can win.

	void csv_cell (std::string const& str, std::string& out)
	{
		out += '"';
		for(char ch : str)
		{
			if(ch == '"')
				out += '"';
			out += ch;
		}
		out += '"';
	}

	std::string csv_string (plist::dictionary_t const& plist)
	{
		std::string res = "path,type,modified,link,glob,eventId,entries,content\n";
		for(auto const& pair : plist)
		{
			plist::dictionary_t const* node = plist::get_if<plist::dictionary_t>(&pair.second);
			if(!node)
			{
				if(pair.first == "version")
					res += "version,version,,,," + json_string(pair.second) + ",,\n";
				continue;
			}

			std::string type, modified, link, glob, eventId, entries, content;
			for(auto const& field : *node)
			{
				if(field.first == "content")
				{
					type = "file";
					content = json_string(field.second);
				}
				else if(field.first == "modified")
				{
					if(oak::date_t const* date = plist::get_if<oak::date_t>(&field.second))
						modified = std::to_string((long long)date->time_value());
				}
				else if(field.first == "link")
				{
					type = "link";
					link = plist::get_ref<std::string>(field.second);
				}
				else if(field.first == "missing")
				{
					type = "missing";
				}
				else if(field.first == "entries")
				{
					type = "directory";
					entries = json_string(field.second);
				}
				else if(field.first == "glob")
				{
					glob = plist::get_ref<std::string>(field.second);
				}
				else if(field.first == "eventId")
				{
					eventId = json_string(field.second);
				}
			}

			csv_cell(pair.first, res);
			res += ',' + type + ',' + modified + ',';
			csv_cell(link, res);
			res += ',';
			csv_cell(glob, res);
			res += ',' + eventId + ',';
			csv_cell(entries, res);
			res += ',';
			csv_cell(content, res);
			res += '\n';
		}
		return res;
	}

	std::vector<std::string> csv_row (std::string const& text, size_t& offset)
	{
		std::vector<std::string> res;
		std::string cell;
		bool quoted = false;
		while(offset < text.size())
		{
			char ch = text[offset++];
			if(quoted)
			{
				if(ch == '"')
				{
					if(offset < text.size() && text[offset] == '"')
					{
						cell += '"';
						++offset;
					}
					else
					{
						quoted = false;
					}
				}
				else
				{
					cell += ch;
				}
			}
			else if(ch == '"')
			{
				quoted = true;
			}
			else if(ch == ',')
			{
				res.push_back(std::move(cell));
				cell.clear();
			}
			else if(ch == '\n')
			{
				break;
			}
			else
			{
				cell += ch;
			}
		}
		res.push_back(std::move(cell));
		return res;
	}

	plist::dictionary_t dictionary_from_csv (std::string const& text)
	{
		plist::dictionary_t res;
		size_t offset = 0;
		csv_row(text, offset); // header
		while(offset < text.size())
		{
			std::vector<std::string> row = csv_row(text, offset);
			if(row.size() != 8)
				continue;

			std::string const& type = row[1];
			if(type == "version")
			{
				res.emplace("version", any_from_integer(std::stoll(row[5])));
				continue;
			}

			plist::dictionary_t node;
			if(type == "file")
			{
				node.emplace("content", json_parse(row[7].data(), row[7].size()));
				node.emplace("modified", oak::date_t((time_t)std::stoll(row[2])));
			}
			else if(type == "link")
			{
				node.emplace("link", row[3]);
			}
			else if(type == "missing")
			{
				node.emplace("missing", true);
			}
			else if(type == "directory")
			{
				node.emplace("entries", json_parse(row[6].data(), row[6].size()));
				node.emplace("glob", row[4]);
				if(!row[5].empty())
					node.emplace("eventId", uint64_t(std::stoull(row[5])));
			}
			res.emplace(row[0], std::move(node));
		}
		return res;
	}

	// ========
	// = YAML =
	// ========
	//
	// Written in block style with every string double quoted, which is the
	// shape a person would recognize as YAML. JSON string escapes are a
	// subset of YAML's double quoted escapes, so the JSON escaper serves.
	// Read back through libyaml's event parser.

	bool yaml_is_scalar (plist::any_t const& value)
	{
		return !plist::get_if<plist::array_t>(&value) && !plist::get_if<plist::dictionary_t>(&value) && !plist::get_if<oak::date_t>(&value) && !plist::get_if<std::vector<char>>(&value);
	}

	// YAML's double quoted scalars take JSON's escapes, but YAML also refuses
	// unescaped DEL, the C1 controls and U+FFFE and U+FFFF, and the cache holds
	// U+FFFF wherever a glob string is unset. Those go out as \u escapes.
	void yaml_escape (std::string const& str, std::string& out)
	{
		out += '"';
		for(size_t i = 0; i < str.size(); )
		{
			unsigned char lead = str[i];
			size_t length = lead < 0x80 ? 1 : lead < 0xE0 ? 2 : lead < 0xF0 ? 3 : 4;
			if(i + length > str.size())
				length = 1;

			uint32_t codePoint = length == 1 ? lead : lead & (0x7F >> length);
			for(size_t j = 1; j < length; ++j)
				codePoint = (codePoint << 6) | ((unsigned char)str[i + j] & 0x3F);

			bool const unprintable = codePoint < 0x20 || codePoint == 0x7F || (0x80 <= codePoint && codePoint <= 0x9F) || codePoint == 0xFFFE || codePoint == 0xFFFF;
			if(codePoint == '"')
				out += "\\\"";
			else if(codePoint == '\\')
				out += "\\\\";
			else if(codePoint == '\n')
				out += "\\n";
			else if(codePoint == '\t')
				out += "\\t";
			else if(unprintable)
			{
				char buf[8];
				snprintf(buf, sizeof(buf), "\\u%04x", codePoint);
				out += buf;
			}
			else
			{
				out.append(str, i, length);
			}
			i += length;
		}
		out += '"';
	}

	void yaml_scalar (plist::any_t const& value, std::string& out)
	{
		if(std::string const* str = plist::get_if<std::string>(&value))
			yaml_escape(*str, out);
		else
			json_write(value, out);
	}

	void yaml_write (plist::any_t const& value, std::string& out, size_t depth)
	{
		std::string const indent(depth * 2, ' ');
		if(plist::dictionary_t const* dictionary = plist::get_if<plist::dictionary_t>(&value))
		{
			for(auto const& pair : *dictionary)
			{
				out += indent;
				json_escape(pair.first, out);
				out += ':';
				if(yaml_is_scalar(pair.second))
				{
					out += ' ';
					yaml_scalar(pair.second, out);
					out += '\n';
				}
				else if(plist::array_t const* array = plist::get_if<plist::array_t>(&pair.second); array && array->empty())
				{
					out += " []\n";
				}
				else if(plist::dictionary_t const* nested = plist::get_if<plist::dictionary_t>(&pair.second); nested && nested->empty())
				{
					out += " {}\n";
				}
				else
				{
					out += '\n';
					yaml_write(pair.second, out, depth + 1);
				}
			}
		}
		else if(plist::array_t const* array = plist::get_if<plist::array_t>(&value))
		{
			for(auto const& item : *array)
			{
				out += indent + '-';
				if(yaml_is_scalar(item))
				{
					out += ' ';
					yaml_scalar(item, out);
					out += '\n';
				}
				else
				{
					out += '\n';
					yaml_write(item, out, depth + 1);
				}
			}
		}
		else if(oak::date_t const* date = plist::get_if<oak::date_t>(&value))
		{
			out += indent + "\"$date\": " + std::to_string((long long)date->time_value()) + '\n';
		}
		else if(std::vector<char> const* bytes = plist::get_if<std::vector<char>>(&value))
		{
			out += indent + "\"$data\": \"" + base64(*bytes) + "\"\n";
		}
	}

	std::string yaml_string (plist::dictionary_t const& plist)
	{
		std::string res;
		yaml_write(plist, res, 0);
		return res;
	}

	plist::any_t yaml_scalar_value (yaml_event_t const& event)
	{
		std::string str((char const*)event.data.scalar.value, event.data.scalar.length);
		if(event.data.scalar.style == YAML_PLAIN_SCALAR_STYLE)
		{
			if(str == "true")
				return true;
			if(str == "false")
				return false;
			if(!str.empty() && str.find_first_not_of("-0123456789") == std::string::npos)
				return any_from_integer(std::stoll(str));
		}
		return str;
	}

	plist::any_t yaml_finish_container (plist::any_t& container)
	{
		if(plist::dictionary_t* dictionary = plist::get_if<plist::dictionary_t>(&container); dictionary && dictionary->size() == 1)
		{
			auto const& pair = *dictionary->begin();
			if(pair.first == "$date")
				return oak::date_t((time_t)(plist::get_if<int32_t>(&pair.second) ? plist::get_ref<int32_t>(pair.second) : plist::get_ref<uint64_t>(pair.second)));
			if(pair.first == "$data")
				return from_base64(plist::get_ref<std::string>(pair.second));
		}
		return std::move(container);
	}

	plist::dictionary_t dictionary_from_yaml (std::string const& text)
	{
		struct frame_t
		{
			plist::any_t container;
			std::string key;
			bool has_key = false;
		};

		std::vector<frame_t> stack;
		plist::any_t root;

		auto place = [&](plist::any_t value){
			if(stack.empty())
			{
				root = std::move(value);
				return;
			}

			frame_t& top = stack.back();
			if(plist::dictionary_t* dictionary = plist::get_if<plist::dictionary_t>(&top.container))
			{
				if(!top.has_key)
				{
					top.key = plist::get_if<std::string>(&value) ? plist::get_ref<std::string>(value) : std::string();
					top.has_key = true;
				}
				else
				{
					dictionary->emplace(std::move(top.key), std::move(value));
					top.has_key = false;
				}
			}
			else if(plist::array_t* array = plist::get_if<plist::array_t>(&top.container))
			{
				array->push_back(std::move(value));
			}
		};

		yaml_parser_t parser;
		yaml_parser_initialize(&parser);
		yaml_parser_set_input_string(&parser, (unsigned char const*)text.data(), text.size());

		bool done = false;
		while(!done)
		{
			yaml_event_t event;
			if(!yaml_parser_parse(&parser, &event))
			{
				fprintf(stderr, "yaml: %s\n", parser.problem);
				break;
			}

			switch(event.type)
			{
				case YAML_MAPPING_START_EVENT:  stack.push_back(frame_t{ plist::dictionary_t() }); break;
				case YAML_SEQUENCE_START_EVENT: stack.push_back(frame_t{ plist::array_t() });      break;
				case YAML_SCALAR_EVENT:         place(yaml_scalar_value(event));                   break;
				case YAML_STREAM_END_EVENT:     done = true;                                       break;

				case YAML_MAPPING_END_EVENT:
				case YAML_SEQUENCE_END_EVENT:
				{
					plist::any_t container = std::move(stack.back().container);
					stack.pop_back();
					place(yaml_finish_container(container));
				}
				break;

				default:
				break;
			}
			yaml_event_delete(&event);
		}
		yaml_parser_delete(&parser);

		if(plist::dictionary_t* dictionary = plist::get_if<plist::dictionary_t>(&root))
			return std::move(*dictionary);
		return plist::dictionary_t();
	}

	// ===========
	// = Formats =
	// ===========

	struct format_t
	{
		std::string name;
		std::string extension;
		std::function<void(plist::cache_t const&, std::string const&)> save;
		std::function<void(plist::cache_t&, std::string const&)> load;
	};

	std::vector<format_t> const& all_formats ()
	{
		static std::vector<format_t> const formats = {
			{ "capnp", "binary",
				[](plist::cache_t const& cache, std::string const& path){ cache.save_capnp(path); },
				[](plist::cache_t& cache, std::string const& path){ cache.load_capnp(path); } },
			{ "plist_binary", "plist",
				[](plist::cache_t const& cache, std::string const& path){ cache.save(path); },
				[](plist::cache_t& cache, std::string const& path){ cache.load(path); } },
			{ "plist_xml", "xml.plist",
				[](plist::cache_t const& cache, std::string const& path){ plist::save(path, cache.to_plist(), plist::kPlistFormatXML); },
				[](plist::cache_t& cache, std::string const& path){ cache.from_plist(plist::load(path)); } },
			{ "json", "json",
				[](plist::cache_t const& cache, std::string const& path){ write_file(path, json_string(cache.to_plist())); },
				[](plist::cache_t& cache, std::string const& path){ cache.from_plist(dictionary_from_json(read_file(path))); } },
			{ "jsonl", "jsonl",
				[](plist::cache_t const& cache, std::string const& path){ write_file(path, jsonl_string(cache.to_plist())); },
				[](plist::cache_t& cache, std::string const& path){ cache.from_plist(dictionary_from_jsonl(read_file(path))); } },
			{ "csv", "csv",
				[](plist::cache_t const& cache, std::string const& path){ write_file(path, csv_string(cache.to_plist())); },
				[](plist::cache_t& cache, std::string const& path){ cache.from_plist(dictionary_from_csv(read_file(path))); } },
			{ "yaml", "yaml",
				[](plist::cache_t const& cache, std::string const& path){ write_file(path, yaml_string(cache.to_plist())); },
				[](plist::cache_t& cache, std::string const& path){ cache.from_plist(dictionary_from_yaml(read_file(path))); } },
		};
		return formats;
	}

	void usage (FILE* io)
	{
		fprintf(io,
			"usage: bundle_index_benchmark [options]\n"
			"  --location <dir>       a bundle location, repeatable, default is the application's list\n"
			"  --work-dir <dir>       where the cache files are written, default is a temporary directory\n"
			"  --rounds <n>           rounds per format, default 10\n"
			"  --baseline-rounds <n>  index builds from nothing, default 3\n"
			"  --formats <a,b,c>      subset of: capnp plist_binary plist_xml json jsonl csv yaml\n"
			"  --keep                 leave the cache files in the work directory\n");
	}
}

int main (int argc, char* argv[])
{
	std::vector<std::string> locations;
	std::string workDirectory;
	size_t rounds = 10, baselineRounds = 3;
	std::set<std::string> formatNames;
	bool keep = false;

	for(int i = 1; i < argc; ++i)
	{
		std::string const arg = argv[i];
		std::string const next = i + 1 < argc ? argv[i + 1] : "";
		if(arg == "--location")             { locations.push_back(next); ++i; }
		else if(arg == "--work-dir")        { workDirectory = next; ++i; }
		else if(arg == "--rounds")          { rounds = std::stoul(next); ++i; }
		else if(arg == "--baseline-rounds") { baselineRounds = std::stoul(next); ++i; }
		else if(arg == "--keep")            { keep = true; }
		else if(arg == "--formats")
		{
			std::stringstream stream(next);
			std::string name;
			while(std::getline(stream, name, ','))
				formatNames.insert(name);
			++i;
		}
		else if(arg == "--help") { usage(stdout); return 0; }
		else                     { usage(stderr); return 1; }
	}

	if(locations.empty())
		locations = bundles::locations();

	std::vector<std::string> bundlesPaths;
	for(auto const& location : locations)
		bundlesPaths.push_back(path::join(location, "Bundles"));

	if(workDirectory.empty())
	{
		char buf[] = "/tmp/bundle_index_benchmark.XXXXXX";
		workDirectory = mkdtemp(buf);
	}

	std::vector<format_t> formats;
	for(auto const& format : all_formats())
	{
		if(formatNames.empty() || formatNames.count(format.name))
			formats.push_back(format);
	}

	// The index built from nothing is the launch without a cache. Its first
	// build also yields the cache every format is measured against, built
	// exactly as the application builds it.
	plist::cache_t source;
	for(size_t round = 1; round <= std::max<size_t>(baselineRounds, 1); ++round)
	{
		plist::cache_t cache;
		cache.set_content_filter(&prune_bundle_item_plist);

		auto start = clock_type::now();
		auto index = create_bundle_index(bundlesPaths, cache);
		printf("sample\t%zu\tnocache\tindex\t%.2f\n", round, milliseconds_since(start));

		if(round == 1)
		{
			source = cache;
			printf("info\titems\t%zu\n", index.first.size());
		}
	}

	size_t bundleCount = 0;
	for(auto const& bundlesPath : bundlesPaths)
		bundleCount += source.entries(bundlesPath, "*.tm[Bb]undle").size();
	printf("info\tbundles\t%zu\n", bundleCount);
	printf("info\tentries\t%zu\n", source.size());
	printf("info\twork_dir\t%s\n", workDirectory.c_str());

	plist::dictionary_t const reference = source.to_plist();

	std::mt19937 generator(20260903);
	for(size_t round = 1; round <= rounds; ++round)
	{
		double load[1];
		getloadavg(load, 1);
		printf("info\tloadavg\t%.2f\n", load[0]);

		std::vector<format_t> order = formats;
		std::shuffle(order.begin(), order.end(), generator);

		for(auto const& format : order)
		{
			std::string const path = path::join(workDirectory, "BundlesIndex." + format.extension);

			auto saveStart = clock_type::now();
			format.save(source, path);
			printf("sample\t%zu\t%s\tsave\t%.2f\n", round, format.name.c_str(), milliseconds_since(saveStart));

			plist::cache_t loaded;
			auto loadStart = clock_type::now();
			format.load(loaded, path);
			printf("sample\t%zu\t%s\tload\t%.2f\n", round, format.name.c_str(), milliseconds_since(loadStart));

			auto indexStart = clock_type::now();
			create_bundle_index(bundlesPaths, loaded);
			printf("sample\t%zu\t%s\tindex\t%.2f\n", round, format.name.c_str(), milliseconds_since(indexStart));

			if(round == 1)
			{
				printf("size\t%s\t%zu\n", format.name.c_str(), file_size(path));
				printf("roundtrip\t%s\t%s\n", format.name.c_str(), plist::equal(loaded.to_plist(), reference) ? "ok" : "mismatch");
			}
		}
		fflush(stdout);
	}

	if(!keep)
	{
		for(auto const& format : formats)
			unlink(path::join(workDirectory, "BundlesIndex." + format.extension).c_str());
		rmdir(workDirectory.c_str());
	}

	return 0;
}
