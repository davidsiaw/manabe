# frozen_string_literal: true

class CourseCatalog
  # A node in the sidebar tree. May hold problems, subsections, or both;
  # its own problems come before those of its subsections.
  Section = Data.define(:title, :problem_ids, :sections) do
    def all_problem_ids
      problem_ids + sections.flat_map(&:all_problem_ids)
    end
  end
end
