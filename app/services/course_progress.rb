# frozen_string_literal: true

# A learner's progress through one course, across rounds. Round 1 is the
# first time through; each revision is a further round, starting from
# nothing. Only problems that are still in the course count.
class CourseProgress
  class RoundNotCurrent < StandardError; end

  attr_reader :learner, :course

  def initialize(learner, course)
    @learner = learner
    @course = course
  end

  # The number of the revision in progress, or nil before the first one.
  def current_revision
    revision_numbers.max
  end

  # Learners answer in round 1 or in their current revision.
  def answerable_round?(round)
    round == 1 || (round >= 2 && round == current_revision)
  end

  # Solved problem ids in a round, in course order.
  def solved_in(round)
    ids = solved_by_round.fetch(round, [])
    course.problem_order.select { |id| ids.include?(id) }
  end

  # How many rounds each problem has been solved in.
  def times_solved
    solved_by_round.values.flatten.tally
  end

  # Rounds, including round 1 and abandoned revisions, in which every
  # problem is solved.
  def times_completed
    return 0 if course.problem_order.empty?

    ([1] + revision_numbers).count { |round| (course.problem_order - solved_in(round)).empty? }
  end

  def started?
    solved_by_round.any? || revision_numbers.any?
  end

  # Records a correct answer. Raises RoundNotCurrent for any other round.
  def record!(problem_id, round)
    raise RoundNotCurrent unless answerable_round?(round)

    learner.completions.create_or_find_by!(course_id: course.id, problem_id:, round:)
    reset!
  end

  # Starts the next revision; an unfinished current one is left behind.
  def start_revision!
    learner.revisions.create!(course_id: course.id, number: [current_revision || 1, 1].max + 1)
    reset!
  end

  # For the course page: everything needed to draw the tree in either mode.
  def as_json(*)
    revision = current_revision
    {
      solved: solved_in(1),
      revision: revision && { number: revision, solved: solved_in(revision) },
      times_solved:,
      times_completed:
    }
  end

  # For the course menu and the learner's page.
  def summary
    revision = current_revision
    {
      solved_count: solved_in(1).size,
      next_problem_id: next_unsolved(1),
      times_completed:,
      revision: revision && { number: revision, solved_count: solved_in(revision).size,
                              next_problem_id: next_unsolved(revision) }
    }
  end

  private

  def next_unsolved(round)
    (course.problem_order - solved_in(round)).first || course.problem_order.first
  end

  def solved_by_round
    @solved_by_round ||= learner.completions.where(course_id: course.id, problem_id: course.problem_order)
                                .pluck(:round, :problem_id)
                                .group_by(&:first).transform_values { |pairs| pairs.map(&:last) }
  end

  def revision_numbers
    @revision_numbers ||= learner.revisions.where(course_id: course.id).pluck(:number)
  end

  def reset!
    @solved_by_round = nil
    @revision_numbers = nil
    self
  end
end
