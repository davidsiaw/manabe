# frozen_string_literal: true

# A WebAuthn challenge between handing out options and verifying the
# browser's answer. Each one can be used once, within LIFETIME.
class PasskeyChallenge < ApplicationRecord
  LIFETIME = 5.minutes

  # Not `ulid :learner_id`: that also fills in a random ULID when the column
  # is nil, and login challenges have no learner.
  attribute :learner_id, ULID::Rails::Type.new
  belongs_to :learner, optional: true

  def self.issue!(challenge:, purpose:, learner: nil, email: nil)
    where(expires_at: ...Time.current).delete_all
    create!(challenge:, purpose:, learner:, email:, expires_at: LIFETIME.from_now)
  end

  # Returns the challenge and deletes it, or nil if there is no live one.
  # The delete is the check, so two requests cannot both use it.
  def self.consume(challenge:, purpose:, learner: nil)
    record = find_by(challenge:, purpose:, learner:)
    return nil unless record&.expires_at&.future?
    return nil unless where(id: record.id).delete_all == 1

    record
  end
end
