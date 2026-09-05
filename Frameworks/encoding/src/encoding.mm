#include "encoding.h"
#include <plist/plist.h>

static int32_t const kClassifierFormatVersion = 1;

namespace encoding
{
	struct classifier_t
	{
		void load (std::string const& path);
		void save (std::string const& path) const;

		void learn (char const* first, char const* last, std::string const& charset)
		{
			auto& r = _charsets[charset];
			each_word(first, last, [&](std::string const& word){
				r.words[word] += 1;
				r.total_words += 1;
				_combined.words[word] += 1;
				_combined.total_words += 1;

				for(char ch : word)
				{
					if(ch > 0x7F)
					{
						r.bytes[ch] += 1;
						r.total_bytes += 1;
						_combined.bytes[ch] += 1;
						_combined.total_bytes += 1;
					}
				}
			});
		}

		double probability (char const* first, char const* last, std::string const& charset) const
		{
			auto record = _charsets.find(charset);
			if(record == _charsets.end())
				return 0;

			std::set<std::string> seen;
			double a = 1, b = 1;

			each_word(first, last, [&](std::string const& word){
				auto global = _combined.words.find(word);
				if(global != _combined.words.end() && seen.insert(word).second)
				{
					auto local = record->second.words.find(word);
					if(local != record->second.words.end())
					{
						double pWT = local->second / (double)record->second.total_words;
						double pWF = (global->second - local->second) / (double)_combined.total_words;
						double p = pWT / (pWT + pWF);

						a *= p;
						b *= 1-p;
					}
					else
					{
						a = 0;
					}
				}
				else
				{
					for(char ch : word)
					{
						if(ch > 0x7F)
						{
							auto global = _combined.bytes.find(ch);
							if(global != _combined.bytes.end())
							{
								auto local = record->second.bytes.find(ch);
								if(local != record->second.bytes.end())
								{
									double pWT = local->second / (double)record->second.total_bytes;
									double pWF = (global->second - local->second) / (double)_combined.total_bytes;
									double p = pWT / (pWT + pWF);

									a *= p;
									b *= 1-p;
								}
								else
								{
									a = 0;
								}
							}
						}
					}
				}
			});

			return (a + b) == 0 ? 0 : a / (a + b);
		}

		std::vector<std::string> charsets () const;

		bool operator== (classifier_t const& rhs) const
		{
			return _charsets == rhs._charsets && _combined == rhs._combined;
		}

		bool operator!= (classifier_t const& rhs) const
		{
			return !(*this == rhs);
		}

	private:

		template <typename _F>
		static void each_word (char const* first, char const* last, _F op)
		{
			for(auto eow = first; eow != last; )
			{
				auto bow = std::find_if(eow, last, [](char ch){ return isalpha(ch) || ch > 0x7F; });
				eow = std::find_if(bow, last, [](char ch){ return !isalnum(ch) && ch < 0x80; });
				if(std::find_if(bow, eow, [](char ch){ return ch > 0x7F; }) != eow)
					op(std::string(bow, eow));
			}
		}

		struct record_t
		{
			bool operator== (record_t const& rhs) const
			{
				return words == rhs.words && bytes == rhs.bytes && total_words == rhs.total_words && total_bytes == rhs.total_bytes;
			}

			bool operator!= (record_t const& rhs) const
			{
				return !(*this == rhs);
			}

			std::map<std::string, size_t> words;
			std::map<char, size_t> bytes;
			size_t total_words = 0;
			size_t total_bytes = 0;
		};

		std::map<std::string, record_t> _charsets;
		record_t _combined;
	};

	std::vector<std::string> classifier_t::charsets () const
	{
		std::vector<std::string> res;
		for(auto const& pair : _charsets)
			res.emplace_back(pair.first);
		return res;
	}

	// The counts live on disk as a binary property list:
	//
	//   version  1
	//   charsets { "<charset>" : { words { "<base64 of word>" : count }, bytes { "<byte value>" : count } } }
	//
	// A word is the bytes of the file in the charset being learned, not UTF-8,
	// and a property list key has to be a string, so the bytes travel base64
	// encoded. A count comes back as int32 when it fits and uint64 otherwise,
	// which is how the property list loader types every integer.
	static size_t count_from (plist::any_t const& value)
	{
		if(int32_t const* small = plist::get_if<int32_t>(&value))
			return *small;
		if(uint64_t const* large = plist::get_if<uint64_t>(&value))
			return *large;
		return 0;
	}

	static std::string base64_of (std::string const& bytes)
	{
		NSData* data = [NSData dataWithBytes:bytes.data() length:bytes.size()];
		return [data base64EncodedStringWithOptions:0].UTF8String;
	}

	static std::string bytes_of (std::string const& base64)
	{
		NSData* data = [[NSData alloc] initWithBase64EncodedString:[NSString stringWithUTF8String:base64.c_str()] options:0];
		return data ? std::string((char const*)data.bytes, data.length) : std::string();
	}

