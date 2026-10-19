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
language: rust                # optional; what the code in the text is in, for highlighting
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

## Writing text

Bodies, questions and explanations are plain text. Lines are joined into
paragraphs wherever you wrap them, and a blank line starts a new paragraph.

- A list item starts with `- ` (or `* ` or `1. `). Wrap it by indenting the
  next lines to where the item's text starts.
- Indent anything else and it is code: shown in its own highlighted block,
  in the course's `language` (a code problem's own `language`). Indent
  deeper than a list item's text for code inside a list.

```yaml
body: |
  A variable is a name for a value:

    let x = 5;

  - Variables are immutable unless declared with
    mut, as in this sentence's second line.
```

## problems/<id>.yml

```yaml
id: integers                  # must equal the file name
title: Integers
type: multiple_choice         # or code, below
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
anything starting with `{`, `*` or `:`). Courses are loaded with
`YAML.safe_load`, so an unquoted `:hi` is a Symbol and fails to load.

## Code problems

A code problem asks for a program. The learner writes it in an editor in the
browser, where it runs; the answer is right when it prints `expected_output`.

```yaml
id: hello-world
title: Hello, World
type: code
language: ruby                # the only one the browser can run for now
body: |
  Plain text explanation, as above.
question: Print Hello, world!
starter_code: |               # optional; what the editor starts with
  # Write your program here.
expected_output: |            # required; never sent to the browser
  Hello, world!
explanation: |                # optional; shown once answered correctly
  puts "Hello, world!" is the whole program.
```

Output is compared ignoring trailing spaces on each line and blank lines at
the end. Ruby runs on mruby 3.4, not CRuby, so `expected_output` must be what
mruby prints: avoid printing inexact Floats (mruby prints fewer digits), and
`it` in blocks does not exist (use `_1` or a named parameter). The frontend's
docs/runtimes.md lists the differences and how to run a solution on the real
runtime.

A learner can always pass by printing the expected text directly. Ask for
output that takes a loop or a method to produce, so that writing the program
is the easier way.

### Code run on the learner's computer

For a language the browser cannot run (Rust, for now), add `run: local`. The
learner copies the code, runs it on their own computer and pastes what it
printed; the rest works as above. Any language name will do, as there is no
runtime to need, and `rust` gets syntax highlighting.

```yaml
id: fix-mutability
title: Fixing Mutability
type: code
language: rust
run: local
body: |
  Copy the program below into src/main.rs in your hello project, replacing
  everything in it, and run cargo run. Read the error.
question: |
  Fix the program so that it compiles and counts to three, then run it and
  paste what it printed.
starter_code: |               # the code to copy
  fn main() {
      let count = 0;
      ...
expected_output: |
  count is 3
```

Learners can paste everything `cargo run` showed: what Cargo prints up to its
`Running` line is left out before comparing. The course has to teach the
setup first; `rust-basics/install-rust` does, and checks it by asking for the
output of the project `cargo new` makes. Write `expected_output` by running
the solution with a real toolchain, and check that the starter code does not
already print it. For a program that reads input, tell the learner exactly
what to type: the terminal shows the typed text, so `expected_output`
includes it, as in `rust-basics/guess-loop`. Compiler errors make good problems: give code that does not
compile and ask for it fixed.

## Checking a course

The course loader rejects a course that lists a problem with no file, lists a
problem twice, has a problem file that no section lists, has a multiple choice
problem without exactly one correct choice, or has a code problem without
`expected_output` or with a language there is no runtime for. `spec/services/course_catalog_spec.rb`
loads every course in this directory, so the test suite fails on a broken
course.

Courses are read from disk on every request, so edits show up without a
restart.
