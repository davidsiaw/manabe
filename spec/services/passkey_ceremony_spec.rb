# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PasskeyCeremony do
  include ActiveSupport::Testing::TimeHelpers

  subject(:ceremony) { described_class.new }

  let(:client) { fake_passkey_client }
  let(:learner) { Learner.create! }

  def register(learner, email = 'student@example.com')
    options = ceremony.registration_options(learner, email)
    ceremony.register!(learner, client.create(challenge: options['challenge'], user_verified: true))
  end

  def log_in(user_handle: raw_user_handle(learner))
    options = ceremony.login_options
    ceremony.login!(client.get(challenge: options['challenge'], user_verified: true, user_handle:))
  end

  describe 'registration' do
    it 'gives the learner the email and a passkey, and keeps their progress' do
      learner.completions.create!(course_id: 'c', problem_id: 'p')
      register(learner)
      learner.reload
      expect([learner.email, learner.passkeys.count, learner.completions.count]).to eq ['student@example.com', 1, 1]
    end

    it 'asks for a discoverable passkey, which usernameless login needs' do
      options = ceremony.registration_options(learner, 'student@example.com')
      expect(options['authenticatorSelection']).to include('residentKey' => 'required')
    end

    it 'refuses an email that is already registered, in any case' do
      register(Learner.create!, 'Student@Example.com')
      expect { ceremony.registration_options(learner, 'student@example.COM') }
        .to raise_error(described_class::Failed, 'email_taken')
    end

    it 'treats plus addresses as different emails' do
      register(Learner.create!, 'student@example.com')
      expect { register(learner, 'student+rust@example.com') }.not_to raise_error
    end

    it 'refuses a learner who is already registered' do
      register(learner)
      expect { ceremony.registration_options(learner, 'other@example.com') }
        .to raise_error(described_class::Failed, 'already_registered')
    end

    it 'refuses something that is not an email' do
      expect { ceremony.registration_options(learner, 'not an email') }
        .to raise_error(described_class::Failed, 'invalid_email')
    end

    it 'refuses a credential signed over another learner\'s challenge' do
      options = ceremony.registration_options(Learner.create!, 'other@example.com')
      credential = client.create(challenge: options['challenge'])
      expect { ceremony.register!(learner, credential) }.to raise_error(described_class::Failed, 'challenge_expired')
    end

    it 'refuses an expired challenge' do
      options = ceremony.registration_options(learner, 'student@example.com')
      credential = client.create(challenge: options['challenge'])
      travel(PasskeyChallenge::LIFETIME + 1.second) do
        expect { ceremony.register!(learner, credential) }.to raise_error(described_class::Failed, 'challenge_expired')
      end
    end

    it 'refuses a credential from another origin' do
      options = ceremony.registration_options(learner, 'student@example.com')
      credential = WebAuthn::FakeClient.new('https://evil.example').create(challenge: options['challenge'])
      expect { ceremony.register!(learner, credential) }.to raise_error(described_class::Failed, 'invalid_credential')
    end

    it 'refuses garbage' do
      expect { ceremony.register!(learner, { 'id' => 'x' }) }
        .to raise_error(described_class::Failed, 'invalid_credential')
    end
  end

  describe 'login' do
    before { register(learner) }

    it 'returns the learner the passkey belongs to' do
      expect(log_in).to eq learner
    end

    it 'uses each challenge only once' do
      options = ceremony.login_options
      credential = client.get(challenge: options['challenge'], user_handle: raw_user_handle(learner))
      ceremony.login!(credential)
      expect { ceremony.login!(credential) }.to raise_error(described_class::Failed, 'challenge_expired')
    end

    it 'refuses a passkey that claims to belong to someone else' do
      expect { log_in(user_handle: 'someone else') }.to raise_error(described_class::Failed, 'unknown_passkey')
    end

    it 'refuses a passkey it does not know' do
      stranger = fake_passkey_client
      stranger.create # a passkey the server never saw registered
      credential = stranger.get(challenge: ceremony.login_options['challenge'], user_handle: raw_user_handle(learner))
      expect { ceremony.login!(credential) }.to raise_error(described_class::Failed, 'unknown_passkey')
    end
  end
end
