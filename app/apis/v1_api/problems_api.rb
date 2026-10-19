# frozen_string_literal: true

# A single problem of a course, and answering it.
class ProblemsApi < Grape::API
  helpers AuthHelpers, CourseApiHelpers

  rescue_from(CourseCatalog::NotFound) { error!({ error: :not_found }, 404) }
  # A revision started elsewhere between the check and the save.
  rescue_from(CourseProgress::RoundNotCurrent) { error!({ error: :round_not_current }, 409) }

  helpers do
    # The round a request is about: 1 unless it names a revision.
    def round
      params[:round] || 1
    end

    # The learner's current revision, when the request is about it.
    def revision_for_round
      return nil if round == 1

      error!({ error: :round_not_current }, 409) unless progress.answerable_round?(round)
      current_learner.revisions.find_by!(course_id: course.id, number: round)
    end
  end

  namespace 'courses/:course_id/problems/:problem_id' do
    desc 'A problem, without its answer. For a revision (round >= 2), needs the learner.'
    params do
      optional :round, type: Integer, values: 1..
    end
    get do
      problem_json(course.problem(params[:problem_id]), revision_for_round)
    end

    desc 'Answer a problem in round 1 or the current revision. A correct answer is recorded as solved.'
    params do
      requires :choice, type: String
      optional :round, type: Integer, values: 1..
    end
    post :answer do
      problem = course.problem(params[:problem_id])
      revision_for_round
      status 200
      if problem.correct?(params[:choice])
        progress.record!(problem.id, round)
        { correct: true, explanation: problem.explanation, progress: progress.as_json }
      else
        { correct: false }
      end
    end
  end
end
