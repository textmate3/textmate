# Ed25519 fixtures

Test material for `t_ed25519.cc`. The private keys are test keys committed on purpose so the
fixtures can be regenerated or extended. They sign nothing outside this directory.

Generated with OpenSSL 3:

```sh
openssl genpkey -algorithm ED25519 -out signing_key_private.pem
openssl genpkey -algorithm ED25519 -out other_key_private.pem
openssl pkey -in signing_key_private.pem -pubout -outform DER | tail -c 32 | base64 > public_key.base64
openssl pkey -in other_key_private.pem -pubout -outform DER | tail -c 32 | base64 > other_public_key.base64
openssl pkeyutl -sign -inkey signing_key_private.pem -rawin -in signed_payload.txt | base64 > signature.base64
```

The public keys are base64 of the raw 32 byte key, the same format Sparkle uses for
`SUPublicEDKey`, and the format `SecKeyCreateWithData` expects for the Ed25519 key type. The
subject public key info form is rejected by that call, which is why `tail -c 32` strips the
12 byte DER header.
