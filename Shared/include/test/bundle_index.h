#ifndef TEST_BUNDLE_INDEX_H_FIMSPZJT
#define TEST_BUNDLE_INDEX_H_FIMSPZJT

#include <bundles/bundles.h>
#include <io/path.h>
#include <plist/plist.h>

namespace test
{
	// A bundle item fixture kept next to the test that uses it, as the
	// property list it holds. The test passes its own path, so the fixture
	// is found wherever the test binary runs from.
	inline plist::dictionary_t fixture (std::string const& testFile, std::string const& name)
	{
		return plist::load(path::join(path::parent(testFile), path::join("fixtures", name)));
	}

	struct bundle_index_t
	{
		bundle_index_t ()
		{
			_bundle = add(bundles::kItemTypeBundle, plist::dictionary_t{ { "name", std::string("Fixtures Bundle") } });
		}

		bundles::item_ptr add (bundles::kind_t itemKind, plist::dictionary_t const& plist)
		{
			oak::uuid_t uuid;
			if(!plist::get_key_path(plist, bundles::kFieldUUID, uuid))
				uuid.generate();

			auto item = std::make_shared<bundles::item_t>(uuid, itemKind == bundles::kItemTypeBundle ? bundles::item_ptr() : _bundle, itemKind);
			item->set_plist(plist);
			_items.push_back(item);

			return item;
		}

		bool commit () const
		{
			return bundles::set_index(_items);
		}

	private:
		bundles::item_ptr _bundle;
		std::vector<bundles::item_ptr> _items;
	};

} /* test */

#endif /* end of include guard: TEST_BUNDLE_INDEX_H_FIMSPZJT */
