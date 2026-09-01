#include <network/filter_check_signature.h>
#include <io/path.h>

static std::string fixture (std::string const& name)
{
	return path::content(path::join(path::join(__FILE__, ".."), "fixtures/ed25519/" + name));
}

// Base64 values arrive without surrounding whitespace, so trim what the file carries.
static std::string trimmed_fixture (std::string const& name)
{
	std::string res = fixture(name);
	while(!res.empty() && (res.back() == '\n' || res.back() == '\r'))
		res.pop_back();
	return res;
}

// Drive the filter the way download_tbz does: setup, data, end.
static bool run_filter (network::check_signature_t& filter, std::string const& payload, std::string& error)
{
	filter.setup();
	filter.receive_data(payload.data(), payload.size());
	return filter.receive_end(error);
}

void test_valid_signature_is_accepted ()
{
	network::check_signature_t filter(trimmed_fixture("signature.base64"), trimmed_fixture("public_key.base64"));
	std::string error;
	OAK_ASSERT(run_filter(filter, fixture("signed_payload.txt"), error));
	OAK_ASSERT_EQ(error, "");
}

// The one that matters. A verifier that accepts everything passes every other test here.
void test_corrupted_signature_is_rejected ()
{
	std::string signature = trimmed_fixture("signature.base64");
	signature[10] = (signature[10] == 'A' ? 'B' : 'A');

	network::check_signature_t filter(signature, trimmed_fixture("public_key.base64"));
	std::string error;
	OAK_ASSERT(!run_filter(filter, fixture("signed_payload.txt"), error));
	OAK_ASSERT_EQ(error, "Bad signature.");
}

// The other half of the same property: the signature must be bound to this payload.
void test_modified_payload_is_rejected ()
{
	network::check_signature_t filter(trimmed_fixture("signature.base64"), trimmed_fixture("public_key.base64"));
	std::string error;
	OAK_ASSERT(!run_filter(filter, fixture("signed_payload.txt") + "tampered", error));
	OAK_ASSERT_EQ(error, "Bad signature.");
}

void test_truncated_payload_is_rejected ()
{
	std::string payload = fixture("signed_payload.txt");
	payload.pop_back();

	network::check_signature_t filter(trimmed_fixture("signature.base64"), trimmed_fixture("public_key.base64"));
	std::string error;
	OAK_ASSERT(!run_filter(filter, payload, error));
	OAK_ASSERT_EQ(error, "Bad signature.");
}

// A valid signature by a key the application does not trust must not verify.
void test_signature_by_another_key_is_rejected ()
{
	network::check_signature_t filter(trimmed_fixture("signature.base64"), trimmed_fixture("other_public_key.base64"));
	std::string error;
	OAK_ASSERT(!run_filter(filter, fixture("signed_payload.txt"), error));
	OAK_ASSERT_EQ(error, "Bad signature.");
}

// An index entry without a signature field yields NULL_STR, and a signature the
// server never provided must fail before any cryptography happens.
void test_missing_signature_is_rejected ()
{
	network::check_signature_t filter(NULL_STR, trimmed_fixture("public_key.base64"));
	std::string error;
	OAK_ASSERT(!run_filter(filter, fixture("signed_payload.txt"), error));
	OAK_ASSERT_EQ(error, "Missing signature.");
}

void test_empty_signature_is_rejected ()
{
	network::check_signature_t filter("", trimmed_fixture("public_key.base64"));
	std::string error;
	OAK_ASSERT(!run_filter(filter, fixture("signed_payload.txt"), error));
	OAK_ASSERT_EQ(error, "Missing signature.");
}

// A build with no trusted key, the shipped default until a production key
// exists, must reject everything rather than accept everything.
void test_empty_public_key_rejects ()
{
	network::check_signature_t filter(trimmed_fixture("signature.base64"), "");
	std::string error;
	OAK_ASSERT(!run_filter(filter, fixture("signed_payload.txt"), error));
	OAK_ASSERT_EQ(error, "Bad public key: expected 32 bytes, got 0.");
}

// Bytes arrive from the network in chunks. Verification must be over the
// concatenation, not the last chunk.
void test_chunked_delivery_verifies ()
{
	std::string const payload = fixture("signed_payload.txt");
	size_t const half = payload.size() / 2;

	network::check_signature_t filter(trimmed_fixture("signature.base64"), trimmed_fixture("public_key.base64"));
	filter.setup();
	filter.receive_data(payload.data(), half);
	filter.receive_data(payload.data() + half, payload.size() - half);

	std::string error;
	OAK_ASSERT(filter.receive_end(error));
	OAK_ASSERT_EQ(error, "");
}

// setup begins a fresh download. Bytes from an earlier attempt must not leak
// into the next verification.
void test_setup_resets_accumulated_payload ()
{
	network::check_signature_t filter(trimmed_fixture("signature.base64"), trimmed_fixture("public_key.base64"));

	std::string error;
	filter.setup();
	filter.receive_data("stale bytes from an aborted attempt", 35);
	OAK_ASSERT(run_filter(filter, fixture("signed_payload.txt"), error));
	OAK_ASSERT_EQ(error, "");
}
