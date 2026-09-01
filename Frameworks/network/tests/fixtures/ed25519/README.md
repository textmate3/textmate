# Ed25519 fixtures

Used by `../../t_check_signature.cc` and `../../t_ed25519.cc`.

| File                      | What it is                                             |
| ------------------------- | ------------------------------------------------------ |
| `public_key.base64`       | base64 of the raw 32 byte Ed25519 public key           |
| `signed_payload.txt`      | the signed content                                     |
| `signature.base64`        | base64 of the 64 byte signature over that payload      |
| `other_public_key.base64` | a second key pair's public half, which must NOT verify |

The public keys are the raw 32 byte form, the same format Sparkle uses for `SUPublicEDKey`, and
the form `SecKeyCreateWithData` accepts for the Ed25519 key type. The subject public key info
form is rejected by that call, which is why the recipe below strips the 12 byte DER header with
`tail -c 32`.

The private keys are deliberately absent. Tests only need the public halves, and committing a
private key invites secret scanners to flag the repository for no benefit.

To regenerate everything, including fresh key pairs:

```sh
openssl genpkey -algorithm ED25519 -out /tmp/signing_key_private.pem
openssl genpkey -algorithm ED25519 -out /tmp/other_key_private.pem
printf 'This payload is signed with the Ed25519 test key.\n' > signed_payload.txt
openssl pkey -in /tmp/signing_key_private.pem -pubout -outform DER | tail -c 32 | base64 > public_key.base64
openssl pkey -in /tmp/other_key_private.pem -pubout -outform DER | tail -c 32 | base64 > other_public_key.base64
openssl pkeyutl -sign -inkey /tmp/signing_key_private.pem -rawin -in signed_payload.txt | base64 > signature.base64
rm /tmp/signing_key_private.pem /tmp/other_key_private.pem
```
