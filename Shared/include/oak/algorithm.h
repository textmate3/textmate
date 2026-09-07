#ifndef OAK_ALGORITHM_H_E3HYH9S3
#define OAK_ALGORITHM_H_E3HYH9S3

template <typename _SrcKeyT, typename _SrcValueT, typename _DstKeyT, typename _DstValueT>
std::map<_SrcKeyT, _SrcValueT>& operator<< (std::map<_DstKeyT, _DstValueT>& dst, std::map<_SrcKeyT, _SrcValueT> const& src)
{
	dst.insert(src.begin(), src.end());
	return dst;
}

#endif /* end of include guard: OAK_ALGORITHM_H_E3HYH9S3 */
