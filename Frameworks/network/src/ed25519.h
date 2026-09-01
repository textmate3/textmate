#ifndef ED25519_H_QK3M7VNA
#define ED25519_H_QK3M7VNA

namespace network
{
	// Verifies an Ed25519 signature over ‘payload’. The signature and the public
	// key arrive base64 encoded, the key as the raw 32 byte form, the same format
	// Sparkle uses for ‘SUPublicEDKey’.
	//
	// Security.framework implements Ed25519 in ‘SecKeyVerifySignature’ but does
	// not declare the key type or algorithm constant in any public header. The
	// implementation resolves both symbols at runtime instead of linking them, so
	// if a future macOS stops exporting them the application still launches, and
	// verification fails with a clear error rather than the process failing to
	// start. Should that day come, the fallback is vendoring the small public
	// domain C implementation that Sparkle itself embeds for the same job.
	bool verify_ed25519_signature (std::string const& payload, std::string const& signatureBase64, std::string const& publicKeyBase64, std::string& error);

} /* network */

#endif /* end of include guard: ED25519_H_QK3M7VNA */
