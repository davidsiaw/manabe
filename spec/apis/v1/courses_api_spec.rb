# frozen_string_literal: true

RSpec.describe CoursesApi, type: :request do # also covers ProblemsApi
  let(:learner) { Learner.create! }
  let(:headers) { bearer(LearnerSession.start(learner).last) }
  let(:json) { response.parsed_body }

  before do
    allow(CourseCatalog).to receive(:new).and_return(CourseCatalog.new(Rails.root.join('spec/fixtures/courses')))
  end

  describe 'GET /api/v1/courses' do
    it 'lists courses without progress for an anonymous visitor' do
      get '/api/v1/courses'
      expect(json).to eq [{ 'id' => 'sample', 'title' => 'Sample Course', 'description' => 'For specs.',
                            'problem_count' => 3, 'solved_count' => nil, 'next_problem_id' => nil,
                            'times_completed' => nil, 'revision' => nil }]
    end

    it 'includes how far the learner is' do
      learner.completions.create!(course_id: 'sample', problem_id: 'one')
      get '/api/v1/courses', headers: headers
      expect(json.first).to include('solved_count' => 1, 'next_problem_id' => 'two')
    end
  end

  describe 'GET /api/v1/courses/:id' do
    it 'returns the section tree with problem titles' do
      get '/api/v1/courses/sample'
      expect(json['sections'].first).to eq(
        'title' => 'First',
        'problems' => [{ 'id' => 'one', 'title' => 'Problem one' }],
        'sections' => [{ 'title' => 'Nested', 'problems' => [{ 'id' => 'two', 'title' => 'Problem two' }],
                         'sections' => [] }]
      )
    end

    it 'returns 404 for an unknown course' do
      get '/api/v1/courses/nope'
      expect(response).to have_http_status :not_found
    end
  end

  describe 'GET /api/v1/courses/:id/problems/:pid' do
    before { get '/api/v1/courses/sample/problems/two' }

    it 'does not reveal which choice is correct' do
      expect(json['choices']).to eq [{ 'id' => 'a', 'text' => 'Not this' }, { 'id' => 'b', 'text' => 'This one' }]
    end

    it 'links to the neighbouring problems across sections' do
      expect([json['previous'], json['next']]).to eq [{ 'id' => 'one', 'title' => 'Problem one' },
                                                      { 'id' => 'three', 'title' => 'Problem three' }]
    end

    it 'returns 404 for an unknown problem' do
      get '/api/v1/courses/sample/problems/nope'
      expect(response).to have_http_status :not_found
    end
  end

  describe 'POST /api/v1/courses/:id/problems/:pid/answer' do
    def answer(choice, with_headers: headers)
      post '/api/v1/courses/sample/problems/two/answer', params: { choice: }, headers: with_headers
    end

    it 'records a correct answer and returns the explanation and the new progress' do
      answer('b')
      expect(json).to include('correct' => true, 'explanation' => 'Because b.',
                              'progress' => include('solved' => ['two'], 'times_solved' => { 'two' => 1 }))
      expect(learner.completions.pluck(:course_id, :problem_id, :round)).to eq [['sample', 'two', 1]]
    end

    it 'records nothing for a wrong answer' do
      answer('a')
      expect(json).to eq('correct' => false)
      expect(learner.completions).to be_empty
    end

    it 'records a problem only once when answered correctly twice' do
      2.times { answer('b') }
      expect(learner.completions.count).to eq 1
    end

    it 'rejects a request without a session' do
      answer('b', with_headers: {})
      expect(response).to have_http_status :unauthorized
    end

    it 'rejects an unknown token' do
      answer('b', with_headers: bearer('x' * 43))
      expect(response).to have_http_status :unauthorized
    end

    it 'rejects a token after logout' do
      session, token = LearnerSession.start(learner)
      session.destroy!
      answer('b', with_headers: bearer(token))
      expect(response).to have_http_status :unauthorized
    end
  end

  describe 'GET /api/v1/courses/:id/progress' do
    it 'shows this learner\'s progress only' do
      learner.completions.create!(course_id: 'sample', problem_id: 'three')
      Learner.create!.completions.create!(course_id: 'sample', problem_id: 'one')
      get '/api/v1/courses/sample/progress', headers: headers
      expect(json).to eq('solved' => ['three'], 'revision' => nil, 'times_solved' => { 'three' => 1 },
                         'times_completed' => 0)
    end
  end

  describe 'revisions' do
    def answer(choice, round:, problem: 'two')
      post "/api/v1/courses/sample/problems/#{problem}/answer", params: { choice:, round: }, headers:
    end

    before do
      learner.completions.create!(course_id: 'sample', problem_id: 'two')
      post '/api/v1/courses/sample/revisions', headers:
    end

    it 'starts one from nothing, keeping round 1' do
      expect(response).to have_http_status :created
      expect(json).to include('solved' => ['two'], 'revision' => { 'number' => 2, 'solved' => [] })
    end

    it 'records answers in the revision' do
      answer('b', round: 2)
      expect(json['progress']).to include('revision' => { 'number' => 2, 'solved' => ['two'] },
                                          'times_solved' => { 'two' => 2 })
    end

    it 'still takes answers in round 1' do
      answer('b', round: 1, problem: 'one')
      expect(json['progress']['solved']).to eq %w[one two]
    end

    it 'refuses answers in a revision that is not the current one' do
      post '/api/v1/courses/sample/revisions', headers: headers
      answer('b', round: 2)
      expect([response.status, json]).to eq [409, { 'error' => 'round_not_current' }]
    end

    it 'refuses round 0' do
      answer('b', round: 0)
      expect(response).to have_http_status :bad_request
    end

    it 'shuffles the choices of a problem, the same way every time' do
      many = (1..8).map { |i| CourseCatalog::Problem::Choice.new(id: i.to_s, text: "c#{i}", correct: i == 1) }
      allow(CourseCatalog::Problem).to receive(:new).and_wrap_original do |original, *args, **kwargs|
        original.call(*args, **kwargs).tap { |p| p.instance_variable_set(:@choices, many) }
      end
      # Not `json`, which is memoized: this example makes several requests.
      ids = lambda do |params, with_headers|
        get('/api/v1/courses/sample/problems/two', params:, headers: with_headers)
        response.parsed_body['choices'].pluck('id')
      end
      revision_orders = Array.new(2) { ids.call({ round: 2 }, headers) }
      in_order = (1..8).map(&:to_s)
      expect([revision_orders.uniq.size, revision_orders.first == in_order, ids.call({}, {})])
        .to eq [1, false, in_order]
    end

    it 'shows revision problems only to their learner' do
      get '/api/v1/courses/sample/problems/two', params: { round: 2 }
      expect(response).to have_http_status :unauthorized
    end
  end
end
