# frozen_string_literal: true

# Shared by the course and problem APIs.
module CourseApiHelpers
  extend Grape::API::Helpers

  def catalog
    @catalog ||= CourseCatalog.new
  end

  def course
    @course ||= catalog.find(params[:course_id])
  end

  def progress
    @progress ||= CourseProgress.new(current_learner, course)
  end

  # Without progress (no learner), the progress fields are nil.
  def course_summary_json(a_course, a_progress)
    summary = a_progress&.summary || { solved_count: nil, next_problem_id: nil, times_completed: nil, revision: nil }
    { id: a_course.id, title: a_course.title, description: a_course.description,
      problem_count: a_course.problem_order.size }.merge(summary)
  end

  def problem_link(id)
    id && { id:, title: course.problem(id).title }
  end

  def section_json(section)
    {
      title: section.title,
      problems: section.problem_ids.map { |id| problem_link(id) },
      sections: section.sections.map { |s| section_json(s) }
    }
  end

  # Never includes which choice is correct, nor a code problem's expected
  # output. In a revision the choices are shuffled, so that the answer is not
  # remembered by its position; the order is fixed per revision and problem,
  # so it does not change on a reload.
  def problem_json(problem, revision = nil)
    {
      id: problem.id, title: problem.title, body: problem.body, type: problem.type,
      question: problem.question,
      **exercise_json(problem, revision),
      previous: problem_link(course.previous_of(problem.id)),
      next: problem_link(course.next_of(problem.id))
    }
  end

  def exercise_json(problem, revision)
    if problem.code?
      { language: problem.language, run: problem.run, starter_code: problem.starter_code }
    else
      { language: course.language, choices: choices_for(problem, revision).map { |c| { id: c.id, text: c.text } } }
    end
  end

  def choices_for(problem, revision)
    return problem.choices unless revision

    seed = Digest::SHA256.hexdigest("#{revision.id}/#{problem.id}").to_i(16)
    problem.choices.shuffle(random: Random.new(seed))
  end
end
