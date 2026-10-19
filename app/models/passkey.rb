# frozen_string_literal: true

# A WebAuthn credential a registered learner logs in with.
class Passkey < ApplicationRecord
  ulid :learner_id, primary_key: false
  belongs_to :learner
end
