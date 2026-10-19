# frozen_string_literal: true

class CourseCatalog
  # One exercise. `type` says what kind:
  #
  # - multiple_choice: pick one of `choices`; exactly one is correct.
  # - code: write a program in `language`, and send back what it printed,
  #   which must match `expected_output` (see #output_correct?). With `run:
  #   browser` (the default) the frontend runs it; with `run: local` the
  #   learner runs it on their own computer and pastes the output.
  class Problem
    TYPES = %w[multiple_choice code].freeze
    RUNS = %w[browser local].freeze
    # Languages the frontend has a runtime for (its Resources/runtimes/).
    LANGUAGES = %w[ruby zig].freeze
    LANGUAGE_FORMAT = /\A[a-z0-9][a-z0-9_-]*\z/
    # The line `cargo run` prints just before the program's own output.
    CARGO_RUNNING = /\A\s*Running `/

    Choice = Data.define(:id, :text, :correct)

    attr_reader :id, :title, :body, :type, :question, :choices, :explanation,
                :language, :run, :starter_code, :expected_output

    def initialize(data, source:)
      @source = source
      @id = require_string(data, 'id')
      @title = require_string(data, 'title')
      @body = data['body'].to_s
      @type = require_string(data, 'type')
      @question = require_string(data, 'question')
      @explanation = data['explanation'].to_s
      @choices = Array(data['choices']).map { |c| build_choice(c) }
      read_code_fields(data)
      validate!
    end

    def code?
      @type == 'code'
    end

    def correct?(choice_id)
      @choices.any? { |c| c.correct && c.id == choice_id.to_s }
    end

    # Compares printed output, ignoring trailing whitespace on each line,
    # trailing blank lines and CRLF line endings, which a learner cannot see.
    # Output pasted from a terminal may start with what Cargo printed while
    # building; everything up to its Running line is left out.
    def output_correct?(output)
      return false unless code?

      output = program_output(output.to_s) if local?
      normalize_output(output) == normalize_output(@expected_output)
    end

    def local?
      @run == 'local'
    end

    private

    def read_code_fields(data)
      @language = data['language']&.to_s
      @run = (data['run'] || 'browser').to_s
      @starter_code = data['starter_code'].to_s
      @expected_output = data['expected_output']&.to_s
    end

    def program_output(pasted)
      lines = pasted.gsub("\r\n", "\n").split("\n")
      running = lines.rindex { |line| line.match?(CARGO_RUNNING) }
      running ? lines.drop(running + 1).join("\n") : pasted
    end

    def normalize_output(text)
      text.to_s.gsub("\r\n", "\n").split("\n").map(&:rstrip).join("\n").sub(/\n+\z/, '')
    end

    def build_choice(data)
      fail_with("choice must be a mapping, got #{data.inspect}") unless data.is_a?(Hash)

      Choice.new(id: require_string(data, 'id'), text: require_string(data, 'text'), correct: data['correct'] == true)
    end

    def validate!
      fail_with('id must match the file name') unless @id == @source.basename('.yml').to_s
      fail_with("type must be one of #{TYPES.join(', ')}") unless TYPES.include?(@type)
      code? ? validate_code! : validate_choices!
    end

    def validate_choices!
      fail_with('needs at least two choices') if @choices.size < 2
      fail_with('choice ids must be unique') unless @choices.map(&:id).uniq.size == @choices.size
      fail_with('needs exactly one correct choice') unless @choices.one?(&:correct)
    end

    def validate_code!
      fail_with("run must be one of #{RUNS.join(', ')}") unless RUNS.include?(@run)
      validate_language!
      fail_with('expected_output is required') if @expected_output.blank?
      fail_with('a code problem has no choices') if @choices.any?
    end

    # The browser can only run languages it has a runtime for; on the
    # learner's computer, any language will do.
    def validate_language!
      if local?
        fail_with('language must be a slug') unless LANGUAGE_FORMAT.match?(@language.to_s)
      elsif LANGUAGES.exclude?(@language)
        fail_with("language must be one of #{LANGUAGES.join(', ')}, or the problem run: local")
      end
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
