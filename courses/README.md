# Courses

Each directory here is one course. The directory name is the course id that
appears in URLs, so use lowercase letters, digits, `-` and `_`.

```
courses/
  rust-basics/
    course.yml          metadata and the sidebar tree
    problems/
      integers.yml      one file per problem; file name == problem id
```

## course.yml

```yaml
id: rust-basics               # must equal the directory name
title: Rust Basics
description: Plain text shown on the course landing page.
sections:
  - title: Welcome
    problems: [welcome, syntax]
  - title: A Basic Calculator
    problems: [calculator-intro]   # a section may list problems...
    sections:                      # ...and/or nest further sections
      - title: Numbers
        problems: [integers, overflow]
```

Problems appear in the sidebar, and Previous/Next walk through them, in the
order they are listed. A section's own problems come before those of its
subsections.

## problems/<id>.yml

```yaml
id: integers                  # must equal the file name
title: Integers
type: multiple_choice         # the only type for now
body: |
  Plain text explanation. Blank lines separate paragraphs.
question: What is the largest value a u8 can hold?
choices:
  - id: a
    text: "127"
  - id: b
    text: "255"
    correct: true             # exactly one choice is correct
explanation: |                # optional; shown once answered correctly
  u8 is unsigned and 8 bits wide: 2^8 - 1 = 255.
```

Quote choice text that YAML might read as something else (`"255"`, `"true"`,
anything starting with `{` or `*`).

## Checking a course

The course loader rejects a course that lists a problem with no file, lists a
problem twice, has a problem file that no section lists, or has a problem
without exactly one correct choice. `spec/services/course_catalog_spec.rb`
loads every course in this directory, so the test suite fails on a broken
course.

Courses are read from disk on every request, so edits show up without a
restart.
