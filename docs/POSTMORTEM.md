# Postmortem

Every defect this project has found in itself, what caused it, and — the part
worth the paper — **what found it**. The tally at the end is the only real
argument for the checks the project now runs on every push.

[JOURNAL.md](JOURNAL.md) is the narrative; [CHANGELOG.md](CHANGELOG.md) is what
shipped. This is the failures.

## Scope

Thirty-seven defects, in five cohorts that failed for five different reasons:

- **Design era**: six bugs about memory lifetime and ordering, produced by the
  choice to copy structures and manage memory by hand. Five fixed before the
  first commit, and one of the same kind found on 2026-09-27; the five are
  documented in full in the [engine
  internals](https://hansolovkarlsson.github.io/Ariadne-Prolog/internals.html)
  under *Five bugs this design produced*, and summarised here.
- **Portability** — three bugs that existed from the first commit and were
  invisible on the machine the interpreter was written on. All three fell out of
  CI's first run.
- **Consistency**: fifteen defects in which two parts of the project did not
  agree with each other: the code, the documentation, the standard, the flag
  reporting the behaviour, two predicates that should have matched. Eight found
  while writing the tutorials, two while adding the character predicates, five
  on 2026-09-27.
- **The suite about itself**: three defects in the checks, each invisible to the
  check because the check was the thing that was wrong. The first found by an
  audit that counted the file against the runner; the other two on 2026-09-27,
  by asking what a check could reach.
- **Scale**: ten defects that no test was large enough to meet, a fixed
  buffer, a recursion on the C stack or a cost that grew with the square, all
  found on 2026-09-27, nine of them by probing a neighbour of the defect
  before.

## Cohort A — the design era

Five bugs, every one a mistake about **lifetime** or about **when a value is
read**. That is not a coincidence: it is the specific failure mode of a
structure-copying engine with three memory regions and no compiler checking
which is which.

| Symptom | Cause | Found by |
| --- | --- | --- |
| A nested `findall` read freed memory | Instantiating a clause shared constant cells instead of copying them; a `findall` buffer is freed while its results are live | Address sanitizer |
| `clause/2` and `retract/1` returned only their first solution | The next candidate clause was chosen *after* head unification had bound the arguments, so indexing rejected everything remaining | Test suite |
| A soft cut produced an extra answer | The flag marking the alternative dead was trailed, so backtracking brought it back | Test suite |
| Retrying a choice point read freed memory | The if-then-else alternative was built *after* the choice point took its heap mark | Reading the code |
| `write_canonical` output would not read back | The atom `.` was written unquoted, and `atom_codes` returned bytes rather than character codes | Test suite |

Two of these are worth restating as rules, because both are easy to reintroduce:

- **Anything a choice point refers to must be older than the mark it holds.**
  The fix was to move the constants involved outside the heap entirely.
- **Anything derived from a call must be derived before the call binds
  anything.** Indexing that reads state unification is about to change is
  indexing that is always one step stale.

The internals page adds the observation that none of the five was found by
*using* the interpreter — only by the sanitizer, by tests that asked for every
solution rather than the first, and by reading. That is the argument for
`make test-asan` and for writing `\+ more_solutions` style tests.

### A sixth, found later: `abolish/1` freed clauses in use

`retract/1` had always kept a retracted clause on a garbage list, because a
choice point on the predicate could still walk to it. `abolish/1` did not: it
freed every clause of the predicate at once, live or retracted, whether or not a
choice point was on one. Backtracking into a predicate abolished under it read
freed memory, and `findall(X, (p(X), (X == 2 -> abolish(p/1) ; true)), L)` died
with SIGSEGV.

Found on 2026-09-27 by reading `pred_abolish` while making retracted clauses
freeable, and confirmed by running that goal against the old binary. It is the
first rule above broken by the one path nobody had checked it on: anything a
choice point refers to must outlive it. `abolish/1` now puts every clause on
the garbage list, and each predicate counts the choice points on its clauses,
so the list is freed only when that count is zero. (`d936ad0`)

## Cohort B — portability

Three bugs, all present from the first commit, none reproducible on the
development machine, all found by CI's first run. Adding the matrix was the
roadmap's first item; it paid for itself immediately.

### `strdup` is POSIX, not C99

Under `-std=c99`, glibc does not declare `strdup`. The call therefore compiled
as an implicit declaration returning `int`, and **the pointer was truncated to
32 bits before being stored**. On Linux this corrupted the stream name in
`open/3` and the text buffer that `atom_length/2`, `atom_codes/2` and
`format/2` use for numbers.

macOS headers declare `strdup` whatever the standard setting, which is exactly
why it was never seen locally. The fix is `pl_strdup`, four lines of C99.
(`c486ab3`)

*What this says:* a warning suppressed by one platform's headers is not a
warning that has been dealt with. `-std=c99` means the standard library is
smaller than habit assumes.

### Seventeen gcc warnings clang never mentioned

`-Wmaybe-uninitialized` fired seventeen times, all on one shape: a local passed
by address to one of four accessor functions, which gcc cannot prove is written
on the success path.

The tempting fix — initialise seventeen call sites — was rejected in favour of
fixing the four accessors so they write their outputs before doing anything
else. That is what every caller already assumed, so the warnings were pointing
at a real (if latent) contract that had never been written down. (`8fbcf05`)

*What this says:* when a warning fires seventeen times in one shape, the warning
is describing an interface, not seventeen accidents. Fix the interface.

### `X is -1 << 2` was undefined behaviour

Shifting a negative value left is undefined in C. It produced the expected `-4`
on both compilers, every time, which is the worst way for undefined behaviour to
behave. It surfaced when the sanitizer build was tightened to **abort** on
undefined behaviour rather than print and continue — at which point it would
have failed the build the moment any program exercised the path. Doing the shift
unsigned gives the same two's complement answer with defined behaviour, and two
tests now exercise it under the sanitizer. (`f81293b`)

*What this says:* `-fsanitize=undefined` without `-fno-sanitize-recover` is a
log file, not a test. A finding has to fail the run or it scrolls past.

## Cohort C — consistency

Fifteen defects in which two parts of the project disagreed. The first eight were
found while writing the four tutorial levels, which is the interesting part: writing
documentation is a different test from writing tests, and it found things the
256-test suite never would have.

### `max_arity` was three different numbers

`current_prolog_flag(max_arity, V)` answered `unbounded`. `=../2` stopped at
255 — its buffer held the functor name and 255 arguments, and the bound was
checked against the list length rather than the arity. The reader stopped at
256. And `functor/3` **had no check at all**: `functor(T, f, 100000)` built the
term, and a large enough arity would have overflowed the `int` the arity is
stored in.

Found by writing a sentence in the reference and then testing whether it was
true. `MAX_ARITY` in `src/prolog.h` is now the single definition; all three
paths use it, and the flag reports the integer. (`8831038`)

*What this says:* a limit that appears in more than one place is not a limit, it
is a coincidence waiting to be discovered. And a flag that reports a policy the
code does not enforce is worse than no flag.

### The disclosure marker rendered as `B8?A0Solutions`

The shared CSS block was a plain Python string. `content: "\25B8\00A0"` — a
perfectly good CSS escape for `▸` plus a non-breaking space — was read by
**Python** first, where `\25` is an octal escape. The browser received a control
character, `B8`, a NUL and `A0`.

Live on every published page since the site went up. Found by rendering a page
and looking at it. The block is a raw string now. (`afbc1cb`)

*What this says:* generated markup passes through two languages' escaping rules,
and the first one wins silently.

### Note titles overlapped their own body text

`.note-tag` was `white-space: nowrap` at a fixed `7.5rem`, so any title longer
than that overflowed into the prose beside it. Also live since the site went up,
on pages that had been reviewed. Found by rendering. (`afbc1cb`)

### `*emphasis*` reached six pages as literal asterisks

The shared `inline()` handled `**bold**` and nothing else, so every author's
single-asterisk emphasis was published verbatim. Found by grepping the rendered
output for asterisks that had survived. (`afbc1cb`)

*What the last three say together:* the pages are generated, so they were
checked by regenerating them — which proves only that the generator is
deterministic. Three defects sat in the output for nine days because nobody had
**looked at** it.

### Two deviations from ISO that nothing recorded

Writing Level 4 turned up two behaviours the reference did not mention:

- **There is no logical update view.** A goal backtracking through a predicate
  sees clauses asserted after it started, and skips clauses retracted ahead of
  it. This announced itself by **hanging**: a transcript query that asserted to
  the predicate it was walking ran forever. Retracting the clause the goal is
  currently on is safe; nothing else is.
- **There is no `setup_call_cleanup/3`**, and `dynamic/1` is a predicate rather
  than a prefix operator, so `:- dynamic foo/1.` is a syntax error.

Neither is a bug — both are consequences of a small implementation — but the
reference claims to list *anything the interpreter does not provide*, and it did
not list these. Both are in *Deviations and limits* now. (`78d43c4`)

*What this says:* the deviations list decays silently, because nothing tests a
list of absences. The only thing that finds a missing entry is somebody trying
to do the thing.

### Two worked exercise solutions were wrong

Both in a draft of Level 4, both caught by running them:

- A solution that handled some exceptions and let others through by letting the
  recovery **fail**. A failing recovery does not re-throw — `catch/3` simply
  fails and the ball is gone. The correct form has to `throw/1` it again
  explicitly.
- A cleanup predicate written as `catch(Goal, E, true)` followed by the cleanup
  goals. That handles success and exceptions but not **failure**: a failing Goal
  makes `catch/3` fail and the cleanup never runs.

Both were plausible enough to write down and wrong enough to teach the reader a
bug. Neither would have been caught by re-reading.

*What this says:* worked solutions are code. The fact that they live in a
document does not change what they are.

### Two claims that had stopped being true

Both found on 2026-09-25 while adding the character predicates (`0a37c7c`),
neither by a check:

- **`put_char/1` wrote any atom.** The reference said "Writes a one-character
  atom" and the code called `get_atom` and wrote whatever it got, so
  `put_char(ab)` printed `ab`. Found by reading the one-argument version in
  order to write the two-argument one next to it. It raises
  `type_error(character, ab)` now, as ISO has it.
- **Six of the twelve line counts on the internals page were wrong**,
  `src/builtins.c` by forty-six lines and `lib/boot.pl` by seventeen in the
  other direction. Found
  when the change moved `src/stream.c` and the table had to be touched: counting
  every row with `wc -l` rather than only the edited one showed the rest had
  drifted too. All twelve are current now.

*What this says:* a figure in a document that nothing regenerates is a claim
that starts decaying the day it is written, and the only thing that re-checks
it is somebody editing the row next to it. The same goes for a one-line
description of a predicate: it was true of what the author meant, and nothing
compared it with what the code did.

### Three pairs that should have matched

All found on 2026-09-27, each while working on the other half of its pair:

- **The prompt read standard input through a reader of its own.** Day five made
  `read/1` and `get_char/1` share `user_input`'s one reader and its pushback;
  the toplevel in `src/main.c` still built a second one on the same `FILE`.
  They agreed until one of them held a pushed-back character: after
  `?- peek_char(C).` the peeked `x` sat in `user_input`'s pushback, the next
  query was read without it, and a later `get_char` answered with the stale
  character. Found by reading the toplevel while working on `open/4`, and
  confirmed by piping input to the prompt. It reads through `user_input`'s
  reader now. (`a16c715`)
- **`read/2` and `read_term/3` took an output stream** and answered
  `end_of_file`, having read from standard output's descriptor, where
  `get_char/2` raised `permission_error(input, stream, S)`. Found by reading
  `read_from_stream` while adding the end-of-stream check to it. (`63dccdb`)
- **Splitting did not undo joining for a numeric separator.**
  `atomic_list_concat([a, b], 1, A)` gives `a1b`, but splitting `a1b` on `1`
  gave `[a1b]`, because the split looked for the separator with `sub_atom/5`,
  which wants an atom; a code-list separator never matched either. Found by
  diffing the old binary's answers against the new split's on 22 cases.
  (`8a5b8a3`)

*What this says:* the day-five lesson again, from the other side. Two
mechanisms that do the same job will drift apart, and the one to check is the
one nobody is editing.

### An error the printer had no words for

`format/2` raises `error(format(Message), _)` when its arguments do not fit its
directives, as SWI-Prolog does, and the error printer had no case for that
formal term, so it fell through to its last line: `ERROR: format/2: Unhandled
exception: error(format('not enough arguments'), ...)`, the raw term, as if
nothing had caught it. `resource_error/1` fell through the same way. The two
halves of the error path, what is raised and what is printed, had been written
apart, and nothing listed what the one could raise against what the other could
say.

Found on 2026-09-27 by a mistake of the author's own, a `format/2` call with
nine directives and two arguments made while counting the grammar's lexicon.
Both print as messages now, and `make test` checks the first. (`3187426`)

### A cut that reached through a variable

ISO converts a clause body when the clause is made: a variable where a goal
stands becomes `call(V)`, so that a cut the variable is later bound to is local
to it. `clause_make` did no conversion. A body variable ran as whatever it was
bound to, so `p :- G = !, G, fail.` cut `p`'s other clauses and failed, where
ISO has it succeed through the next one, and `clause/2` returned the body as a
bare variable rather than `call(G)`. The reference described cut as opaque to
`call/1` and said nothing about variables, and nothing tested one.

Found on 2026-09-27 by reading `clause_make` while designing error contexts,
which needed to know whether a goal a library predicate was handed arrived
through a meta-call. Bodies are converted now, iteratively, and the cut is
local. (`a1336d2`)

## Cohort D — the suite about itself

Three defects, and they get a cohort of their own because they failed for a
reason none of the cohorts above name: the check that would have found them was
the check that had them.

### Thirteen tests that never ran

The arithmetic section of `tests/test.pl` held thirteen tests written as

    test(ar_add,          X is 2 + 3, X =:= 5).

with no parentheses around the conjunction, next to a hundred written as
`test(name, (G1, G2))`. Prolog reads the first form as a fact of arity three,
or four for `ar_intdiv`, and the harness runs `forall(test(Name, Goal), ...)`,
which is `test/2`. The thirteen consulted without complaint, sat in the database
under a name nothing queried, and the suite printed **256** from the first
commit (`e31b881`) while the file held 269.

Every record quoted the 256: the README twice, this document, the journal, the
site's front page. All of them were true of what ran and none of them was true
of what was written.

Found on 2026-09-12 by an audit whose rule is that every number in its report is
one it watched come out of a command. It counted `^test\(` lines in the file,
got 269, counted what the harness enumerated, got 256, and `comm` named the
thirteen. Run by hand as conjunctions, all thirteen pass: the interpreter was
never wrong about arithmetic, only the suite about itself. They are `test/2` now,
and the suite is 269. (`af41122`)

*What this says:* a suite reports what it ran, not what was written, and the
gap between the two is a number no check was producing. A count that has been
stable since the first commit is not a count that has been verified; it is one
nobody has had a reason to look at. And the day-three lesson has a mirror
image: green is not the same as quiet, and quiet is not the same as complete.

### The collector's leg never collected

`make test-gc` ran the whole suite with `PROLOG_GC_THRESHOLD=1`, and the
Makefile said that exercised the collector "on every code path". It ran **not
one collection**. The collector only runs when no choice point is live, and
`run_tests` holds several around every test: `forall/2`'s for the next test,
and the `->` and `catch/3` in `run_one/2`. The second leg of `make test-asan`
was the same run again. Every count in these records of "both legs" was one
leg run twice.

Two more things kept it quiet. The threshold reset to three times the live heap
after each collection, whatever `PROLOG_GC_THRESHOLD` said, so "at every
opportunity" was one collection and then a long wait; and the collector was
only considered every 1024 inferences, which most tests never reach.

Found on 2026-09-27 while writing a test for the collector's own deep-nesting
crash (Cohort E): the question was whether the suite could reach `gc_copy` at
all, and a counter printed at exit answered it with 0. The second leg now runs
every test again bare, as `Goal, !` with nothing around it, with the threshold
held and the collector considered every fourth inference: about 575,000
collections, inside every one of the tests. A collector planted with a bug,
one that stopped forwarding variables, passed the old leg and fails the new
one. (`19f42ca`)

### A goal that failed exited 0

A `-g` goal that failed printed a warning, ran the goals after it, and exited
0, as the reference documented. To `make` and to CI that was success: `make
examples` and `make tutorials` run ten goals, and any of them could have
failed and left the build green. The tutorial programs are what the published
pages quote, so the check that keeps them true could not fail. Found the same
day, designing the bare leg, which stops at its first failure and needed that
failure to reach `make`. A failed goal now ends the run with status 1, and
`make test` checks it. (`67b3a74`)

*What these two say:* a check is known to work only once it has been seen to
fail. Neither of these ever had been. The first was measured by what it was
supposed to do, collect, and the second by what it would do on a failure, and
both answers were nothing. Planting a defect and watching the check catch it is
the only evidence that it can.

## Cohort E: scale

Ten defects that no test was large enough to meet, all found on 2026-09-27.
The first nine came one from another: each fix was followed by probing the same shape a
step further, at a million elements or a million levels, and the probe found
the next.

| Symptom | Cause | Found by |
| --- | --- | --- |
| A list literal of more than 4096 elements was a syntax error, "too many arguments" | `parse_list` collected elements into a fixed array; nothing documented the limit | Reading the parser while fixing its arity error (`e8a75ca`) |
| `term_variables/2` returned 4096 variables of 100,000, without a word; `bagof/3` and `setof/3` inherited it; `read_term`'s `variables(L)` stopped at 1024 | Fixed-size arrays that stopped filling when full | Searching the tree for other 4096s after the list (`d156849`) |
| A term of 2000 variables was not `=@=` its own copy, and `\=@=` said so | The renaming was kept in a 1024-pair array, and a full array answered false | Reading `=@=` while fixing the next row (`4006577`) |
| `term_variables`, `ground`, `numbervars`, `unify_with_occurs_check` and `=@=` died with SIGSEGV on a list of a million elements | Each recursed on every argument, list tails included | Probing each walk with a million-element list (`d156849`, `4006577`) |
| Copying a term of a million variables took about five minutes | The variable map under `copy_term`, `findall`, `assert` and every thrown ball found each variable by scanning all before it | Timing the probe, after first blaming `=@=` (`4006577`) |
| `1+1+...+1` at 100,000 levels died with SIGSEGV in the collector, before any builtin saw it; the reader gave out at 5000 levels of brackets, arguments, lists or prefix operators | Every walk recursed on all arguments but the last; the reader also held a 256-slot array on the C stack at each level of a compound | Probing with terms nested in the first argument, after the list case (`d1e3088`) |
| A comment written straight after a full stop, `a.% note`, swallowed the next clause of a consulted file | The full stop consumed the character after it as layout, and when that was `%` the comment lost its opening mark | Probing the prompt's reader with a `%` case (`fcb9128`) |
| `atomic_list_concat` of a million parts ran the machine out of memory and was killed | Joining in Prolog made a new atom at every step, and atoms are never freed | Writing the deep-nesting tests, which built their text that way (`678e501`) |
| Splitting 20,000 parts took five seconds | Splitting interned every remainder on the way | Reading it beside the join (`8a5b8a3`) |
| Reading a clause of 40,000 distinct variables took 0.26 seconds, quadrupling with each doubling | The reader found each variable by scanning every one before it in the clause | Reading the parser at the day's closeout, then timing it (`cabc0a0`) |

Every one of these passed the suite, because every test in the suite is small.
The deep-nesting fix touched the collector, unification, comparison, copying,
the builtins' walks, the writer, the evaluator and the parser, and each was
checked against the binary before it: writer output over 72 cases, arithmetic
results and errors over 40, every clause in the repository read to identical
terms. `tests/deep.pl` now puts million-deep terms through 21 walks at the top
level, where the collector can run, and fails unless it did.

*What this says:* a limit nobody measured is a limit nobody knows, and the
suite measures nothing about size. One wrong turn is worth keeping. The
quadratic cost was first put down to `=@=`, whose own map had just been
rewritten; it was `copy_term`, run just before it in the same probe, and timing
each half separately was what showed it. The probe that finds the next defect
is the one aimed at the neighbour of the last.

## What found what

| Found by | Count |
| --- | --- |
| Reading the code | 11 |
| Writing the documentation, then testing the claim | 6 |
| Probing past what the suite tries, at a million elements or levels | 4 |
| CI's first run (matrix, `-Werror`, sanitizer configuration) | 3 |
| The test suite | 3 |
| Rendering the pages and looking at them | 3 |
| Address sanitizer | 1 |
| An audit counting the test file against the runner | 1 |
| Searching the tree for the shape just fixed | 1 |
| Writing a test, which the defect then killed | 1 |
| Diffing the old binary's answers against the new | 1 |
| Using the interpreter for something else, and making a mistake | 1 |
| Counting what a check actually did | 1 |

Three things stand out.

**The test suite found three of thirty-seven.** It is a good suite, 330 tests
run normally, again bare with the collector inside every test, and again under
two sanitizers, and it found under a tenth of the defects. Everything it found
was a wrong *answer*. Everything it missed was a wrong *limit*, a wrong
*platform assumption*, a wrong *claim in the documentation*, a wrong *count of
itself*, or, on 2026-09-27, a wrong *size*, and no realistic number of
additional small tests would have changed that. Until that day its second leg
had also never collected, so "twice per leg" in this paragraph was itself one
of the claims that was not true.

**Writing the documentation found the most of any one activity before
2026-09-27.** Six defects, and they were the ones nothing else could have
reached, because the question a document asks is "is this sentence true?",
which is a different question from "does this goal succeed?". The most
productive single activity in the project was writing a tutorial for a
beginner, because a beginner's questions have no respect for which parts were
carefully implemented.

**Reading the code now leads, and it is not one activity.** Nine of its eleven
were found on one day, each while working on something beside it: the parser
while fixing its error path, `=@=` while fixing its crash, the toplevel while
working on streams. Reading the path that will be touched, before touching it,
finds what the path next to it gets wrong.

## What changed as a result

Each standing check exists because of something above:

| Check | Added because of |
| --- | --- |
| The build matrix, Linux and macOS, clang and gcc, `-Werror` | `strdup`, the seventeen gcc warnings |
| `-fno-sanitize-recover=undefined` | the shift, which the sanitizer had been printing and continuing past |
| `make test-asan` on every leg | the use-after-free class; it found one of the two directly |
| `make test-gc`: every test again, bare, with the threshold held and the collector considered every fourth inference | the second leg, which ran with choice points live and never collected; it replaced a leg that forced only the threshold |
| `make test-deep`: terms nested a million deep through 21 walks, failing unless `statistics(garbage_collection, _)` shows a collection | the collector's crash on deep terms, which no test was large enough or deterministic enough to reach |
| A failed `-g` goal exits 1, and `make test` checks it | ten example and tutorial goals whose failure could not fail the build |
| `make doc` + `git diff --exit-code` | pages drifting from their generators |
| `make tutorials` | four tutorial programs that nothing was loading |
| Tests written against `current_prolog_flag(max_arity, N)` rather than `256` | `max_arity`, so the tests stay honest if the limit moves |
| `run_tests` refuses to start while any arity of `test` other than 2 exists | the thirteen tests that consulted as `test/3` and were never run |

## What is probably still wrong

Stated plainly, since the pattern above is that the unlisted things are the
expensive ones:

- **The deviations list is still incomplete.** Two entries were added by
  accident, in the course of writing one tutorial level. There is no reason to
  think that was the last of them.
- **Nothing systematically checks the reference against the interpreter.** Every
  signature in it was verified by hand once. A predicate whose behaviour changes
  will not update its own entry.
- **An error's context names a predicate, not a place.** It says which
  predicate the program called, not which clause of the program called it,
  and an unknown procedure or a program's own throw still has none. There is
  no backtrace.
- **More costs grow with the square than the ones found.** Nothing measures
  cost at size, so each was found by accident, the last of them, the reader's
  scan for a clause's variables, while writing this list.
- **The collector is exercised, not proven.** The second leg now collects
  inside every test, and one planted defect was caught; one is not many. A
  collector is only tested against the kinds of wrong it was tried with.
