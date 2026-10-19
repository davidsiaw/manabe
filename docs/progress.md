# Progress, rounds and revisions

## Rounds

A learner's progress through a course is kept per **round**. Round 1 is the first time through. A **revision** starts a further round from nothing, for going through the course again; the learner can start as many as they like, at any time, and round 1 is never touched.

- `completions` has a `round` column (default 1). Round 1 has no record of its own, so progress from before revisions existed is round 1.
- A `Revision` row (number 2, 3, ...) records each revision started. The highest number is the **current** revision. Starting another while the current one is unfinished leaves that one behind: it stays in the database and counts towards how often each problem was solved, but it can no longer be answered in.
- Answers go to round 1 or the current revision, and nowhere else (`round_not_current`, 409).

## CourseProgress

`CourseProgress.new(learner, course)` (`app/services/course_progress.rb`) computes everything from those two tables, with one query for each:

| Method | Gives |
|---|---|
| `solved_in(round)` | Problem ids solved in that round, in course order |
| `current_revision` | The current revision's number, or nil |
| `times_solved` | Problem id to the number of rounds it was solved in |
| `times_completed` | How many rounds (round 1, current and abandoned revisions) have every problem solved |
| `answerable_round?(n)` | Whether answers may go to round n |
| `started?` | Any completion or revision at all (for `GET /me`) |
| `record!(problem_id, round)` | Records a correct answer; raises `RoundNotCurrent` |
| `start_revision!` | Starts the next revision |
| `as_json` / `summary` | The progress and summary shapes in api.md |

Only problems still in the course count. Completeness is computed, not stored, against the course as it is now: add a problem and every round that does not have it becomes incomplete, and `times_completed` drops. That is deliberate (a course with more in it has not been completed), but it means the number can go down.

`times_completed` is 0 for a course with no problems, rather than counting every round as complete.

## Shuffled choices

In a revision, `GET .../problems/:id?round=N` returns the choices shuffled, so that the answer cannot be remembered by its position. The order is fixed per revision and problem: the seed is `SHA-256("<revision id>/<problem id>")`, so a reload shows the same order and a new revision a new one. Round 1 always keeps the course's order. Choice ids do not change, so checking the answer needs nothing special.

## Races

- Two answers at once: `create_or_find_by!` on the unique index.
- Two revisions started at once: the unique index on (learner, course, number) answers the second with 409 `revision_already_started`.
- An answer for a revision that was replaced between the check and the save: `RoundNotCurrent`, answered with 409.
