# Courses

How to write a course is in [courses/README.md](../courses/README.md), next to the courses. This file is about how they are loaded.

## On disk

```
courses/
  rust-basics/
    course.yml            id, title, description, sections (nested)
    problems/
      integers.yml        id, title, type, body, question, choices, explanation
                          (type code: language, starter_code, expected_output instead of choices)
```

There are three sample courses, `rust-basics` (105 problems, original text following chapters 1 to 6 of The Rust Programming Language, with some examples adapted from it; 52 are programs the learner runs on their own computer), `git-basics` (6 problems) and `ruby-basics` (10 problems, 8 of them code). Text is plain: the frontend joins wrapped lines into paragraphs, keeps list items on their own lines, and shows indented lines as highlighted code, so write it like simple markdown without markup (courses/README.md). A course may say which `language` the code in its text is in; `problem_json` sends it with multiple choice problems.

## Loading: CourseCatalog

`CourseCatalog.new(root = Rails.root.join('courses'))`:

- `#find(id)` loads one course, `#all` loads every directory with a `course.yml`, sorted by id.
- Courses are read from disk on **every call**. They are small, and edits show up without a restart. If that ever becomes slow, cache with the files' modification times as the key.
- `find` raises `CourseCatalog::NotFound` for an unknown id, and also for any id that is not a plain slug (`/\A[a-z0-9][a-z0-9_-]*\z/`), so that a request cannot read outside `courses/`.

The pieces (`app/services/course_catalog/`):

- `Course`: metadata, `sections` (a tree of `Section`), `problems` (id to `Problem`), `problem_order` (problem ids in sidebar order: a section's own problems first, then its subsections'), and `previous_of`/`next_of` along that order.
- `Section`: `title`, `problem_ids`, `sections`.
- `Problem`: `title`, `body`, `type`, `question`, `choices` (`Choice` with `id`, `text`, `correct`), `explanation`, and `correct?(choice_id)`. For `code?` problems, `language`, `run` (`browser` or `local`, and `local?`), `starter_code`, `expected_output` and `output_correct?(output)`.

## Validation

Loading raises `CourseCatalog::InvalidCourse`, naming the file, when:

- a YAML file does not parse or is not a mapping;
- a required field is missing (course `id`, `title`; problem `id`, `title`, `type`, `question`; choice `id`, `text`);
- the course id is not its directory's name, or a problem id is not its file's name;
- the course has no sections;
- a section lists a problem with no file, a problem is listed twice, or a problem file is not listed anywhere;
- a problem's `type` is not `multiple_choice` or `code`;
- a multiple choice problem has fewer than two choices, duplicate choice ids, or not exactly one correct choice;
- a code problem's `run` is not `browser` or `local`; it runs in the browser and its `language` is not in `Problem::LANGUAGES` (those the frontend has a runtime for), or it runs locally and its `language` is not a slug; it has no `expected_output`; or it has choices.

`spec/services/course_catalog_spec.rb` loads every real course, so a broken course fails the test suite.

## Adding a kind of problem

`type` exists so that other kinds can be added without touching existing files; `code` was the first added. A new type needs: validation rules in `Problem` (and the rest of `TYPES`), its own fields in `problem_json` (`app/apis/v1_api/course_api_helpers.rb`), its own way of checking an answer in `ProblemsApi#answer`, and a view in the frontend's `ProblemView`.

## Code problems

The frontend runs the learner's program in the browser (or, with `run: local`, the learner runs it on their own computer and pastes what it printed) and posts the output; `ProblemsApi#answer` compares that with `expected_output` (`Problem#output_correct?`). The expected output is never sent. The backend runs no code, so nothing here can check that `expected_output` is what the reference solution prints; run it through the frontend's runtime when writing a problem (frontend docs/runtimes.md). Adding a language means a runtime in the frontend and an entry in `Problem::LANGUAGES`.

For `run: local`, `output_correct?` first drops everything up to and including the last line that starts with `` Running ` ``, which is what `cargo run` prints just before the program's own output. Learners then can paste the whole terminal (the command, Cargo's `Compiling` and `Finished` lines, warnings) or only the program's lines. Other languages' tools print nothing of the kind, so this does nothing for them; add a rule beside `CARGO_RUNNING` if one does.
