# Learners, sessions and passkeys

## Learners and sessions

- `POST /learners` creates an anonymous `Learner` and a `LearnerSession`, and returns the session's token. The frontend calls it on a first visit.
- A token is 32 random bytes, base64url. The table keeps only `SHA-256(token)` (`LearnerSession.digest`), so a database leak does not leak usable tokens. `LearnerSession.from_token` ignores anything that is not a string of 20 to 100 characters before hashing.
- `AuthHelpers#current_session` reads `Authorization: Bearer <token>`. `current_learner` answers 401 `unauthorized` without a live session; `optional_learner` returns nil.
- A learner can have many sessions (one per browser). `DELETE /session` deletes only the current one.
- Abandoned anonymous learners are never cleaned up yet (see roadmap.md).

## Registering: an anonymous learner gets an email and a passkey

`PasskeyCeremony` (`app/services/passkey_ceremony.rb`) does both ceremonies; `AccountApi` only maps them to HTTP.

1. `POST /registration/options {email}`, with the anonymous learner's session. Refused if the learner already has an email (`already_registered`), the email does not look like one (`invalid_email`), or another learner has it (`email_taken`; `email` is citext, so case does not matter, but `a+b@x` and `a@x` are different). The learner gets a `webauthn_id` (the WebAuthn user handle) if it has none. The options require a **discoverable** credential (`residentKey: required`), which usernameless login needs, and prefer user verification. The challenge is stored as a `PasskeyChallenge` with purpose `registration`, the learner and the email.
2. The browser creates the passkey.
3. `POST /registration {credential}`, same session. The challenge the browser signed is read from the credential's client data and must match a live challenge for this learner, which is used up. The gem verifies the attestation against it (origin, RP id, challenge). Then, in one transaction, the learner gets the email and a `Passkey`. A race on the email hits the unique index and answers `email_taken`.

The learner keeps its id, sessions and progress: registering does not log anyone in or out.

## Logging in

1. `POST /login/options`, no session needed. The options have an empty `allowCredentials`, so the browser offers every passkey it has for the site. The challenge is stored with purpose `login` and no learner.
2. The browser signs with the chosen passkey.
3. `POST /login {credential}`. The challenge is found and used up as above. The passkey is looked up by the credential id, and its learner's `webauthn_id` must equal the credential's user handle (`unknown_passkey` otherwise). The gem verifies the signature and sign count; the new sign count is saved. A **new** session is created for that learner and its token returned.

The browser's previous anonymous session is not touched, and its progress is not merged: that was a product decision (system.md).

## Configuration

`config/initializers/webauthn.rb`:

| Setting | From | Default |
|---|---|---|
| allowed origins | `WEBAUTHN_ORIGINS`, comma separated | `http://localhost:4444` |
| RP id | `WEBAUTHN_RP_ID` | the host of the first origin |
| RP name | fixed | `Manabase` |

Heighliner.config allows two origins, the frontend's `https://manafe.<suffix>` and the mobile frontend's `https://manamo.<suffix>`, and sets the RP id to `<suffix>`, their common parent domain, so that one passkey logs in on both. Passkeys belong to the site the browser runs the ceremony on, and an RP id may be that site's host or any parent of it short of a public suffix. In production, serve both frontends from one domain, or from subdomains of one, for the same reason. Passkeys need HTTPS (or `localhost`). Changing the RP id orphans every existing passkey.

## Gem notes (webauthn 3.4)

- `options.as_json` has symbol keys; `PasskeyCeremony` returns `as_json.deep_stringify_keys`.
- `credential.response.client_data.challenge` is the decoded bytes; encode it with `WebAuthn.standard_encoder` to compare with stored challenges.
- Malformed browser input raises all sorts of errors inside the gem (`NoMethodError`, `KeyError`, ...). `PasskeyCeremony#parse` turns them all into `invalid_credential`; `#verify` does the same for `WebAuthn::Error`.
- `WebAuthn::FakeClient` (needs `require 'webauthn/fake_client'`) runs real ceremonies in specs. See testing.md.
