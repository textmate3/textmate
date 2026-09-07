#ifndef TEST_SHUFFLE_H_9G2LWXQF
#define TEST_SHUFFLE_H_9G2LWXQF

namespace test
{
	// Puts a range in random order, for tests that want to insert keys in an order they did not choose.
	// std::shuffle wants a random number engine handed to it, and this keeps one for every test in the process.
	// The engine is seeded once from the system, so each run of a test sees a different order.
	template <typename _Iter>
	void shuffle (_Iter first, _Iter last)
	{
		static std::mt19937 engine(std::random_device{}());
		std::shuffle(first, last, engine);
	}
}

#endif /* end of include guard: TEST_SHUFFLE_H_9G2LWXQF */
