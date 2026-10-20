# frozen_string_literal: true

# Passkeys are bound to the site the browser shows, which is the frontend, not
# this API. WEBAUTHN_ORIGINS lists the frontend origins that may register and
# log in (comma separated); WEBAUTHN_RP_ID is the domain the passkeys belong
# to, and defaults to the host of the first origin.
WebAuthn.configure do |config|
  config.allowed_origins = ENV.fetch('WEBAUTHN_ORIGINS', 'http://localhost:4444').split(',').map(&:strip)
  # .presence: docker-compose.prod.yml passes it empty when not configured.
  config.rp_id = ENV['WEBAUTHN_RP_ID'].presence || URI(config.allowed_origins.first).host
  config.rp_name = 'Manabase'
end
