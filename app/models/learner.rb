# frozen_string_literal: true

# A student. Anonymous until they register an email and a passkey; their
# progress stays with them either way.
class Learner < ApplicationRecord
  has_many :completions, dependent: :destroy
  has_many :revisions, dependent: :destroy
  has_many :sessions, class_name: 'LearnerSession', dependent: :destroy
  has_many :passkeys, dependent: :destroy

  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_nil: true

  def registered?
    email.present?
  end
end
