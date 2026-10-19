# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CourseCatalog do
  subject(:catalog) { described_class.new(root) }

  let(:root) { Pathname(Dir.mktmpdir) }
  let(:course_yml) do
    nested = { 'title' => 'B', 'problems' => %w[p2] }
    { 'id' => 'demo', 'title' => 'Demo',
      'sections' => [{ 'title' => 'A', 'problems' => %w[p1], 'sections' => [nested] }] }
  end
  let(:problems) { { 'p1' => problem_yml('p1'), 'p2' => problem_yml('p2') } }

  def problem_yml(id, **overrides)
    { 'id' => id, 'title' => id.upcase, 'type' => 'multiple_choice', 'question' => 'Q?',
      'choices' => [{ 'id' => 'a', 'text' => 'A' }, { 'id' => 'b', 'text' => 'B', 'correct' => true }] }
      .merge(overrides.transform_keys(&:to_s))
  end

  def write_course
    dir = root.join('demo')
    dir.join('problems').mkpath
    dir.join('course.yml').write(course_yml.to_yaml)
    problems.each { |id, data| dir.join("problems/#{id}.yml").write(data.to_yaml) }
  end

  before { write_course }
  after { FileUtils.rm_rf(root) }

  it 'orders problems depth first through nested sections' do
    expect(catalog.find('demo').problem_order).to eq %w[p1 p2]
  end

  it 'knows the neighbours of a problem' do
    course = catalog.find('demo')
    expect([course.previous_of('p1'), course.next_of('p1'), course.next_of('p2')]).to eq [nil, 'p2', nil]
  end

  it 'checks answers by choice id' do
    problem = catalog.find('demo').problem('p1')
    expect([problem.correct?('b'), problem.correct?('a'), problem.correct?('zzz')]).to eq [true, false, false]
  end

  it 'lists courses' do
    expect(catalog.all.map(&:id)).to eq %w[demo]
  end

  it 'raises NotFound for an unknown course' do
    expect { catalog.find('nope') }.to raise_error CourseCatalog::NotFound
  end

  it 'raises NotFound for an unknown problem' do
    expect { catalog.find('demo').problem('nope') }.to raise_error CourseCatalog::NotFound
  end

  it 'refuses ids that are not slugs, so paths cannot escape the root' do
    expect { catalog.find('../demo') }.to raise_error CourseCatalog::NotFound
  end

  context 'with a section listing a problem that has no file' do
    let(:problems) { { 'p1' => problem_yml('p1') } }

    it { expect { catalog.find('demo') }.to raise_error CourseCatalog::InvalidCourse, /no file: p2/ }
  end

  context 'with a problem file no section lists' do
    let(:problems) { super().merge('p3' => problem_yml('p3')) }

    it { expect { catalog.find('demo') }.to raise_error CourseCatalog::InvalidCourse, /not listed.*p3/ }
  end

  context 'with a language that is not a slug' do
    let(:course_yml) { super().merge('language' => '../ruby') }

    it { expect { catalog.find('demo') }.to raise_error CourseCatalog::InvalidCourse, /language must be a slug/ }
  end

  context 'with a problem listed twice' do
    let(:course_yml) { super().merge('sections' => [{ 'title' => 'A', 'problems' => %w[p1 p2 p1] }]) }

    it { expect { catalog.find('demo') }.to raise_error CourseCatalog::InvalidCourse, /more than once: p1/ }
  end

  context 'with two correct choices' do
    let(:problems) do
      super().merge('p2' => problem_yml('p2', choices: [{ 'id' => 'a', 'text' => 'A', 'correct' => true },
                                                        { 'id' => 'b', 'text' => 'B', 'correct' => true }]))
    end

    it { expect { catalog.find('demo') }.to raise_error CourseCatalog::InvalidCourse, /exactly one correct/ }
  end

  context 'with a problem whose id differs from its file name' do
    let(:problems) { super().merge('p2' => problem_yml('other')) }

    it { expect { catalog.find('demo') }.to raise_error CourseCatalog::InvalidCourse, /match the file name/ }
  end

  context 'with an unknown problem type' do
    let(:problems) { super().merge('p2' => problem_yml('p2', type: 'essay')) }

    it { expect { catalog.find('demo') }.to raise_error CourseCatalog::InvalidCourse, /type must be/ }
  end

  describe 'a code problem' do
    let(:code) do
      { 'type' => 'code', 'language' => 'ruby', 'expected_output' => "1\n2\n", 'choices' => nil }
    end
    let(:problems) { super().merge('p2' => problem_yml('p2', **code)) }

    it 'compares output ignoring trailing whitespace and blank lines' do
      problem = catalog.find('demo').problem('p2')
      expect([problem.output_correct?("1 \r\n2"), problem.output_correct?("1\n2\n3\n"), problem.output_correct?(nil)])
        .to eq [true, false, false]
    end

    context 'with a language there is no runtime for' do
      let(:code) { super().merge('language' => 'cobol') }

      it { expect { catalog.find('demo') }.to raise_error CourseCatalog::InvalidCourse, /language must be/ }
    end

    context 'without expected output' do
      let(:code) { super().merge('expected_output' => nil) }

      it { expect { catalog.find('demo') }.to raise_error CourseCatalog::InvalidCourse, /expected_output/ }
    end

    context 'when run on the learner\'s computer' do
      let(:code) { super().merge('language' => 'rust', 'run' => 'local') }

      it 'takes any language, as there is no browser runtime to need' do
        expect(catalog.find('demo').problem('p2')).to have_attributes(language: 'rust', run: 'local')
      end

      it 'leaves out what cargo printed before running the program' do
        pasted = ['$ cargo run', '   Compiling hello v0.1.0 (/tmp/hello)', '    Finished `dev` profile in 0.09s',
                  '     Running `target/debug/hello`', '1', '2'].join("\n")
        problem = catalog.find('demo').problem('p2')
        answers = [pasted, "1\n2", "Running\n1\n2"]
        expect(answers.map { |a| problem.output_correct?(a) }).to eq [true, true, false]
      end

      it 'leaves out the line cargo adds when the program exits with an error' do
        pasted = ['     Running `target/debug/hello`', '1', '2',
                  "error: process didn't exit successfully: `target/debug/hello` (exit status: 1)"].join("\n")
        expect(catalog.find('demo').problem('p2').output_correct?(pasted)).to be true
      end
    end

    context 'when it asks for what cargo test printed' do
      let(:summary) { 'test result: ok. 1 passed; 0 failed; 0 ignored; 0 measured; 0 filtered out' }
      let(:code) do
        empty = summary.sub('1 passed', '0 passed')
        expected = "running 1 test\ntest tests::it_works ... ok\n\n#{summary}\n\nrunning 0 tests\n\n#{empty}\n"
        super().merge('language' => 'rust', 'run' => 'local', 'expected_output' => expected)
      end

      it 'leaves out cargo\'s status lines and how long the tests took' do
        pasted = ['   Compiling adder v0.1.0 (/tmp/adder)', 'warning: unused variable: `x`', ' --> src/lib.rs:2:9', '',
                  '    Finished `test` profile in 0.31s',
                  '     Running unittests src/lib.rs (target/debug/deps/adder-1f9b6d5c)', '', 'running 1 test',
                  'test tests::it_works ... ok', '', "#{summary}; finished in 0.00s", '',
                  '   Doc-tests adder', '', 'running 0 tests', '',
                  "#{summary.sub('1 passed', '0 passed')}; finished in 0.00s",
                  'all doctests ran in 0.13s; merged doctests compilation took 0.12s', ''].join("\n")
        problem = catalog.find('demo').problem('p2')
        failed = pasted.sub('it_works ... ok', 'it_works ... FAILED')
        answers = [pasted, failed, problem.expected_output]
        expect(answers.map { |a| problem.output_correct?(a) }).to eq [true, false, true]
      end
    end

    context 'with a run that is neither browser nor local' do
      let(:code) { super().merge('run' => 'server') }

      it { expect { catalog.find('demo') }.to raise_error CourseCatalog::InvalidCourse, /run must be/ }
    end

    it 'runs in the browser unless it says otherwise, which only some languages can' do
      expect(catalog.find('demo').problem('p2').run).to eq 'browser'
    end
  end

  # Fails the build when a real course has a mistake in it.
  describe 'the courses in courses/' do
    Rails.root.join('courses').children.select(&:directory?).each do |dir|
      it "loads #{dir.basename}" do
        expect { described_class.new.find(dir.basename.to_s) }.not_to raise_error
      end
    end
  end
end
