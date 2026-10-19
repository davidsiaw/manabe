# Testing

```sh
heighliner login bundle exec rspec                  # everything
heighliner login bundle exec rspec spec/apis spec/services spec/models
heighliner login bundle exec rubocop
```

`spec/` is mounted into the container, so specs and the app code under test need no rebuild. Both must pass, and RuboCop must be clean, before handing work over.

## What is where

| Folder | Covers |
|---|---|
| `spec/services/` | `CourseCatalog` (including loading every real course), `CourseProgress`, `PasskeyCeremony` |
| `spec/apis/v1/` | Each API over HTTP: status codes, JSON shapes, error codes, authentication |
| `spec/models/`, `spec/sockets/`, ... | From the template |
| `spec/browser/` | From the template: admin login for `/swagger` and `/sidekiq`, in the shared chrome |
| `spec/fixtures/courses/sample/` | A three-problem course (`one`, `two` in a nested section, `three`) used by API and progress specs, so that editing real courses cannot break them |

API specs point the catalog at the fixtures with `allow(CourseCatalog).to receive(:new).and_return(CourseCatalog.new(Rails.root.join('spec/fixtures/courses')))`.

## Helpers

- `bearer(token)` returns the `Authorization` header. A session for a learner: `LearnerSession.start(learner).last` is the token.
- `fake_passkey_client` is a `WebAuthn::FakeClient` for the configured origin. It runs real ceremonies: `client.create(challenge: options['challenge'], user_verified: true)` makes a credential, `client.get(challenge:, user_handle: raw_user_handle(learner))` signs a login. A second client is a second authenticator, with passkeys the first does not have.
- `ActiveSupport::Testing::TimeHelpers` (`travel`) is included where needed, for challenge expiry.

## Gotchas

- `let(:json) { response.parsed_body }` is **memoized**: in an example that makes several requests it keeps returning the first response. Use `response.parsed_body` directly, or `def json = response.parsed_body`. This has caused wrong results twice.
- `post path, params: {...}` sends form parameters; the frontend sends JSON. Add `as: :json` when the difference matters (nested hashes such as `credential` need it).
- `spec/browser/restricted_area_spec.rb` (the Sidekiq dashboard) currently fails because `manabe-redis` does not resolve (development.md). The other 82 examples pass.

## End to end

Nothing runs the frontend against this backend automatically: the frontend's specs mock the API. After changing an endpoint's shape, check it against the real frontend: start both, open `https://manafe.<suffix>`, and go through the affected flow. For passkeys, a Selenium script with a virtual authenticator against the real HTTPS site works from the sandbox (`--ignore-certificate-errors`); see the frontend's testing notes.
