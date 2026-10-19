# frozen_string_literal: true

class CourseCatalog
  # A course: metadata, a tree of sections, and the problems they list.
  class Course
    attr_reader :id, :title, :description, :sections, :problems

    def self.load(dir)
      data = CourseCatalog.read_yaml(dir.join('course.yml'))
      problems = dir.glob('problems/*.yml').to_h do |path|
        problem = Problem.new(CourseCatalog.read_yaml(path), source: path)
        [problem.id, problem]
      end
      new(data, problems, source: dir)
    end

    def initialize(data, problems, source:)
      @source = source
      @id = require_string(data, 'id')
      @title = require_string(data, 'title')
      @description = data['description'].to_s
      @problems = problems
      @sections = Array(data['sections']).map { |s| build_section(s) }
      validate!
    end

    def problem(problem_id)
      @problems.fetch(problem_id) { raise NotFound, problem_id }
    end

    # Problem ids in the order a student meets them walking the tree.
    def problem_order
      @problem_order ||= @sections.flat_map(&:all_problem_ids)
    end

    def previous_of(problem_id)
      index = problem_order.index(problem_id)
      problem_order[index - 1] if index&.positive?
    end

    def next_of(problem_id)
      index = problem_order.index(problem_id)
      problem_order[index + 1] if index
    end

    private

    def build_section(data)
      fail_with("section must be a mapping, got #{data.inspect}") unless data.is_a?(Hash)

      Section.new(
        title: require_string(data, 'title'),
        problem_ids: Array(data['problems']).map(&:to_s),
        sections: Array(data['sections']).map { |s| build_section(s) }
      )
    end

    def validate!
      fail_with('id must match the directory name') unless @id == @source.basename.to_s
      fail_with('has no sections') if @sections.empty?
      validate_problem_references!
    end

    def validate_problem_references!
      missing = problem_order - @problems.keys
      fail_with("lists problems with no file: #{missing.join(', ')}") if missing.any?

      duplicates = problem_order.tally.select { |_, n| n > 1 }.keys
      fail_with("lists problems more than once: #{duplicates.join(', ')}") if duplicates.any?

      unlisted = @problems.keys - problem_order
      fail_with("has problem files not listed in any section: #{unlisted.join(', ')}") if unlisted.any?
    end

    def require_string(data, key)
      value = data[key]
      fail_with("#{key} is required") if value.blank?
      value.to_s
    end

    def fail_with(message)
      raise InvalidCourse, "#{@source}: #{message}"
    end
  end
end
