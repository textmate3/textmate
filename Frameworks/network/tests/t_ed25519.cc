#include <network/ed25519.h>
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

void test_valid_signature_is_accepted ()
{
	std::string error;
	OAK_ASSERT(network::verify_ed25519_signature(fixture("signed_payload.txt"), trimmed_fixture("signature.base64"), trimmed_fixture("public_key.base64"), error));
	OAK_ASSERT_EQ(error, "");
}

// The one that matters. A verifier that accepts everything passes every other test here.
void test_corrupted_signature_is_rejected ()
{
	std::string signature = trimmed_fixture("signature.base64");
	signature[10] = (signature[10] == 'A' ? 'B' : 'A');

	std::string error;
	OAK_ASSERT(!network::verify_ed25519_signature(fixture("signed_payload.txt"), signature, trimmed_fixture("public_key.base64"), error));
	OAK_ASSERT_EQ(error, "Bad signature.");
}

// The other half of the same property: the signature must be bound to this payload.
void test_modified_payload_is_rejected ()
{
	std::string payload = fixture("signed_payload.txt");
	payload += "tampered";

	std::string error;
	OAK_ASSERT(!network::verify_ed25519_signature(payload, trimmed_fixture("signature.base64"), trimmed_fixture("public_key.base64"), error));
	OAK_ASSERT_EQ(error, "Bad signature.");
}

void test_truncated_payload_is_rejected ()
{
	std::string payload = fixture("signed_payload.txt");
	payload.pop_back();

	std::string error;
	OAK_ASSERT(!network::verify_ed25519_signature(payload, trimmed_fixture("signature.base64"), trimmed_fixture("public_key.base64"), error));
	OAK_ASSERT_EQ(error, "Bad signature.");
}

// A valid signature by a key the application does not trust must not verify.
void test_signature_by_another_key_is_rejected ()
{
	std::string error;
	OAK_ASSERT(!network::verify_ed25519_signature(fixture("signed_payload.txt"), trimmed_fixture("signature.base64"), trimmed_fixture("other_public_key.base64"), error));
	OAK_ASSERT_EQ(error, "Bad signature.");
}

void test_wrong_length_signature_is_rejected ()
{
	std::string error;
	OAK_ASSERT(!network::verify_ed25519_signature(fixture("signed_payload.txt"), "c2hvcnQ=", trimmed_fixture("public_key.base64"), error));
	OAK_ASSERT_EQ(error, "Bad signature: expected 64 bytes, got 5.");
}

void test_wrong_length_public_key_is_rejected ()
{
	std::string error;
	OAK_ASSERT(!network::verify_ed25519_signature(fixture("signed_payload.txt"), trimmed_fixture("signature.base64"), "c2hvcnQ=", error));
	OAK_ASSERT_EQ(error, "Bad public key: expected 32 bytes, got 5.");
}

void test_empty_public_key_is_rejected ()
{
	std::string error;
	OAK_ASSERT(!network::verify_ed25519_signature(fixture("signed_payload.txt"), trimmed_fixture("signature.base64"), "", error));
	OAK_ASSERT_EQ(error, "Bad public key: expected 32 bytes, got 0.");
}
