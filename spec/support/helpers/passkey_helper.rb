# frozen_string_literal: true

require 'webauthn/fake_client'

# Drives the passkey ceremonies with the webauthn gem's fake authenticator,
# from the origin the app is configured to accept.
module PasskeyHelper
  def fake_passkey_client
    WebAuthn::FakeClient.new(WebAuthn.configuration.allowed_origins.first)
  end

  def bearer(token)
    { 'Authorization' => "Bearer #{token}" }
  end

  def raw_user_handle(learner)
    WebAuthn.standard_encoder.decode(learner.webauthn_id)
  end
end

RSpec.configure { |config| config.include PasskeyHelper }
