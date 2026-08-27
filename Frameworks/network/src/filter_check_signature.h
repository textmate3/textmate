#ifndef PUBKEY_H_VC2ABIZU
#define PUBKEY_H_VC2ABIZU

#include "download.h" // filter_t
#include "key_chain.h"

// ======================
// = Validate signature =
// ======================

namespace network
{
	struct check_signature_t : filter_t
	{
		check_signature_t (key_chain_t const& keyChain, std::string const& signeeHeader, std::string const& signatureHeader);
		~check_signature_t ();

		bool setup ();
		bool receive_header (std::string const& header, std::string const& value);
		bool receive_data (char const* buf, size_t len);
		bool receive_end (std::string& error);

		std::string name ();

		std::string const& signee () const    { return _signee_header; }
		std::string const& signature () const { return _signature_header; }

		// Bypass signature checking. Callers set this when the download URL
		// points at localhost during local development against the
		// `api.textmate3.com` stand-in server, which serves unsigned bundles.
		void skip_validation ()               { _skip = true; }

	private:
		key_chain_t const _key_chain;
		std::string const _signee_header;
		std::string const _signature_header;

		CFMutableDataRef _data;

		std::string _signee    = NULL_STR;
		std::string _signature = NULL_STR;
		bool        _skip      = false;
	};

} /* network */

#endif /* end of include guard: PUBKEY_H_VC2ABIZU */
