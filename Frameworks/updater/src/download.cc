#include "download.h"
#include <network/network.h>
#include <io/path.h>

namespace bundles_db
{
	// The index signature is a sibling resource: base64 Ed25519 over the exact
	// bytes of the index, served beside it with ‘.sig’ appended to the URL.
	static std::string download_index_signature (std::string const& url)
	{
		network::save_t archiver(false);
		std::string error = NULL_STR;
		long res = network::download(network::request_t(url, &archiver, nullptr), &error);

		std::string signature = NULL_STR;
		if(res == 200)
		{
			signature = path::content(archiver.path);
			while(!signature.empty() && (signature.back() == '\n' || signature.back() == '\r'))
				signature.pop_back();
		}
		else
		{
			os_log_error(OS_LOG_DEFAULT, "download_index_signature(‘%{public}s’): got ‘%ld’ from server (expected 200)", url.c_str(), res);
		}

		path::remove(archiver.path);
		return signature;
	}

	std::string download_etag (std::string const& url, std::string* etag, double* progress, double min, double max)
	{
		network::save_t archiver(false);
		network::header_t collect_etag("etag");

		std::string error = NULL_STR;
		long res = network::download(network::request_t(url, &archiver, &collect_etag, nullptr).set_entity_tag(etag ? *etag : NULL_STR).update_progress_variable(progress, min, max), &error);
		if(res == 304) // not modified, and verified when it was first downloaded
		{
			path::remove(archiver.path);
		}
		else if(res == 200)
		{
			std::string const signature = download_index_signature(url + ".sig");
			if(network::verify_ed25519_signature(path::content(archiver.path), signature, BUNDLE_PUBLIC_ED_KEY, error))
			{
				if(etag)
					*etag = collect_etag.value();
				return archiver.path;
			}

			os_log_error(OS_LOG_DEFAULT, "download_etag(‘%{public}s’): rejecting index: %{public}s", url.c_str(), error.c_str());
			path::remove(archiver.path);
		}
		else
		{
			if(res != 0)
					os_log_error(OS_LOG_DEFAULT, "download_etag(‘%{public}s’): got ‘%ld’ from server (expected 200)", url.c_str(), res);
			else	os_log_error(OS_LOG_DEFAULT, "download_etag(‘%{public}s’): %{public}s", url.c_str(), error.c_str());
		}
		return NULL_STR;
	}
}
