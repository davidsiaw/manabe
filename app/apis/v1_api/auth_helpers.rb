# frozen_string_literal: true

# Every learner, anonymous or registered, is identified by the bearer token
# of a LearnerSession: `Authorization: Bearer <token>`.
module AuthHelpers
  extend Grape::API::Helpers

  def current_session
    return @current_session if defined?(@current_session)

    token = headers['authorization'].to_s[/\ABearer (\S+)\z/, 1]
    @current_session = LearnerSession.from_token(token)
  end

  def current_learner
    current_session&.learner || error!({ error: :unauthorized }, 401)
  end

  # For endpoints that work anonymously but show more to a learner.
  def optional_learner
    current_session&.learner
  end
end
