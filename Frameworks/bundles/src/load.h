#ifndef LOAD_H_C8BVI372
#define LOAD_H_C8BVI372

#include "item.h"
#include <plist/fs_cache.h>

std::pair<std::vector<bundles::item_ptr>, std::map< oak::uuid_t, std::vector<oak::uuid_t>>> create_bundle_index (std::vector<std::string> const& bundlesPaths, plist::cache_t& cache);

// The subset of a bundle item's property list that the index needs. Set as
// the cache's content filter so the cache holds and stores only this subset.
plist::dictionary_t prune_bundle_item_plist (plist::dictionary_t const& plist);

#endif /* end of include guard: LOAD_H_C8BVI372 */
