#ifndef PUBKEY_H_VC2ABIZU
#define PUBKEY_H_VC2ABIZU

#include "download.h" // filter_t

// ======================
// = Validate signature =
// ======================

namespace network
{
	// Verifies that the downloaded bytes carry a valid Ed25519 signature. The
	// expected signature comes from the catalog index rather than from response
	// headers, so callers know it before the download starts. Bytes accumulate
	// as they arrive and verification happens once in receive_end.
	struct check_signature_t : filter_t
	{
		check_signature_t (std::string const& signatureBase64, std::string const& publicKeyBase64);

		bool setup ();
		bool receive_data (char const* buf, size_t len);
		bool receive_end (std::string& error);

		std::string name ();

	private:
		std::string const _signature_base64;
		std::string const _public_key_base64;
		std::string _payload;
	};

} /* network */

#endif /* end of include guard: PUBKEY_H_VC2ABIZU */
