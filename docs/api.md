# API

Everything is under `/api/v1` and speaks JSON. Requests with a body send `Content-Type: application/json`. Errors are `{"error": "<code>"}` with the status shown.

**Auth** column: *required* means `Authorization: Bearer <token>` must name a live session (else 401 `unauthorized`); *optional* means the response says more with one.

## Health

| Method and path | Auth | Response |
|---|---|---|
| `GET /health` | none | `{"result": "ok"}` |

## Learners and accounts

| Method and path | Auth | Body | Response |
|---|---|---|---|
| `POST /learners` | none | none | 201 `{"token": "..."}`: a new anonymous learner and a session for it |
| `GET /me` | required | | `{"email": null or "...", "courses": [summary, ...]}`: only courses the learner has started |
| `POST /registration/options` | required | `{"email": "..."}` | WebAuthn creation options (see below) |
| `POST /registration` | required | `{"credential": {...}}` | `{"email": "..."}`: the current learner is now registered |
| `POST /login/options` | none | none | WebAuthn request options |
| `POST /login` | none | `{"credential": {...}}` | `{"token": "...", "email": "..."}`: a new session for the passkey's learner |
| `DELETE /session` | required | | 204: ends the current session only |

Errors from registration and login:

| Code | Status | When |
|---|---|---|
| `invalid_email` | 422 | The email does not look like one. |
| `email_taken` | 409 | Another learner has this email (case-insensitively). |
| `already_registered` | 409 | The current learner already has an email. |
| `challenge_expired` | 422 | The challenge is unknown, used, older than five minutes, or belongs to another learner. |
| `invalid_credential` | 422 | The credential is malformed, or fails verification (origin, challenge, signature). |
| `unknown_passkey` | 422 | Login with a passkey the server does not know, or whose user handle does not match. |

The options are what the webauthn gem produces, with binary fields in base64url, for example:

```json
{"challenge": "ryTx...", "timeout": 120000, "rp": {"name": "Manabase", "id": "manafe.localdev.astrobunny.net"},
 "user": {"id": "...", "name": "a@example.com", "displayName": "a@example.com"},
 "pubKeyCredParams": [{"type": "public-key", "alg": -7}, ...],
 "authenticatorSelection": {"residentKey": "required", "userVerification": "preferred"}}
```

The credential is the browser's `PublicKeyCredential` as JSON with base64url binary fields: `type`, `id`, `rawId`, `response` (`clientDataJSON` plus `attestationObject` for registration, or `authenticatorData`, `signature` and `userHandle` for login) and `clientExtensionResults`.

## Courses

| Method and path | Auth | Response |
|---|---|---|
| `GET /courses` | optional | `[summary, ...]`, every course, sorted by id |
| `GET /courses/:course_id` | none | the course and its section tree |
| `GET /courses/:course_id/progress` | required | progress (below) |
| `POST /courses/:course_id/revisions` | required | 201 progress: a new revision started. 409 `revision_already_started` on a race |

A **summary**; the progress fields are `null` without a learner:

```json
{"id": "rust-basics", "title": "Rust Basics", "description": "...", "problem_count": 12,
 "solved_count": 3, "next_problem_id": "integers", "times_completed": 0,
 "revision": {"number": 2, "solved_count": 1, "next_problem_id": "syntax"}}
```

`next_problem_id` is the first problem not solved in that round (the first problem if all are). `revision` is `null` until one is started.

A **course**:

```json
{"id": "sample", "title": "Sample", "description": "...",
 "sections": [{"title": "First", "problems": [{"id": "one", "title": "Problem one"}],
               "sections": [{"title": "Nested", "problems": [...], "sections": []}]}]}
```

**Progress**:

```json
{"solved": ["one", "two"],
 "revision": {"number": 2, "solved": ["one"]},
 "times_solved": {"one": 2, "two": 1},
 "times_completed": 1}
```

`solved` is round 1, `revision` the current revision (or `null`), `times_solved` counts the rounds each problem was solved in (all rounds, including abandoned revisions), and `times_completed` the rounds in which every problem is solved. Problems no longer in the course are left out everywhere.

## Problems

| Method and path | Auth | Body | Response |
|---|---|---|---|
| `GET /courses/:course_id/problems/:problem_id` | none; required with `?round=N`, N >= 2 | | the problem |
| `POST /courses/:course_id/problems/:problem_id/answer` | required | `{"choice": "b", "round": 1}` | the verdict |

A **problem** never says which choice is correct:

```json
{"id": "integers", "title": "Integers", "body": "...", "type": "multiple_choice",
 "question": "What is the largest value a u8 can hold?",
 "choices": [{"id": "a", "text": "127"}, {"id": "b", "text": "128"}, ...],
 "previous": {"id": "literals", "title": "Literals"}, "next": null}
```

With `?round=N` for the current revision, the choices are shuffled (see progress.md).

The **verdict**: `{"correct": false}`, or `{"correct": true, "explanation": "...", "progress": {...}}` with the learner's progress after recording the answer. `round` defaults to 1, and must be 1 or the current revision; otherwise 409 `round_not_current`. Round 0 or less is 400.

## Everything else

- Unknown course or problem: 404 `not_found`. Unknown path: 404 `not_found`.
- `/swagger` (after an admin login) lists the endpoints as Grape describes them.
