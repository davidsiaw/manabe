# frozen_string_literal: true

RSpec.describe LearnersApi, type: :request do
  it 'creates an anonymous learner and returns a token for it' do
    expect { post '/api/v1/learners' }.to change(Learner, :count).by(1)
    expect(LearnerSession.from_token(response.parsed_body['token']).learner).to eq Learner.last
  end
end
