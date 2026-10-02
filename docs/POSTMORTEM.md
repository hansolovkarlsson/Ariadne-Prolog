# Postmortem

Every defect this project has found in itself, what caused it, and — the part
worth the paper — **what found it**. The tally at the end is the only real
argument for the checks the project now runs on every push.

[JOURNAL.md](JOURNAL.md) is the narrative; [CHANGELOG.md](CHANGELOG.md) is what
shipped. This is the failures.

## Scope

Fifty-four defects, in five cohorts that failed for five different reasons:

- **Design era**: seven bugs about memory lifetime and ordering, produced by the
  choice to copy structures and manage memory by hand. Five fixed before the
  first commit, and two of the same kind found on 2026-09-27 and 2026-09-29;
  the five are
  documented in full in the [engine
  internals](https://hansolovkarlsson.github.io/Ariadne-Prolog/internals.html)
  under *Five bugs this design produced*, and summarised here.
- **Portability** — three bugs that existed from the first commit and were
  invisible on the machine the interpreter was written on. All three fell out of
  CI's first run.
- **Consistency**: twenty defects in which two parts of the project did not
  agree with each other: the code, the documentation, the standard, the flag
  reporting the behaviour, two predicates that should have matched. Eight found
  while writing the tutorials, two while adding the character predicates, five
  on 2026-09-27, one on 2026-09-28, six on 2026-09-29, one on 2026-09-30 and
  one on 2026-10-02.
- **The suite about itself**: three defects in the checks, each invisible to the
  check because the check was the thing that was wrong. The first found by an
  audit that counted the file against the runner; the other two on 2026-09-27,
  by asking what a check could reach.
- **Scale**: seventeen defects that no test was large enough to meet, a fixed
  buffer, a recursion on the C stack, a cost that grew with the square or a
  fixed allocation, ten found on 2026-09-27, nine of them by probing a
  neighbour of the defect before, three on 2026-09-29, one on 2026-10-01
  and three on 2026-10-02, each a rule that was cheap until the search
  reached past it.

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

### A seventh: `retractall/1` kept the last clause it removed

`retract/1` keeps the clause it has just removed, since its caller may still
be reading it, and frees it on the next retract from the same predicate.
`retractall/1` used the same step for every clause, and so left its last
one allocated after it had returned, when nothing was reading it. Harmless
alone, it was a clause held for as long as the predicate went untouched.

Found on 2026-09-29 by the test suite, when a new check that asserts and
then retracts 10,000 facts put one retained clause into the count
`db_reclaim` bounds across every predicate, and that test failed. It now
reclaims once it has finished. (`f792715`)

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

Nineteen defects in which two parts of the project disagreed. The first eight were
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

Seventeen defects that no test was large enough to meet, ten of them found on
2026-09-27. The first nine came one from another: each fix was followed by probing the same shape a
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
| Loading WordNet's 89,000 facts took 490 MB, 5.5 KB a fact | Every clause has an arena of its own, and an arena's blocks were a fixed 4 KB, for clauses of a hundred bytes | Measuring the first large program loaded, on 2026-09-29, for grammar stage 3 (`99ff4bd`) |
| The grammar's checks took 60 per cent longer after possessives went in, sentences with no *'s* included | The possessive rule was tried at every noun phrase, whatever the sentence held | Timing the checks at each of the day's commits, on 2026-09-29, while looking for a slowdown blamed on the interpreter (`1649f0c`) |
| Refusing one sentence of 28 words took more than six minutes, and the corpus run went from two and a half minutes to twelve and a half | The diagnosis parsed with its violation list open, and with WordNet nearly every noun can stand bare at the cost of one more violation | Timing each sentence of the second corpus after names let long sentences be parsed to the end, then each stage of one, on 2026-09-29 (`39d2965`) |
| Refusing the Class 93 sentence, thirty words and five prepositions, had not ended after seven minutes, and the corpus run that took three minutes was stopped at fifteen | A gerund after a preposition, written that morning, let the verb phrase rule decide the form as a verb's rule does; with agreement relaxed for the diagnosis, every noun WordNet also lists as a verb opened a verb phrase after every preposition | Running the corpus under a time limit before the change was committed, then timing each sentence on a copy with an alarm (`d9763ca`); the rule is entered only when an *-ing* form follows, a lookahead the diagnosis does not relax, and the sentence is refused in three seconds |
| The corpus run went from 184 to 318 seconds of CPU, and the Nita Ambani sentence from a third of a second to fifty, after a participle could stand before a noun, for no reading gained | Two causes outside the rule. The participle test asked `verb_form/3` with the word given, which walks every verb for each of its six forms, a millisecond, and the grammar asked it at every word a noun phrase could start at; and *as* was not in the lexicon, so WordNet supplied it as a noun, the Roman coin, and *best known as* became a noun phrase headed by *as* once *known* could be swallowed, where the old grammar had never got past *known* | Timing each sentence against the commit before on a copy of the tree, then benchmarking the lexical lookups one by one, then cutting the slow sentence down until the cost moved (`0769a0e`); the answer is kept per word while a sentence's placements stand, and *as* is a preposition |
| A request without a verb, *two cups of tea, please*, cost the corpus run seventy seconds, 3:40 to 4:51 | A command is tried on every sentence nothing else reads, which is the expensive kind, and the request parsed a noun phrase for each of them before the missing *please* was noticed | Timing the run before the commit (`7946581`); the rule is entered only when a *please* is somewhere ahead, the guard the possessive has |
| Reading the Kazakhstan sentence ran for minutes once a number before the noun let it be read, where it had been refused in nine seconds; a ten-word cut took three | Not the number: each word of a capitalized run is a noun in WordNet as well, so a noun phrase could end at any of them and try the rest as a relative clause with no relative word, which starts the same search again one word on, six times the cost for every word of the run, and every sentence with a run of names had been paying | Cutting the sentence down until the cost moved, which left the names and no number (`fd637af`); a head that is a name does not end before another name, and the corpus run fell from 2:43 to 1:12 |

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

### A loader that did not know which file a clause came from

`consult/1` added every clause to its predicate, whatever file it came from.
ISO and SWI-Prolog both treat a file as defining its predicates, and three
things went wrong because this loader did not:

- **Two files that defined one predicate were merged**, silently. The
  grammar checker's `check.pl` and its `tests.pl` both came to define
  `readings/2`, one as a rule over a list of words and one as facts. The
  merged predicate, called with its first argument unbound, ran the rule,
  which parsed an unbound word list and so generated English sentences
  without end. The run was killed for memory 25 seconds later, with no
  message.
- **A program's own library predicate was added to the library's.** A file
  holding `member(x, _).` made `member(X, [a,b])` answer `[a,b,x,x,x]`: the
  library's clauses, then the program's once for each element they had
  walked. Writing your own `member/2` or `append/3` is the first exercise in
  most Prolog courses, and this interpreter was written to teach from.
- **Consulting a file again doubled its clauses.**

A predicate now belongs to the file, and the load of it, that first gave it
clauses. Loading that file again replaces them. Another file replaces them
with a warning naming both, and a library predicate is replaced without one.
`multifile/1`, which did not exist, lets a predicate collect clauses from
several files. (`6a20648`) A file was still known by the path it was found
at, so one file reached by two spellings of its path was two files, and
loading it the second way warned that it redefined itself. On 2026-09-29
the path is normalized as text first (`2e774bc`). A symbolic link, or an
absolute path against a relative one, still makes two, since telling them
apart needs `realpath()`, which is not C99.

Found on 2026-09-28 by a naming slip while writing the grammar's stage 2,
the first program here big enough to be split into files that share names.
Once the merge was known, the other two were found by trying its
neighbours: another source of clauses for one predicate, and the same
source twice. Only the first was on the roadmap.

*What this says:* a behaviour nothing mentions can still be a decision, and
a wrong one. The loader had never been asked what a file owns, because
every program loaded so far had been one file, or files with no names in
common.

### A verb the lexicon could not spell

The grammar checker's lexicon derives a verb's past from its base, and
lists the irregular ones beside it. *Sleep* was not among them, so its past
was *sleeped*, and *the dog slept* had been a sentence with an unknown word
since stage 1 (`7fda6d9`). No check used the past of *sleep*: the lexicon
and English disagreed, and nothing compared them.

Found on 2026-09-28 by writing a test, *the dog was slept*, meant to fail
for want of a passive, which failed for want of the word instead. Every
verb's five forms were then printed and read over, and the other 48 were
right. (`29b45a2`)

*What this says:* a table of exceptions is checked only where something
reads it, and a lexicon is mostly exceptions nobody has read.

### Entries the lexicon had short

*Tell* was listed as taking two objects and never one, *open* one and never
none, and *early* only as an adjective. So *my grandmother tells wonderful
stories*, *the museum opens on Sundays* and *we should leave early* were
rejected. WordNet has all three right, and is never consulted for a word
the lexicon lists, which is deliberate: it keeps *can* and *will* from
becoming nouns. The fix was the entries (`d3fc401`).

Found on 2026-09-29 by running fifty ordinary sentences through the grammar
for its stage 3 record, where they were three of the 22 failures. Trying
the same question on the entries beside them found *close* with the same gap
as *open*, and *late* with the same gap as *early*.

*What this says:* the checks tested each verb in the frames it was given,
never whether those were all the frames it has. Sentences someone else
wrote are what ask that.

### A checker that did not read the digits

The grammar checker's tokenizer kept letters and dropped everything else,
digits included. So *the price was 3.5 pounds* was checked as *the price
was pounds*, which is grammatical, and the verdict said so. A sentence
with a number in digits was judged on what was left of it, and nothing
said that anything had been left out.

Found on 2026-09-29 by running the tokenizer on a sentence with digits
before building numbers on it, half an hour after the new text checker's
own first sample had passed that sentence without anyone noticing. A
number in digits is now a word (`42fdaf7`), and *I saw 1 dogs* is caught.

*What this says:* a pass is a claim too. The sample was read for its
failures, and the one wrong pass in it went by.

### A checker that did not read the commas

The same tokenizer dropped commas with the rest of the punctuation, so a
sentence was checked without them. *Two cups of tea, please* passed, as
*two cups of tea please* with *please* the verb, and *Alice, Bob and Carol
sing* passed as a name, *Alice Bob*, and *Carol*: two people. The verdict
was right and the reading was not, and nothing showed which. The first was
seen on the morning of 2026-09-29 and recorded as a pass for the wrong
reason; the second was made by the names added that afternoon, and seen in
the second corpus as *Yevgeny Leonov, Irina Skobtseva, and Valentina
Talyzina*, read as two people. A comma is now a word the grammar must
place (`f4b8c6c`), and the first corpus records the request that has no
verb as not grammatical.

Found by reading the passes of the second corpus with their brackets, on
the morning's advice, rather than counting them.

*What this says:* the digits were the same defect, found the same morning.
Fixing the one piece of punctuation that had bitten left the others to be
found the same way.

### A downcase that knew only ASCII

`downcase_atom/2` lowercased each byte with C's `tolower()`, so A to Z and
nothing else: a letter written in two bytes of UTF-8 kept its case, and
*Île* stayed *Île*. The grammar checker lowercases each word before it
looks it up, and *Île-de-France* came out unknown with its capital still
on. `char_type/2` had case for A to Z only, so the two agreed with each
other and with nothing past ASCII. SWI-Prolog lowercases every letter
Unicode gives a lowercase for.

On 2026-09-30 all three came to read one table in C, Unicode's one-to-one
mappings for Latin-1, Latin Extended-A, Greek and basic Cyrillic, and the
reference lists the table's reach as a deviation (`f80b1b7`). A test walks the
table and checks that every mapping goes back where it came from.

Found on 2026-09-29 by the second corpus, the first text here drawn from
outside, with names in French, German, Turkish and Russian.

### A sentence splitter that stopped at abbreviations it did not list

`check_text/1` ends a sentence at a full stop before a space, unless the
word is on a short list of abbreviations. *Lit.*, *U.S.*, *Vol.* and *N.*
are not on it, so *El Gordo (lit. The Fat One) is ...* was cut in two,
and so were three more of the sixty leads drawn for the second corpus. The
corpus keeps the true sentences, and the four cuts are recorded beside it.
A longer list would have moved the problem rather than ended it, since
*no.* and *etc.* came off the list that morning for ending real sentences.
On 2026-09-30 the splitter learned the shape of an abbreviation instead:
initials, and a short word before a number, with *lit.* added to the list
for what shape cannot tell (`b58529a`).

Found on 2026-09-29 by cutting the second corpus's text with the checker's
own splitter, which was chosen for the purpose so that its faults would
show.

### A rename onto the tests' own predicate

Checking the mark at the end of a sentence (`d27c836`) renamed the
checker's `verdict/1`, which prints a verdict, to `verdict/2`. The grammar's
`tests.pl` already had a `verdict/2` of its own, and a predicate belongs to
the file that first gave it clauses, so loading the tests replaced the
checker's with a warning. Nothing failed, since the tests never call
`check/1`, and the warning was printed on every run for a day, in CI's log
too. Each run's output had been filtered down to the line with the count,
and the warning was not on it. The checker's is `report_verdict/2` now, and
`make english` fails if loading the grammar and its tests prints a warning
(`eb320e4`).

Found on 2026-09-30 by running three new checks against the old code in a
scratch copy and reading the whole of its output.

*What this says:* the loader's warning was built for exactly this, on
2026-09-28, and it worked. A warning nobody reads is a check that cannot
fail, so it now fails the build.

### A pair's first word made known, and *out* lost its adverb

Two-word prepositions, *as of*, *out of*, *because of*, went in on
2026-10-02, and the first version counted a pair's first word as a word
the checker knows. A known word is never looked up in WordNet, which is
deliberate, so that *can* and *will* do not become nouns; and *out* is
an adverb and an adjective only through WordNet. *The lights went out*,
the first corpus's own sentence, lost its reading (`2654e01`).

Found at once by the first corpus's pinned count, which
`make english-wordnet` fails on when a sentence moves either way: the
run printed the one sentence and the count it expected. The pair now
says nothing about its first word alone, and *ran out of the garden*
has two readings, *out* an adverb before *of the garden* or the pair,
both English.

*What this says:* the pinned count was added on 2026-09-29 so that a
change which moved a sentence would be seen whichever way it moved it,
and this is the first time it caught a sentence moving the wrong way.

## What found what

| Found by | Count |
| --- | --- |
| Reading the code | 11 |
| Writing the documentation, then testing the claim | 6 |
| Probing past what the suite tries, at a million elements or levels | 4 |
| Loading a large program and measuring it | 1 |
| Running ordinary sentences through the grammar | 3 |
| Reading a corpus's passes with their brackets | 1 |
| Reading the whole output of a run that was usually filtered | 1 |
| Running the tokenizer on a case before building on it | 1 |
| Timing each commit, looking for another cause | 1 |
| Timing each sentence of a corpus, and once each stage of one | 2 |
| Timing each sentence of a corpus against the commit before, then cutting the slow one down until the cost moved | 3 |
| A corpus count pinned in the runner, which fails the build when a sentence moves | 1 |
| CI's first run (matrix, `-Werror`, sanitizer configuration) | 3 |
| The test suite | 4 |
| Rendering the pages and looking at them | 3 |
| Address sanitizer | 1 |
| An audit counting the test file against the runner | 1 |
| Searching the tree for the shape just fixed | 1 |
| Writing a test, which the defect then killed | 2 |
| Diffing the old binary's answers against the new | 1 |
| Using the interpreter for something else, and making a mistake | 2 |
| Counting what a check actually did | 1 |

Three things stand out.

**The test suite found four of fifty-four.** It is a good suite, 334 tests
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
| `make test` loads two files that define one predicate, one that defines `member/2`, one file twice, and one file by two spellings of its path | the loader that merged clauses from every source |
| `space_clause`: 10,000 small facts must cost under a kilobyte each, read from `statistics(program, _)` | the 4 KB arena blocks, which no check measured |
| `make english` fails if loading the grammar and its tests prints a warning | a rename onto the tests' own `verdict/2`, warned about on every run for a day |

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
