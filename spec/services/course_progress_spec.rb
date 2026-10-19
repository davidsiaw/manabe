# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CourseProgress do
  subject(:progress) { described_class.new(learner, course) }

  let(:learner) { Learner.create! }
  let(:course) { CourseCatalog.new(Rails.root.join('spec/fixtures/courses')).find('sample') }

  def solve(*ids, round: 1)
    ids.each { |id| progress.record!(id, round) }
  end

  it 'starts with nothing, in round 1 only' do
    expect(progress.as_json).to eq(solved: [], revision: nil, times_solved: {}, times_completed: 0)
    expect(progress.started?).to be false
  end

  it 'lists solved problems in course order and ignores ones no longer in the course' do
    solve('three', 'one')
    learner.completions.create!(course_id: 'sample', problem_id: 'deleted')
    expect(progress.solved_in(1)).to eq %w[one three]
  end

  describe 'revisions' do
    before do
      solve('one', 'two', 'three')
      progress.start_revision!
    end

    it 'start from nothing and keep round 1' do
      expect(progress.as_json).to include(solved: %w[one two three], revision: { number: 2, solved: [] })
    end

    it 'count a problem once per round it was solved in' do
      solve('two', round: 2)
      expect(progress.times_solved).to eq('one' => 1, 'two' => 2, 'three' => 1)
    end

    it 'count as completed once every problem is solved again' do
      solve('one', 'two', round: 2)
      expect(progress.times_completed).to eq 1
      solve('three', round: 2)
      expect(progress.times_completed).to eq 2
    end

    it 'leave an unfinished revision behind when starting another' do
      solve('one', round: 2)
      progress.start_revision!
      expect(progress.as_json).to include(revision: { number: 3, solved: [] }, times_completed: 1)
      expect(progress.times_solved['one']).to eq 2
    end

    it 'take answers in round 1 and the current revision only' do
      progress.start_revision!
      expect([1, 2, 3].map { |round| progress.answerable_round?(round) }).to eq [true, false, true]
      expect { solve('one', round: 2) }.to raise_error(described_class::RoundNotCurrent)
    end

    it 'can be started before round 1 is complete' do
      other = described_class.new(Learner.create!, course)
      other.start_revision!
      expect(other.current_revision).to eq 2
    end

    it 'summarise the current revision for the course menu' do
      solve('one', round: 2)
      expect(progress.summary).to eq(solved_count: 3, next_problem_id: 'one', times_completed: 1,
                                     revision: { number: 2, solved_count: 1, next_problem_id: 'two' })
    end
  end

  it 'counts nothing as completed in a course without problems' do
    empty = instance_double(CourseCatalog::Course, id: 'empty', problem_order: [])
    expect(described_class.new(learner, empty).times_completed).to eq 0
  end
end
