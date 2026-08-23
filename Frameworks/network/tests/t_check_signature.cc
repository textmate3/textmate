#include <network/filter_check_signature.h>
#include <network/key_chain.h>
#include <io/path.h>
#include <text/format.h>

// The signee identity is arbitrary. It only has to match between the key chain
// entry and the header the filter reads.
static std::string const kSignee = "test-signer";

static std::string fixture (std::string const& name)
{
	return path::content(path::join(path::join(__FILE__, ".."), "fixtures/" + name));
}

// Header values arrive without surrounding whitespace, so trim what the file carries.
static std::string signature (std::string const& digest)
{
	std::string res = fixture("signature_" + digest + ".base64");
	while(!res.empty() && (res.back() == '\n' || res.back() == '\r'))
		res.pop_back();
	return res;
}

static key_chain_t test_key_chain ()
{
	key_chain_t res;
	res.add(key_chain_t::key_t(kSignee, fixture("signing_key_public.pem")));
	return res;
}

// Drive the filter the way download_tbz does: setup, headers, data, end.
static bool run_filter (network::check_signature_t& filter, std::string const& signee, std::string const& sig, std::string const& payload, std::string& error)
{
	filter.setup();
	if(signee != NULL_STR)
		filter.receive_header(filter.signee(), signee);
	if(sig != NULL_STR)
		filter.receive_header(filter.signature(), sig);
	filter.receive_data(payload.data(), payload.size());
	return filter.receive_end(error);
}

static network::check_signature_t make_filter (key_chain_t const& keyChain)
{
	return network::check_signature_t(keyChain, "x-signee", "x-signature");
}

void test_valid_signature_is_accepted ()
{
	auto keyChain = test_key_chain();
	auto filter   = make_filter(keyChain);
	std::string error;
	OAK_ASSERT(run_filter(filter, kSignee, signature("sha1"), fixture("signed_payload.txt"), error));
	OAK_ASSERT_EQ(error, "");
}

// The one that matters. A verifier that accepts everything passes every other test here.
void test_corrupted_signature_is_rejected ()
{
	auto keyChain = test_key_chain();
	auto filter   = make_filter(keyChain);

	std::string sig = signature("sha1");
	sig[10] = (sig[10] == 'A' ? 'B' : 'A');

	std::string error;
	OAK_ASSERT(!run_filter(filter, kSignee, sig, fixture("signed_payload.txt"), error));
	OAK_ASSERT(error != "");
}

// The other half of the same property: the signature must be bound to this payload.
void test_modified_payload_is_rejected ()
{
	auto keyChain = test_key_chain();
	auto filter   = make_filter(keyChain);

	std::string payload = fixture("signed_payload.txt");
	payload += "tampered";

	std::string error;
	OAK_ASSERT(!run_filter(filter, kSignee, signature("sha1"), payload, error));
	OAK_ASSERT_EQ(error, "Bad signature.");
}

void test_truncated_payload_is_rejected ()
{
	auto keyChain = test_key_chain();
	auto filter   = make_filter(keyChain);

	std::string payload = fixture("signed_payload.txt");
	payload.pop_back();

	std::string error;
	OAK_ASSERT(!run_filter(filter, kSignee, signature("sha1"), payload, error));
	OAK_ASSERT_EQ(error, "Bad signature.");
}

// Pins the implicit digest choice. SecVerifyTransformCreate is called without naming
// one, and picks SHA-1. These are valid signatures by the same key over the same
// payload, and must not verify. If either starts passing, the implicit choice moved.
void test_wrong_digest_signatures_are_rejected ()
{
	for(std::string const& digest : { "sha256", "sha512" })
	{
		auto keyChain = test_key_chain();
		auto filter   = make_filter(keyChain);
		std::string error;
		OAK_ASSERT(!run_filter(filter, kSignee, signature(digest), fixture("signed_payload.txt"), error));
	}
}

void test_unknown_signee_is_rejected ()
{
	auto keyChain = test_key_chain();
	auto filter   = make_filter(keyChain);
	std::string error;
	OAK_ASSERT(!run_filter(filter, "somebody-else", signature("sha1"), fixture("signed_payload.txt"), error));
	OAK_ASSERT_EQ(error, "Unknown signee: ‘somebody-else’.");
}

void test_missing_signee_is_rejected ()
{
	auto keyChain = test_key_chain();
	auto filter   = make_filter(keyChain);
	std::string error;
	OAK_ASSERT(!run_filter(filter, NULL_STR, signature("sha1"), fixture("signed_payload.txt"), error));
	OAK_ASSERT_EQ(error, "Missing signee.");
}

void test_missing_signature_is_rejected ()
{
	auto keyChain = test_key_chain();
	auto filter   = make_filter(keyChain);
	std::string error;
	OAK_ASSERT(!run_filter(filter, kSignee, NULL_STR, fixture("signed_payload.txt"), error));
	OAK_ASSERT_EQ(error, "Missing signature.");
}

void test_empty_payload_is_rejected ()
{
	auto keyChain = test_key_chain();
	auto filter   = make_filter(keyChain);
	std::string error;
	OAK_ASSERT(!run_filter(filter, kSignee, signature("sha1"), "", error));
	OAK_ASSERT_EQ(error, "Bad signature.");
}

// skip_validation exists for local development against the stand-in catalog server.
// It must bypass everything, including a signature that would otherwise fail.
void test_skip_validation_bypasses_a_bad_signature ()
{
	auto keyChain = test_key_chain();
	auto filter   = make_filter(keyChain);
	filter.skip_validation();
	std::string error;
	OAK_ASSERT(run_filter(filter, NULL_STR, NULL_STR, "anything at all", error));
}
