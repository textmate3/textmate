#ifndef OAK_ALGORITHM_H_E3HYH9S3
#define OAK_ALGORITHM_H_E3HYH9S3

namespace oak
{
	template <typename _Map>
	void erase_descendent_keys (_Map& map, std::string const& path)
	{
		auto from = map.upper_bound(path);
		auto to = from;
		while(to != map.end() && to->first.starts_with(path))
			++to;
		map.erase(from, to);
	}
};

template <typename _SrcKeyT, typename _SrcValueT, typename _DstKeyT, typename _DstValueT>
std::map<_SrcKeyT, _SrcValueT>& operator<< (std::map<_DstKeyT, _DstValueT>& dst, std::map<_SrcKeyT, _SrcValueT> const& src)
{
	dst.insert(src.begin(), src.end());
	return dst;
}

#endif /* end of include guard: OAK_ALGORITHM_H_E3HYH9S3 */
