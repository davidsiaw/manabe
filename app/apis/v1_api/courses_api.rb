# frozen_string_literal: true

# The course menu, a course's problem tree, and a learner's progress in it.
class CoursesApi < Grape::API
  helpers AuthHelpers, CourseApiHelpers

  rescue_from(CourseCatalog::NotFound) { error!({ error: :not_found }, 404) }

  resource :courses do
    desc 'All courses. With a learner, also how far they are in each.'
    get do
      learner = optional_learner
      catalog.all.map { |c| course_summary_json(c, learner && CourseProgress.new(learner, c)) }
    end

    route_param :course_id, type: String do
      desc 'A course and its problem tree'
      get do
        { id: course.id, title: course.title, description: course.description,
          sections: course.sections.map { |s| section_json(s) } }
      end

      desc 'What the current learner has solved, in round 1 and in their current revision'
      get :progress do
        progress.as_json
      end

      desc 'Start a revision: go through the course again from nothing. ' \
           'Earlier rounds are kept; an unfinished current revision is left behind.'
      post :revisions do
        progress.start_revision!
        status 201
        progress.as_json
      rescue ActiveRecord::RecordNotUnique
        error!({ error: :revision_already_started }, 409)
      end
    end
  end
end
