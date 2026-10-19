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

The courses are described below, under "The courses". Text is plain: the frontend joins wrapped lines into paragraphs, keeps list items on their own lines, and shows indented lines as highlighted code, so write it like simple markdown without markup (courses/README.md). A course may say which `language` the code in its text is in; `problem_json` sends it with multiple choice problems.

## The courses

| Course | Language | Problems | What it is |
|---|---|---|---|
| `rust-basics` | rust | 312, 169 of them programs run on the learner's computer | All 21 chapters of The Rust Programming Language |
| `ruby-basics` | ruby | 10, 8 of them programs run in the browser | Ruby from puts to methods, on mruby |
| `zig-basics` | zig | 168, 100 of them programs: 89 compiled and run in the browser, 11 run on the learner's computer | All 17 chapters of Introduction to Zig |
| `git-basics` | shell | 6, all multiple choice | What Git tracks, and the everyday commands |

### rust-basics: where it stands

It follows all of [The Rust Programming Language](https://doc.rust-lang.org/book/), one top-level section per chapter, from Getting Started to the final project, a multithreaded web server, with the book's subsections as subsections. The text is original; some examples are adapted from the book (MIT or Apache-2.0), as the course description says.

How the chapters are written, so that the next ones match:

- **Short texts, then practice.** Each problem explains one idea. New syntax is shown first as a small annotated pattern, in an indented code block, before any prose about it.
- **Three kinds of exercise**, mixed throughout:
  - *Write it*: the starter code calls something that does not exist yet (a struct, a method), or has a `todo!()`; the learner writes it.
  - *Fix it*: the starter does not compile, or panics, and the text quotes the first line of the compiler's message. The lesson is reading the error. Most of chapters 4 to 6 work like this, as the borrow checker and the pattern checker are best learned from their messages.
  - *Predict it*: a multiple choice question on what some code prints, or whether it compiles.
- **Local problems** (`run: local`) all use the learner's `hello` project from `install-rust`, except the guessing game, which has its own `guessing_game` project. The text says "Copy the program into src/main.rs in your hello project".
- **`Noisy`**, a tuple struct whose `Drop` prints "Noisy N is dropped", makes ownership visible in chapter 4 (`drop-order`, `move-into-function`, `borrow-noisy`). Its `impl Drop` comes with a comment to ignore it for now: traits are chapter 10, `Drop` chapter 15.
- **The guessing game** uses a fixed secret number, 42, so that its output can be checked, and tells the learner exactly what to type; the expected output includes the typed lines. The text shows `rand::random_range` for the real thing (rand 0.10).
- **Each chapter ends with a capstone** that puts it together: `fizzbuzz`, `fibonacci` and `temperatures` (chapter 3), `account` (5), `calculator` (6), `restaurant-modules` (7), the book's three exercises (8), `score-sheet` (9), and so on to `multithreaded-server` (21).
- **Other projects** for the later chapters, each made with `cargo new` as the text says: `adder` (a library, chapter 11's tests), `minigrep` (chapters 12 and 13, with the book's `poem.txt`), `my_crate` (doc-tests, 14) and `hello_server` (21). Chapter 17 adds the book's `trpl` crate to the hello project.
- **Tests are pasted whole.** Problems that run `cargo test` ask for `cargo test -- --test-threads=1`, so that tests are listed in the same order, and the backend leaves out Cargo's own lines and timings (courses/README.md). Programs whose output depends on timing (threads, async) only print what is the same every run: results after joining, sorted messages, sleeps of distinct lengths.
- **Servers handle two connections and stop** (`.take(2)`), so that what they print can be pasted; the text says exactly which requests to make, with curl or a browser.
- **Problem ids are never renamed or removed**, as completions refer to them; reordering sections is fine. Adding problems makes earlier completions incomplete (progress.md), which is expected.

Every program was checked with rustc 1.99.1 (courses/README.md, "Checking code problems"). Nothing re-checks them automatically yet (roadmap.md).

### zig-basics: where it stands

It follows all 17 chapters of [Introduction to Zig: a project-based book](https://pedropark99.github.io/zig-book/) by Pedro Duarte Faria, which is CC BY 4.0: the course description names the book, its author, its licence, and says the text is rewritten and the examples changed, as the licence requires. Keep that if the course grows. The book is built with Zig 0.17.0, the version the frontend's runtime compiles with, and its examples were checked against it.

The programs are compiled in the browser by the real Zig compiler (frontend docs/runtimes.md), and the learner sees all its output, as on HDLBits. So most code problems are *fix it* problems built on Zig's strictness, with the compiler's own message quoted in the text: a `var` that is never changed, an unused value, `comptime_int` needing a type, `==` on strings, a `switch` missing a case, a method that needs `self: *T`. Chapter 3 adds the runtime's reports: the `DebugAllocator`'s leak report and `error: OutOfMemory`. Multiple choice problems sit beside them for what code cannot show (where memory lives, which allocator to choose, what `errdefer` does).

- Programs print with `std.debug.print`, which needs no setup; the first problems show the book's stdout writer, and `flush` and `debug-print` explain the difference. Both count as output.
- Chapter 3's programs set up a `DebugAllocator` in `main`, so that leaks show.
- Chapter 3 ends with a capstone, `repeat-word`: a function that takes an allocator and returns memory the caller frees. Every chapter after it ends with one too.
- **The browser runs most of it.** Programs get an empty folder of their own in memory as their current directory, so chapter 13's files and directories work in the browser, as do chapter 7's HTTP parsing (on request text) and chapter 15's image filter (on pixels in memory, written out as PGM and ASCII art). stdin is always empty there.
- **What the browser cannot do runs locally** (`run: local`), with Zig 0.17.0 installed by `install-zig`: the HTTP server (sockets), `zig test`, `zig build`, C interop (no C compiler in the browser) and threads (the browser build is single-threaded).
- **Zig 0.17 differs from the book** in places, and the course follows 0.17: `@cImport` is gone (translate-c through the build system, or `extern` declarations), `ArrayList` and the array hash maps take the allocator in each call, locks are `std.Io.Mutex` and `std.Io.RwLock`, and readers use `takeDelimiter`.

Every problem was checked by compiling and running it the way the browser does, or with the native Zig 0.17.0 for local ones (courses/README.md, "Checking code problems"); the first three chapters' solutions were also submitted through the real app, and samples of the later ones.

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
