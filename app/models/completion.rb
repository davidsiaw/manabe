# frozen_string_literal: true

# A problem a learner has answered correctly.
class Completion < ApplicationRecord
  ulid :learner_id, primary_key: false
  belongs_to :learner

  validates :course_id, :problem_id, presence: true
  validates :round, numericality: { greater_than_or_equal_to: 1 }
end
