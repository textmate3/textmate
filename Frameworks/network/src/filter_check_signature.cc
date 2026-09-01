#include "filter_check_signature.h"
#include "ed25519.h"

namespace network
{
	check_signature_t::check_signature_t (std::string const& signatureBase64, std::string const& publicKeyBase64) : _signature_base64(signatureBase64), _public_key_base64(publicKeyBase64)
	{
	}

	bool check_signature_t::setup ()
	{
		_payload.clear();
		return true;
	}

	bool check_signature_t::receive_data (char const* buf, size_t len)
	{
		_payload.append(buf, len);
		return true;
	}

	bool check_signature_t::receive_end (std::string& error)
	{
		if(_signature_base64 == NULL_STR || _signature_base64.empty())
			return (error = "Missing signature."), false;
		return verify_ed25519_signature(_payload, _signature_base64, _public_key_base64, error);
	}

	std::string check_signature_t::name ()
	{
		return "signature";
	}

} /* network */
