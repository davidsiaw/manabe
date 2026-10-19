# frozen_string_literal: true

# A learner going through a course again from the start. Numbered from 2,
# because round 1 is their first time through.
class Revision < ApplicationRecord
  ulid :learner_id, primary_key: false
  belongs_to :learner

  validates :course_id, presence: true
  validates :number, numericality: { greater_than_or_equal_to: 2 }
end
