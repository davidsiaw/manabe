# frozen_string_literal: true

# Anonymous learners. A browser with no session creates one on first visit and
# keeps the token it gets back.
class LearnersApi < Grape::API
  resource :learners do
    desc 'Create an anonymous learner and a session for it'
    post do
      _session, token = LearnerSession.start(Learner.create!)
      status 201
      { token: }
    end
  end
end
