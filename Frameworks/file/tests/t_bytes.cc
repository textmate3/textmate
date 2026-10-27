#include <file/bytes.h>

// The checksum the document attributes carry and the search results compare,
// pinned to the standard CRC-32 check value so that the implementation behind
// it can change without the answer changing: 0xCBF43926 for "123456789" is
// the value every CRC-32 table gives for that polynomial, initial value,
// reflection and final XOR.
void test_crc32_is_the_standard_crc32 ()
{
	OAK_ASSERT_EQ(io::bytes_t("123456789").crc32(), 0xCBF43926);
	OAK_ASSERT_EQ(io::bytes_t("").crc32(), 0);
	OAK_ASSERT_EQ(io::bytes_t("The quick brown fox jumps over the lazy dog").crc32(), 0x414FA339);
}
