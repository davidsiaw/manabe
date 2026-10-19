# frozen_string_literal: true

# Registering and logging in with passkeys. Each ceremony has two steps: the
# browser asks for options (which carry a fresh challenge), has the
# authenticator sign them, and sends back the credential to verify.
#
# Login is usernameless: no email is asked for, and the browser offers the
# passkeys it holds for this site. That needs discoverable credentials, which
# registration therefore requires.
class PasskeyCeremony
  # A ceremony that did not succeed. `code` is what the API reports.
  class Failed < StandardError
    attr_reader :code

    def initialize(code)
      @code = code
      super(code.to_s)
    end
  end

  def registration_options(learner, email)
    email = email.to_s.strip
    raise Failed, :already_registered if learner.registered?
    raise Failed, :invalid_email unless URI::MailTo::EMAIL_REGEXP.match?(email)
    raise Failed, :email_taken if Learner.exists?(email:)

    learner.update!(webauthn_id: WebAuthn.generate_user_id) unless learner.webauthn_id
    options = WebAuthn::Credential.options_for_create(
      user: { id: learner.webauthn_id, name: email, display_name: email },
      authenticator_selection: { resident_key: 'required', user_verification: 'preferred' }
    )
    PasskeyChallenge.issue!(challenge: options.challenge, purpose: 'registration', learner:, email:)
    options.as_json.deep_stringify_keys
  end

  # Gives the learner the email from the options step and the new passkey.
  def register!(learner, credential_json)
    credential, signed_challenge = parse { WebAuthn::Credential.from_create(credential_json) }
    challenge = PasskeyChallenge.consume(challenge: signed_challenge, purpose: 'registration', learner:)
    raise Failed, :challenge_expired unless challenge

    verify { credential.verify(challenge.challenge) }
    Learner.transaction do
      learner.update!(email: challenge.email)
      learner.passkeys.create!(external_id: credential.id, public_key: credential.public_key,
                               sign_count: credential.sign_count)
    end
    learner
  rescue ActiveRecord::RecordNotUnique
    raise Failed, :email_taken
  end

  def login_options
    options = WebAuthn::Credential.options_for_get(user_verification: 'preferred')
    PasskeyChallenge.issue!(challenge: options.challenge, purpose: 'login')
    options.as_json.deep_stringify_keys
  end

  # Returns the learner the passkey belongs to.
  def login!(credential_json)
    credential, signed_challenge = parse { WebAuthn::Credential.from_get(credential_json) }
    challenge = PasskeyChallenge.consume(challenge: signed_challenge, purpose: 'login')
    raise Failed, :challenge_expired unless challenge

    passkey = Passkey.find_by(external_id: credential.id)
    raise Failed, :unknown_passkey unless passkey && credential.user_handle == passkey.learner.webauthn_id

    verify { credential.verify(challenge.challenge, public_key: passkey.public_key, sign_count: passkey.sign_count) }
    passkey.update!(sign_count: credential.sign_count)
    passkey.learner
  end

  private

  # Returns the credential and the challenge the browser signed, encoded as
  # in the options. That challenge only finds the stored one; verify then
  # checks that the two match. Malformed input from the browser raises all
  # sorts of errors inside the gem, so they are all reported the same way.
  def parse
    credential = yield
    [credential, WebAuthn.standard_encoder.encode(credential.response.client_data.challenge)]
  rescue WebAuthn::Error, KeyError, NoMethodError, TypeError, ArgumentError, JSON::ParserError
    raise Failed, :invalid_credential
  end

  def verify
    yield
  rescue WebAuthn::Error
    raise Failed, :invalid_credential
  end
end
