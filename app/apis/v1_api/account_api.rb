# frozen_string_literal: true

# Registering with an email and a passkey, logging in and out, and the
# learner's own page.
class AccountApi < Grape::API
  helpers AuthHelpers, CourseApiHelpers

  helpers do
    def ceremony
      @ceremony ||= PasskeyCeremony.new
    end
  end

  rescue_from(PasskeyCeremony::Failed) do |e|
    status = { email_taken: 409, already_registered: 409 }.fetch(e.code, 422)
    error!({ error: e.code }, status)
  end

  desc 'The current learner and their progress in the courses they have started'
  get :me do
    learner = current_learner
    started = catalog.all.map { |c| [c, CourseProgress.new(learner, c)] }.select { |_, p| p.started? }
    {
      email: learner.email,
      courses: started.map { |c, p| course_summary_json(c, p) }
    }
  end

  namespace :registration do
    desc 'Options for creating a passkey for this email'
    params { requires :email, type: String }
    post :options do
      status 200
      ceremony.registration_options(current_learner, params[:email])
    end

    desc 'Verify the new passkey; the current learner becomes a registered one'
    params { requires :credential, type: Hash }
    post do
      learner = ceremony.register!(current_learner, params[:credential].to_h)
      status 200
      { email: learner.email }
    end
  end

  namespace :login do
    desc 'Options for logging in with any passkey for this site'
    post :options do
      status 200
      ceremony.login_options
    end

    desc 'Verify a passkey and start a session for its learner'
    params { requires :credential, type: Hash }
    post do
      learner = ceremony.login!(params[:credential].to_h)
      _session, token = LearnerSession.start(learner)
      status 200
      { token:, email: learner.email }
    end
  end

  desc 'Log out: end the current session'
  delete :session do
    current_learner
    current_session.destroy!
    status 204
    body false
  end
end
