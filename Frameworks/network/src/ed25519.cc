#include "ed25519.h"
#include <cf/cf.h>
#include <text/decode.h>
#include <text/format.h>
#include <dlfcn.h>

namespace
{
	// The two constants Security.framework exports but does not declare. Resolved
	// once via dlsym against the already loaded process image, never linked, so a
	// macOS that stops exporting them costs us verification, not launch.
	struct ed25519_symbols_t
	{
		CFStringRef key_type  = nullptr;
		CFStringRef algorithm = nullptr;
	};

	static ed25519_symbols_t const& ed25519_symbols ()
	{
		static ed25519_symbols_t const res = []{
			ed25519_symbols_t symbols;
			if(CFStringRef* pointer = (CFStringRef*)dlsym(RTLD_DEFAULT, "kSecAttrKeyTypeEd25519"))
				symbols.key_type = *pointer;
			if(CFStringRef* pointer = (CFStringRef*)dlsym(RTLD_DEFAULT, "kSecKeyAlgorithmEdDSASignatureMessageCurve25519SHA512"))
				symbols.algorithm = *pointer;
			return symbols;
		}();
		return res;
	}
}

namespace network
{
	bool verify_ed25519_signature (std::string const& payload, std::string const& signatureBase64, std::string const& publicKeyBase64, std::string& error)
	{
		auto const& symbols = ed25519_symbols();
		if(!symbols.key_type || !symbols.algorithm)
			return (error = "Ed25519 is unavailable: this macOS no longer exports the Security framework symbols."), false;

		std::string const signature = decode::base64(signatureBase64);
		if(signature.size() != 64)
			return (error = text::format("Bad signature: expected 64 bytes, got %zu.", signature.size())), false;

		std::string const publicKey = decode::base64(publicKeyBase64);
		if(publicKey.size() != 32)
			return (error = text::format("Bad public key: expected 32 bytes, got %zu.", publicKey.size())), false;

		bool res = false;

		CFDataRef keyData = CFDataCreateWithBytesNoCopy(kCFAllocatorDefault, (const UInt8*)publicKey.data(), publicKey.size(), kCFAllocatorNull);
		CFTypeRef attributeKeys[]   = { kSecAttrKeyType,  kSecAttrKeyClass };
		CFTypeRef attributeValues[] = { symbols.key_type, kSecAttrKeyClassPublic };
		CFDictionaryRef attributes = CFDictionaryCreate(kCFAllocatorDefault, attributeKeys, attributeValues, 2, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);

		CFErrorRef err = nullptr;
		if(SecKeyRef key = SecKeyCreateWithData(keyData, attributes, &err))
		{
			CFDataRef payloadData   = CFDataCreateWithBytesNoCopy(kCFAllocatorDefault, (const UInt8*)payload.data(), payload.size(), kCFAllocatorNull);
			CFDataRef signatureData = CFDataCreateWithBytesNoCopy(kCFAllocatorDefault, (const UInt8*)signature.data(), signature.size(), kCFAllocatorNull);

			res = SecKeyVerifySignature(key, symbols.algorithm, payloadData, signatureData, &err);
			if(!res)
			{
				error = "Bad signature.";
				if(err)
					CFRelease(err);
			}

			CFRelease(signatureData);
			CFRelease(payloadData);
			CFRelease(key);
		}
		else
		{
			error = text::format("Error creating public key: ‘%s’.", cf::to_s(err).c_str());
			if(err)
				CFRelease(err);
		}

		CFRelease(attributes);
		CFRelease(keyData);

		return res;
	}

} /* network */
