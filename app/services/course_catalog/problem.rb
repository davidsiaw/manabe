# frozen_string_literal: true

class CourseCatalog
  # One exercise. Only multiple choice exists for now; `type` is there so that
  # code exercises can be added later without changing existing files.
  class Problem
    TYPES = %w[multiple_choice].freeze

    Choice = Data.define(:id, :text, :correct)

    attr_reader :id, :title, :body, :type, :question, :choices, :explanation

    def initialize(data, source:)
      @source = source
      @id = require_string(data, 'id')
      @title = require_string(data, 'title')
      @body = data['body'].to_s
      @type = require_string(data, 'type')
      @question = require_string(data, 'question')
      @explanation = data['explanation'].to_s
      @choices = Array(data['choices']).map { |c| build_choice(c) }
      validate!
    end

    def correct?(choice_id)
      @choices.any? { |c| c.correct && c.id == choice_id.to_s }
    end

    private

    def build_choice(data)
      fail_with("choice must be a mapping, got #{data.inspect}") unless data.is_a?(Hash)

      Choice.new(id: require_string(data, 'id'), text: require_string(data, 'text'), correct: data['correct'] == true)
    end

    def validate!
      fail_with('id must match the file name') unless @id == @source.basename('.yml').to_s
      fail_with("type must be one of #{TYPES.join(', ')}") unless TYPES.include?(@type)
      validate_choices!
    end

    def validate_choices!
      fail_with('needs at least two choices') if @choices.size < 2
      fail_with('choice ids must be unique') unless @choices.map(&:id).uniq.size == @choices.size
      fail_with('needs exactly one correct choice') unless @choices.one?(&:correct)
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
