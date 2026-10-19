# frozen_string_literal: true

RSpec.describe AccountApi, type: :request do
  let(:client) { fake_passkey_client }
  let(:learner) { Learner.create! }
  let(:token) { LearnerSession.start(learner).last }

  # Not memoized: these examples make several requests.
  def json = response.parsed_body

  before do
    allow(CourseCatalog).to receive(:new).and_return(CourseCatalog.new(Rails.root.join('spec/fixtures/courses')))
  end

  def register(email = 'student@example.com')
    post '/api/v1/registration/options', params: { email: }, headers: bearer(token), as: :json
    credential = client.create(challenge: response.parsed_body['challenge'], user_verified: true)
    post '/api/v1/registration', params: { credential: }, headers: bearer(token), as: :json
  end

  def log_in
    post '/api/v1/login/options', as: :json
    credential = client.get(challenge: response.parsed_body['challenge'], user_verified: true,
                            user_handle: raw_user_handle(learner.reload))
    post '/api/v1/login', params: { credential: }, as: :json
  end

  describe 'registration' do
    it 'registers the current learner' do
      register
      expected = [200, { 'email' => 'student@example.com' }, 'student@example.com']
      expect([response.status, json, learner.reload.email]).to eq expected
    end

    it 'needs a session' do
      post '/api/v1/registration/options', params: { email: 'a@example.com' }, as: :json
      expect(response).to have_http_status :unauthorized
    end

    it 'answers 409 for a taken email' do
      Learner.create!(email: 'student@example.com')
      post '/api/v1/registration/options', params: { email: 'student@example.com' }, headers: bearer(token), as: :json
      expect([response.status, json]).to eq [409, { 'error' => 'email_taken' }]
    end

    it 'answers 422 for a bad credential' do
      post '/api/v1/registration', params: { credential: { id: 'x' } }, headers: bearer(token), as: :json
      expect([response.status, json]).to eq [422, { 'error' => 'invalid_credential' }]
    end
  end

  describe 'login' do
    before { register }

    it 'starts a new session for the passkey\'s learner' do
      log_in
      expect(json['email']).to eq 'student@example.com'
      expect(LearnerSession.from_token(json['token']).learner).to eq learner
    end

    it 'answers 422 when the passkey is unknown' do
      post '/api/v1/login/options', as: :json
      stranger = fake_passkey_client
      stranger.create
      post '/api/v1/login', params: { credential: stranger.get(challenge: response.parsed_body['challenge']) },
                            as: :json
      expect([response.status, json]).to eq [422, { 'error' => 'unknown_passkey' }]
    end
  end

  describe 'DELETE /api/v1/session' do
    it 'ends only the current session' do
      other_token = LearnerSession.start(learner).last
      delete '/api/v1/session', headers: bearer(token)
      expect(response).to have_http_status :no_content
      expect([LearnerSession.from_token(token), LearnerSession.from_token(other_token)&.learner]).to eq [nil, learner]
    end
  end

  describe 'GET /api/v1/me' do
    it 'shows the email and the courses started, with progress' do
      learner.update!(email: 'student@example.com')
      learner.completions.create!(course_id: 'sample', problem_id: 'one')
      learner.completions.create!(course_id: 'gone', problem_id: 'x')
      get '/api/v1/me', headers: bearer(token)
      expect(json).to eq('email' => 'student@example.com',
                         'courses' => [{ 'id' => 'sample', 'title' => 'Sample Course', 'description' => 'For specs.',
                                         'problem_count' => 3, 'solved_count' => 1, 'next_problem_id' => 'two',
                                         'times_completed' => 0, 'revision' => nil }])
    end

    it 'has no email for an anonymous learner' do
      get '/api/v1/me', headers: bearer(token)
      expect(json).to eq('email' => nil, 'courses' => [])
    end
  end
end