	void classifier_t::load (std::string const& path)
	{
		int32_t version;
		plist::dictionary_t const plist = plist::load(path);
		if(!plist::get_key_path(plist, "version", version) || version != kClassifierFormatVersion)
			return;

		plist::dictionary_t charsets;
		if(!plist::get_key_path(plist, "charsets", charsets))
			return;

		for(auto const& pair : charsets)
		{
			record_t r;

			plist::dictionary_t words;
			if(plist::get_key_path(pair.second, "words", words))
			{
				for(auto const& word : words)
					r.words.emplace(bytes_of(word.first), count_from(word.second));
			}

			plist::dictionary_t bytes;
			if(plist::get_key_path(pair.second, "bytes", bytes))
			{
				for(auto const& byte : bytes)
					r.bytes.emplace((char)std::stoi(byte.first), count_from(byte.second));
			}

			_charsets.emplace(pair.first, r);
		}

		for(auto& pair : _charsets)
		{
			for(auto const& word : pair.second.words)
			{
				_combined.words[word.first] += word.second;
				_combined.total_words += word.second;
				pair.second.total_words += word.second;
			}

			for(auto const& byte : pair.second.bytes)
			{
				_combined.bytes[byte.first] += byte.second;
				_combined.total_bytes += byte.second;
				pair.second.total_bytes += byte.second;
			}
		}
	}

	void classifier_t::save (std::string const& path) const
	{
		plist::dictionary_t charsets;
		for(auto const& pair : _charsets)
		{
			plist::dictionary_t words;
			for(auto const& word : pair.second.words)
				words.emplace(base64_of(word.first), uint64_t(word.second));

			plist::dictionary_t bytes;
			for(auto const& byte : pair.second.bytes)
				bytes.emplace(std::to_string((unsigned char)byte.first), uint64_t(byte.second));

			plist::dictionary_t record;
			record.emplace("words", words);
			record.emplace("bytes", bytes);
			charsets.emplace(pair.first, record);
		}

		plist::dictionary_t plist;
		plist.emplace("version", kClassifierFormatVersion);
		plist.emplace("charsets", charsets);
		plist::save(path, plist);
	}

} /* encoding */

@interface EncodingClassifier : NSObject
{
	NSString* _path;
	encoding::classifier_t _database;
	std::mutex _databaseMutex;

	BOOL _needsSaveDatabase;
	NSTimer* _saveDatabaseTimer;
}
@end

@implementation EncodingClassifier
+ (instancetype)sharedInstance
{
	static EncodingClassifier* sharedInstance = [self new];
	return sharedInstance;
}

- (instancetype)init
{
	if(self = [super init])
	{
		// The application's caches folder, named by its bundle identifier. This
		// framework sits below OakSystem, which knows the identifier, so it asks
		// the bundle instead. A test binary has no bundle and gets the same name.
		NSString* identifier = NSBundle.mainBundle.bundleIdentifier ?: @"com.textmate3.TextMate";
		_path = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES).firstObject stringByAppendingPathComponent:[identifier stringByAppendingPathComponent:@"EncodingFrequencies.plist"]];
		_database.load(_path.fileSystemRepresentation);

		[NSNotificationCenter.defaultCenter addObserver:self selector:@selector(applicationWillTerminate:) name:NSApplicationWillTerminateNotification object:NSApp];
	}
	return self;
}

- (void)applicationWillTerminate:(NSNotification*)aNotification
{
	[self synchronize];
}

- (std::vector<std::string>)charsets
{
	std::lock_guard<std::mutex> lock(_databaseMutex);
	return _database.charsets();
}

- (double)probabilityForData:(NSData*)data asCharset:(std::string const&)charset
{
	std::lock_guard<std::mutex> lock(_databaseMutex);
	return _database.probability((char const*)data.bytes, (char const*)data.bytes + data.length, charset);
}

- (void)learnData:(NSData*)data asCharset:(std::string const&)charset
{
	std::lock_guard<std::mutex> lock(_databaseMutex);
	_database.learn((char const*)data.bytes, (char const*)data.bytes + data.length, charset);
	self.needsSaveDatabase = YES;
}

- (void)synchronize
{
	std::lock_guard<std::mutex> lock(_databaseMutex);
	if(_needsSaveDatabase)
		_database.save(_path.fileSystemRepresentation);
	self.needsSaveDatabase = NO;
}

- (void)setNeedsSaveDatabase:(BOOL)flag
{
	if(_saveDatabaseTimer)
	{
		[_saveDatabaseTimer invalidate];
		_saveDatabaseTimer = nil;
	}

	if(_needsSaveDatabase = flag)
		_saveDatabaseTimer = [NSTimer scheduledTimerWithTimeInterval:5 target:self selector:@selector(saveDatabaseTimerDidFire:) userInfo:nil repeats:NO];
}

- (void)saveDatabaseTimerDidFire:(NSTimer*)aTimer
{
	[self synchronize];
}
@end

namespace encoding
{
	// ==============
	// = Public API =
	// ==============

	std::vector<std::string> charsets ()
	{
		return EncodingClassifier.sharedInstance.charsets;
	}

	double probability (char const* first, char const* last, std::string const& charset)
	{
		NSData* data = [NSData dataWithBytesNoCopy:(void*)first length:last - first freeWhenDone:NO];
		return [EncodingClassifier.sharedInstance probabilityForData:data asCharset:charset];
	}

	void learn (char const* first, char const* last, std::string const& charset)
	{
		NSData* data = [NSData dataWithBytesNoCopy:(void*)first length:last - first freeWhenDone:NO];
		return [EncodingClassifier.sharedInstance learnData:data asCharset:charset];
	}

} /* encoding */
