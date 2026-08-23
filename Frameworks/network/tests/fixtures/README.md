# Signature verification fixtures

Used by `../t_check_signature.cc`.

| File                      | What it is                                                        |
| ------------------------- | ------------------------------------------------------------------ |
| `signing_key_public.pem`  | 2048-bit RSA public key, PEM, the form `key_chain_t` imports       |
| `signed_payload.txt`      | the signed content                                                 |
| `signature_sha1.base64`   | valid signature over that payload, SHA-1, base64 as the header carries it |
| `signature_sha256.base64` | same payload signed with SHA-256, which must NOT verify            |
| `signature_sha512.base64` | same payload signed with SHA-512, which must NOT verify            |

The private key is deliberately absent. Tests only need the public half, and committing a private key
invites secret scanners to flag the repository for no benefit.

To regenerate everything, including a fresh key pair:

```sh
openssl genrsa -out /tmp/signing_key_private.pem 2048
openssl rsa -in /tmp/signing_key_private.pem -pubout -out signing_key_public.pem
printf 'The quick brown fox jumps over the lazy dog.\n' > signed_payload.txt
for alg in sha1 sha256 sha512; do
  openssl dgst -$alg -sign /tmp/signing_key_private.pem -out /tmp/sig.bin signed_payload.txt
  base64 -i /tmp/sig.bin -o signature_$alg.base64
done
rm /tmp/signing_key_private.pem /tmp/sig.bin
```

## Why the SHA-256 and SHA-512 signatures are here

They are negative fixtures, and they document a finding. `SecVerifyTransformCreate` is called without
naming a digest, so it picks one implicitly. Measured on macOS 26: it accepts **SHA-1 only**. The other
two are valid signatures over the same payload by the same key, and both are rejected.

That matters because `SecKeyVerifySignature`, the replacement, requires the algorithm to be named
explicitly. These fixtures pin down which one preserves current behavior, and prove the other choices
fail loudly rather than silently.
