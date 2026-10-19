# frozen_string_literal: true

class AddRevisionRounds < ActiveRecord::Migration[8.1]
  def change
    # Round 1 is a learner's first time through a course; rounds 2 and up are
    # revisions. Existing completions are round 1.
    add_column :completions, :round, :integer, null: false, default: 1
    remove_index :completions, %i[learner_id course_id problem_id], unique: true
    add_index :completions, %i[learner_id course_id round problem_id], unique: true

    # A revision the learner started. Round 1 needs no row. The highest
    # number is the current revision; earlier unfinished ones were abandoned.
    create_table :revisions, id: :uuid do |t|
      t.references :learner, type: :uuid, null: false, foreign_key: true, index: false
      t.string :course_id, null: false
      t.integer :number, null: false
      t.datetime :updated_at
    end
    add_index :revisions, %i[learner_id course_id number], unique: true
  end
end
