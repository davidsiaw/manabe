# frozen_string_literal: true

# Loads courses from YAML on disk. Each course is a directory under
# courses/ (see courses/README.md for the format).
#
# Courses are read from disk on every lookup. They are small, and this means
# an edit to a course shows up without restarting the server.
class CourseCatalog
  class NotFound < StandardError; end
  class InvalidCourse < StandardError; end

  ID_FORMAT = /\A[a-z0-9][a-z0-9_-]*\z/

  def initialize(root = Rails.root.join('courses'))
    @root = Pathname(root)
  end

  # Raises NotFound for unknown ids, and for ids that are not a plain slug so
  # that a request cannot walk outside the courses directory.
  def find(id)
    raise NotFound, id unless id.is_a?(String) && ID_FORMAT.match?(id)

    dir = @root.join(id)
    raise NotFound, id unless dir.join('course.yml').file?

    Course.load(dir)
  end

  def all
    @root.children.select { |dir| dir.join('course.yml').file? }.sort.map { |dir| Course.load(dir) }
  end

  def self.read_yaml(path)
    data = YAML.safe_load_file(path)
    raise InvalidCourse, "#{path}: must be a YAML mapping" unless data.is_a?(Hash)

    data
  rescue Psych::SyntaxError => e
    raise InvalidCourse, "#{path}: #{e.message}"
  end
end
