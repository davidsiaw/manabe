# Courses

How to write a course is in [courses/README.md](../courses/README.md), next to the courses. This file is about how they are loaded.

## On disk

```
courses/
  rust-basics/
    course.yml            id, title, description, sections (nested)
    problems/
      integers.yml        id, title, type, body, question, choices, explanation
```

There are two sample courses, `rust-basics` (12 problems, original text following the structure of rust-exercises.com) and `git-basics` (6 problems). Text is plain: the frontend joins wrapped lines into paragraphs and keeps indented lines (code) and list items as they are, so write it like simple markdown without markup.

## Loading: CourseCatalog

`CourseCatalog.new(root = Rails.root.join('courses'))`:

- `#find(id)` loads one course, `#all` loads every directory with a `course.yml`, sorted by id.
- Courses are read from disk on **every call**. They are small, and edits show up without a restart. If that ever becomes slow, cache with the files' modification times as the key.
- `find` raises `CourseCatalog::NotFound` for an unknown id, and also for any id that is not a plain slug (`/\A[a-z0-9][a-z0-9_-]*\z/`), so that a request cannot read outside `courses/`.

The pieces (`app/services/course_catalog/`):

- `Course`: metadata, `sections` (a tree of `Section`), `problems` (id to `Problem`), `problem_order` (problem ids in sidebar order: a section's own problems first, then its subsections'), and `previous_of`/`next_of` along that order.
- `Section`: `title`, `problem_ids`, `sections`.
- `Problem`: `title`, `body`, `type`, `question`, `choices` (`Choice` with `id`, `text`, `correct`), `explanation`, and `correct?(choice_id)`.

## Validation

Loading raises `CourseCatalog::InvalidCourse`, naming the file, when:

- a YAML file does not parse or is not a mapping;
- a required field is missing (course `id`, `title`; problem `id`, `title`, `type`, `question`; choice `id`, `text`);
- the course id is not its directory's name, or a problem id is not its file's name;
- the course has no sections;
- a section lists a problem with no file, a problem is listed twice, or a problem file is not listed anywhere;
- a problem's `type` is not `multiple_choice`;
- a problem has fewer than two choices, duplicate choice ids, or not exactly one correct choice.

`spec/services/course_catalog_spec.rb` loads every real course, so a broken course fails the test suite.

## Adding a kind of problem

`type` exists so that other kinds (code to evaluate, first of all) can be added without touching existing files. A new type needs: validation rules in `Problem` (and the rest of `TYPES`), its own fields in `problem_json` (`app/apis/v1_api/course_api_helpers.rb`), its own way of checking an answer in `ProblemsApi#answer`, and a view in the frontend's `ProblemView`.
