# frozen_string_literal: true

# A browser that is acting as a learner. The browser holds a random bearer
# token; only its SHA-256 digest is stored, so a database leak does not leak
# usable tokens.
class LearnerSession < ApplicationRecord
  ulid :learner_id, primary_key: false
  belongs_to :learner

  # Returns the session and the token, which is not stored anywhere else.
  def self.start(learner)
    token = SecureRandom.urlsafe_base64(32)
    [create!(learner:, token_digest: digest(token)), token]
  end

  def self.from_token(token)
    return nil unless token.is_a?(String) && token.length.between?(20, 100)

    find_by(token_digest: digest(token))
  end

  def self.digest(token)
    OpenSSL::Digest::SHA256.hexdigest(token)
  end
end
