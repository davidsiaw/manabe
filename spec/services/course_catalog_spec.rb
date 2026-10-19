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

  # Fails the build when a real course has a mistake in it.
  describe 'the courses in courses/' do
    Rails.root.join('courses').children.select(&:directory?).each do |dir|
      it "loads #{dir.basename}" do
        expect { described_class.new.find(dir.basename.to_s) }.not_to raise_error
      end
    end
  end
end
