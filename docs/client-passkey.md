# Native client passkey sign-in

The client uses the OS passkey sheet directly (AuthenticationServices on Apple,
Credential Manager on Android, WebAuthn on Windows). No browser, localhost server,
Redis handoff, URL credential transfer or new passkey registration is involved.
The original challenge/options from `/api/auth/login` are submitted to the existing
`/api/auth/login/passkey` verifier with the signed assertion.

The button appears only when all of these are true:

- The account has an enabled passkey and valid authentication options.
- The server reports native passkeys are configured for this platform.
- The platform supports native passkeys.
- A biometric method is enrolled and available for the current device user.

Capability checks do not show a biometric prompt. Windows uses
`WinBioGetEnrolledFactors` for the current user's SID; a Windows Hello PIN alone
is insufficient. Linux has no native implementation and shows TOTP instead.
The native OS may offer its own credential-unlock fallback; the app does not
replace the cryptographic passkey proof with a successful biometric prompt.

TOTP remains available when enabled on the account. If a passkey-only account
cannot use native passkeys, the app asks the user to configure TOTP on the web
account. It does not silently enroll TOTP or bypass the second factor.

## Release setup

Publish the website's `.well-known` routes and native-aware login update.
Set these public identity values in the website's deployment environment:

- `OCULVE_APPLE_APP_IDS`: comma-separated actual application identifiers,
  each `APP_ID_PREFIX.com.oculve.app` (normally Apple Team ID as the prefix).
- `OCULVE_ANDROID_CERTIFICATE_SHA256`: comma-separated SHA-256 fingerprints
  of the certificates that actually sign distributed APKs. For Google Play,
  use the app signing certificate, not only the upload certificate.

No defaults or generic debug certificate are trusted in production. An absent
configuration disables native passkeys on the corresponding platform and leaves
TOTP available. Android expected origins are constructed from the configured
certificate digests, never from untrusted request data.

Serve both association documents on the relying-party domain without redirects:

- `/.well-known/apple-app-site-association`
- `/.well-known/assetlinks.json`

Oculve's apex currently redirects to www at the hosting layer. If existing
passkeys use the apex RP ID, exempt the `.well-known` paths from that redirect;
do not change the RP ID of existing credentials to work around it.

Apple apps must be signed with a matching provisioning profile that enables
Associated Domains. Both app entitlements already contain
`webcredentials:oculve.com` and `webcredentials:www.oculve.com`.
An unsigned local build is not proof of native passkey sign-in. The repository's
iOS team and the locally installed development certificate have different team
IDs; select the release team before configuring the website association.

## Validation

Use real devices and registered web passkeys on each target OS. Cover biometric
hardware absent, biometrics unenrolled, TOTP-only/passkey-only/combined accounts,
no matching local passkey, cancellation, invalid signatures, domain association,
Android app-signing certificate mismatch, and session persistence on restart.
