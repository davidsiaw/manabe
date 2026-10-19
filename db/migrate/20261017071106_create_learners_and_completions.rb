# frozen_string_literal: true

class CreateLearnersAndCompletions < ActiveRecord::Migration[8.1]
  def change
    # An anonymous learner. The browser keeps the id in localStorage. When
    # accounts arrive, a learner gets linked to a user rather than replaced,
    # so that progress made before signing up is kept.
    # No created_at, as elsewhere in this app: the ULID id records it.
    create_table :learners, id: :uuid do |t|
      t.datetime :updated_at
    end

    # A problem the learner has answered correctly. Course and problem ids are
    # the slugs from the YAML, not foreign keys, because courses live on disk.
    create_table :completions, id: :uuid do |t|
      t.references :learner, type: :uuid, null: false, foreign_key: true, index: false
      t.string :course_id, null: false
      t.string :problem_id, null: false
      t.datetime :updated_at
    end
    add_index :completions, %i[learner_id course_id problem_id], unique: true
  end
end
