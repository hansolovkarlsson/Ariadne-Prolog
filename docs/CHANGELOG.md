# Changelog

What has shipped, newest first. [ROADMAP.md](ROADMAP.md) holds what has not.

There are no releases yet, so entries are grouped by the day they landed on
`main`. Commit hashes are given so each entry can be read in full with
`git show`.

## 2026-09-29

### Added

- **Nouns before nouns.** *The record label*, *a water polo player*, *the
  NBC television network*: singular nouns may stand between the
  adjectives and the noun, and *a* or *an* goes by the first word, *an
  apple tree*. A word that is an adjective or a name there is read as
  that only, so the first corpus's readings do not grow. 376 checks; the
  second corpus goes to 7 grammatical. (`fca8565`)

- **A number after a name.** *Class 91*, *Apollo 11*, *the InterCity 250
  project*: a number in digits may belong to the name before it, and a
  first word followed by one may be a name, *Class 93 is*. 368 checks; no
  corpus sentence moved, as the *Class 91* sentence now stops at *entered
  service*. (`5263460`)

- **Lists, with *and* or *or*, and the commas they need.** A comma is
  now a word, read only where a rule places it: in a list, between two
  clauses, and before a last *please*. One list rule serves noun phrases,
  *Alice, Bob and Carol sing*, nouns under one determiner, *a doctor and
  teacher*, and adjectives, *big, old and happy*, *a big, old dog*. *Or*
  agrees with the nearest, *the dog or the cats bark*. Dropping commas had
  made passes for the wrong reason, and the first corpus loses one: *two
  cups of tea, please* has no verb. 363 checks; the first corpus 49 of 50,
  the second still 6, and `make english-wordnet` a minute faster.
  (`f4b8c6c`)

- **Names, known by their capital.** The tokenizer notes which words a
  sentence capitalizes, and each is a name there beside its other
  readings; the first word only when the next is a name too, when WordNet
  writes it with a capital, or when nothing knows it, so *Dog barks* is
  still refused. A run of names is one name, *Stanley Ralph Ross*, and a
  name stands before a noun, *the Congress Party*. `make wordnet` now
  keeps WordNet's 14,783 capitalized nouns as names. The diagnosis
  searches with at most three violations, as a sentence of 28 words took
  over six minutes to be refused with any number. 337 checks; the second
  corpus goes from 0 grammatical to 6, 34 not, 10 unknown. (`39d2965`)

- **A second corpus for the grammar checker, from text it was not built
  against.** Fifty sentences, the first two of each of 25 articles drawn at
  random from Simple English Wikipedia, by a rule fixed before the text was
  seen, in `english/corpus2.txt`, with each article's revision in
  `english/corpus2-sources.tsv`. None passes: 19 are rejected and 31 have a
  word the checker does not know, mostly names. The counts are pinned in
  `english/corpus.pl` beside the first corpus's, and the README records the
  causes, with the time one sentence takes, 116 seconds. (`45374ee`)

- **The constructions the grammar checker lacked.** Adverbs before the
  verb, *has already eaten*; *very* and the other degree words; verbs that
  take an adjective (*tastes good*), a clause (*think that she is right*),
  a *to*-infinitive (*wants to learn*), an object and an infinitive, an
  object and an adjective (*paint the kitchen blue*), or an *-ing* form;
  noun phrases as adverbs, *last night*; *such a*; and commands, *please
  close the door*, read only when no statement can be. WordNet's verb
  frames for these, which the generator dropped, are now kept. 325 checks;
  all fifty corpus sentences pass. (`819ae98`)

- **Conjunctions, numbers, indefinite pronouns and more prepositions** in
  the grammar checker, the small closed classes WordNet does not list.
  *And*, *but* and *or* join two clauses, and *because*, *if*, *when* and
  the like join one to another, before it or after it, each clause
  agreeing on its own. Numbers are determiners or noun phrases, *six dogs*,
  *at six*, *a hundred degrees*, and a number in digits is now a word
  rather than dropped, so *I saw 1 dogs* is caught. *Nobody*, *everyone*
  and nine more are pronouns, and 23 prepositions join, *after* and
  *during* among them. 288 checks; the corpus goes from 34 grammatical to
  40, and every sentence in it now has only known words. (`42fdaf7`)

- **Nouns that take no article.** *Water boils*, *some homework*, *the price
  of bread*: nineteen nouns are marked as mass nouns, by hand, as WordNet
  does not mark them, and a mass noun may stand alone in the singular and
  take *some*, or *much*, which is new and takes nothing else. Fourteen of
  them join the lexicon; *water*, *milk*, *rain*, *snow* and *work* stay
  WordNet's, since a listed word loses its WordNet verb. 261 checks; the
  corpus goes from 31 grammatical to 34. (`94e110b`)

- **The grammar checker takes running text.** `check_file/1` cuts a file,
  or standard input, into sentences and gives a verdict for each, with the
  reason when one fails, then the counts; `check_text/1` does the same for
  an atom. A sentence ends at `.`, `?` or `!` before a space, or at a blank
  line, but not inside a number or after *Mr.*, *Dr.* or *e.g.*. The corpus
  runner now uses the same code. 250 checks. (`a220dd9`)

- **The grammar checker guesses a word missing from its lexicon from its
  ending.** *-ly* is an adverb, *-tion* or *-ness* a noun, *-ful* or *-ous*
  an adjective, *-ize* a verb. An *-s*, *-ed* or *-ing* word is taken back
  to its stem by undoing the lexicon's spelling rules, and the stem is placed
  by its own ending or taken as a noun or a verb. The guessed word agrees as
  a listed one does, so *the zorbles is happy* is still caught, and the
  verdict says what was guessed. A word with no ending to go on is still
  reported, so a misspelling is not read as a new word. *Of* joins the
  prepositions. 205 checks. (`fcb35cc`)

- **The grammar checker reads contractions and possessives, which finishes
  its stage 2.** *She's*, *they're*, *I'm*, *we've*, *I'll* and *he'd* are
  read as the words they stand for, *'s* as *is* or *has* and *'d* as
  *would* or *had*, so *they's sleeping* is caught. A possessive stands
  where a determiner would, *Alice's friend's dog*, *the dogs' bones*. 236
  checks. Stage 2 was estimated at months and took two days. (`36c8d5f`)

- **The grammar checker's stage 3: WordNet's words, and a record of what
  they break.** `make wordnet` downloads WordNet 3.1 and generates
  `english/wordnet.pl`, 85,000 words with verb frames and irregular forms,
  which git ignores. `english/wordnet_check.pl` loads it, and a word missing
  from the lexicon is then looked up there before it is guessed from its
  ending. `make english-wordnet` runs the grammar's checks with it, all of
  which pass, and fifty ordinary sentences, of which 28 pass. The README
  sets out why the rest fail. The lexicon's own words are never looked up,
  and `make english` and CI run without WordNet. (`9650c91`)

- **`read_line_to_string/2` and `read_line_to_codes/2`**, as SWI-Prolog has
  them: the next line without its line ending, as an atom, since there is
  no string type, or as a code list; `end_of_file` or -1 at the end. A last
  line with no line ending is a line. (`63ad3c9`)

- **`statistics(program, [InUse, 0])`**, the bytes the clause store and the
  other permanent arenas hold, as SWI-Prolog names it. The suite uses it to
  check that a small fact costs under a kilobyte, which would have caught the
  4 KB arena blocks below; it reads the interpreter's own count, not the
  process's resident size, which every platform reports differently.
  (`f792715`)

- **CI runs the grammar with WordNet.** A job of its own runs `make
  english-wordnet`, with WordNet 3.1 kept in the Actions cache, and
  `english/corpus.pl` pins the corpus counts, 31 grammatical, 18 not, one
  unknown, so a change that moves a sentence fails there. (`2c5a76d`)

### Fixed

- **The grammar lexicon's incomplete entries.** *Tell* took only two
  objects, *open* and *close* only one, and *early* and *late* were only
  adjectives, so *tells wonderful stories*, *the museum opens* and *leave
  early* failed; WordNet has them right but never overrides a listed word.
  Five checks, 241 in all; the corpus goes from 28 grammatical to 31.
  (`d3fc401`)

- **One file reached by two spellings of its path is one file.**
  `consult(tests/f)` and then `consult('./tests/../tests/f')` warned that
  the second file had redefined the first's predicates. A path is now
  normalized as text before it names the file. A symbolic link or an
  absolute path is not, since that needs `realpath()`, which is not C99.
  (`2e774bc`)

- **`retractall/1` frees what it retracted.** The last clause it removed
  stayed allocated until the next retract on that predicate. (`f792715`)

- **A clause costs memory in proportion to its size.** Each clause has an
  arena, and an arena's blocks were a fixed 4 KB, so WordNet's 89,000 facts
  took 490 MB. Blocks now start at 256 bytes and double: 52 MB. (`99ff4bd`)

- **The grammar's checks are a third faster.** The possessive rule was tried
  at every noun phrase, even with no *'s* in the sentence, and cost 60 per
  cent. It now looks ahead for one first. (`1649f0c`)

## 2026-09-28

### Added

- **The grammar checker's stage 2 has begun: auxiliaries, negation, yes/no
  questions and passives.** A verb phrase is a chain of auxiliaries and then
  the verb, *might have been chased*. Each word in the chain sets the next
  word's form and admits only words ranked above it, so English's order is
  enforced. *Not* goes after the first word of the chain, and a question
  moves that word before the subject: *does the dog not bark*, *is the dog
  happy*, *doesn't the dog bark*. A passive loses its first object to the
  subject. The lexicon gains every verb's *-ing* and participle forms, the
  modals, *have* and *do*, and seventeen *n't* contractions. The diagnosis
  names the new faults: "after 'has' the verb should be 'eaten', not 'ate'",
  "'barks not' should be 'does not bark'". 149 checks, up from 73.
  (`29b45a2`)

- **The grammar checker reads relative clauses and *wh*-questions.** *The
  cat that the dog chased sleeps*, *the park that the dog walks in*, *the
  cat the dog chased*; *who chased the cat*, *what did the dog chase*,
  *which dogs chase the cat*, *where does the dog sleep*. The missing noun
  phrase is a gap threaded through the rules, placed exactly once, and
  shown as `_` in the bracketing. A relative clause's verb agrees with its
  noun, and *whom* stands only for an object. 190 checks. (`b9f2a0d`)

- **`multifile/1`**, so that a predicate may collect clauses from several
  files. (`6a20648`)

### Fixed

- **A predicate belongs to the file that defined it.** The loader added
  every clause to its predicate whatever file it came from. A second file
  that defined the same predicate was merged into the first without a word.
  A program's own `member/2` was added to the library's, so
  `member(X, [a,b])` gave `[a,b,x,x,x]`. Consulting a file again doubled
  its clauses. Now loading a file again replaces its clauses, and another
  file replaces them with a warning naming both, as SWI-Prolog does. A
  program's definition of a library predicate replaces the library's
  silently. (`6a20648`)

- **The grammar checker knows *slept*.** The lexicon had no irregular past
  for *sleep* and derived *sleeped*, which no check asked for until stage 2
  needed the participle. (`29b45a2`)

### Changed

- **The binary is `bin/prolog`,** not `prolog` at the top of the tree. `make`
  creates `bin/`, `make clean` removes it, and `make install` still installs
  it as `$(PREFIX)/bin/prolog`. The README, the tutorials and the pages
  generated from them all say `bin/prolog`. (`f2199a6`)

- **Build products go to `build/`.** The object files used to sit beside
  their sources in `src/`, and the C generated from `lib/boot.pl` lived there
  too. Both now go to `build/`, which `make clean` removes along with `bin/`,
  so `src/` holds only checked-in files. (`4061f1a`, `be1c84c`)

- **The repository is `hansolovkarlsson/Ariadne-Prolog`, and the site
  `hansolovkarlsson.github.io/Ariadne-Prolog/`.** The repository was renamed
  on GitHub, and Pages follows the name, so the lowercase site address is a
  404; git remotes are redirected. Every link in the tree now uses the new
  names. (`b972014`)

## 2026-09-27

### Added

- **`char_type/2` and `code_type/2`,** with SWI-Prolog's types: `alpha`,
  `digit(W)`, `space`, `upper(L)`, `to_lower(L)`, `punct` and the rest. ASCII is
  classified exactly, and a character past ASCII counts as a letter. Either
  argument may be unbound. (`3187426`)

- **An English grammar checker, stage 1, in `english/`.** Written as a DCG and
  run on the interpreter: 262 words, simple declarative sentences with
  determiners, adjectives, prepositional phrases, `and`, and verbs taking
  none, one or two objects, or `be` with an adjective, noun phrase or place.
  It checks subject and verb, determiner and noun, *a* and *an* by sound,
  pronoun case, and a singular noun's determiner, by unification alone; says
  which words disagree when a sentence fails; and prints every reading of an
  ambiguous one as a labelled bracketing. `make english` runs its 73 checks,
  and CI runs it. (`7fda6d9`)

- **Errors say which predicate raised them.** The second argument of
  `error/2` is `context(Name/Arity, _)` for the predicate the program called:
  the builtin itself, or the library predicate whose helper raised it, so
  `atomic_list_concat([a, f(x)], A)` names `atomic_list_concat/3`. A goal
  passed to `maplist/2` or `findall/3` is the program's own, and names what it
  called. The toplevel prints it: `ERROR: is/2: Arguments are not
  sufficiently instantiated`. It stays unbound for an unknown procedure and
  for what a program throws itself. (`a1336d2`)

- **Lambdas, as SWI-Prolog's `library(yall)` has them.** `Params>>Body`,
  `Free/Lambda` and `\X^Body`, so `maplist([X,Y]>>(Y is X*2), [1,2,3], L)`
  works without a named helper. As in yall, the lambda is copied before each
  call, so its variables are local unless declared free with `Free/`. Eleven
  tests. (`99ebdce`)

### Changed

- **The records are in `docs/` and the site in `web/`.** `JOURNAL.md`,
  `POSTMORTEM.md`, `ROADMAP.md` and `CHANGELOG.md` moved from the root into
  `docs/`, and the generated pages from `docs/` into `web/`, which a new
  workflow publishes to GitHub Pages. The site's addresses are unchanged.

- **The interpreter is Ariadne Prolog.** It was called C Prolog, which is the
  name of Fernando Pereira's interpreter from Edinburgh in the early 1980s, an
  ancestor of Quintus and SWI-Prolog. The banner, `--version`, the pages and
  the repository are renamed, and `current_prolog_flag(dialect, D)` answers
  `ariadne` where it answered `cprolog`, which a portable program would have
  taken for the other C-Prolog. The binary is still `prolog`.

### Added

- **A second leg that collects.** `make test-gc` ran the suite through
  `run_tests`, which holds choice points around every test, so the collector
  never ran: not one collection, however low `PROLOG_GC_THRESHOLD` was set.
  It now runs `run_tests_bare`, which runs every test again as `Goal, !` with
  nothing around it, stops at the first failure and names it. With the new
  `PROLOG_GC_INTERVAL=4` and the threshold now held where
  `PROLOG_GC_THRESHOLD` puts it, instead of tripling after each collection,
  every one of the 296 tests is collected while it runs, about 525,000
  collections in 11 seconds. A collector planted with a bug, one that stopped
  forwarding variables, passed the old leg and fails this one. `make test-asan`
  runs the new leg too. `tests/deep.pl` runs once, as the forced run added
  nothing. (`19f42ca`)

- **`statistics(garbage_collection, [Collections, BytesFreed, Milliseconds])`,**
  as SWI has it, and **`make test-deep`**, which runs `tests/deep.pl`: terms
  nested a million deep put through 21 walks at the top level, where the
  collector can run, failing unless it did. `make check` and `make test-asan`
  run it.
  (`d1e3088`)

- **`open/4` options.** The list was accepted and ignored; every option is
  now checked before the file is touched. `alias(A)` names the stream wherever
  a stream is expected, and an alias already in use is
  `permission_error(open, source_sink, alias(A))`. `eof_action(A)` is
  `error`, `eof_code` or `reset`. `type(text)` and `reposition(false)` are
  accepted; `type(binary)` and `reposition(true)` are refused with a
  permission error, as there is no byte input and no seeking. Anything else
  is `domain_error(stream_option, O)`. Seven tests, one changed; the suite is
  at 284. (`22b12d0`)

### Changed

- **A `-g` goal that fails ends the run with status 1,** and the goals after
  it do not run, as for an error. It printed a warning, carried on, and exited
  0, so `make examples` and `make tutorials`, which CI runs, could not fail on
  a goal that failed. `make test` now checks the exit status. (`67b3a74`)

- **Reading past the end of a stream is an error by default.** A read that
  answers `end_of_file` moves the stream past its end, and the next read,
  character or term, raises `permission_error(input, past_end_of_stream, S)`.
  Every stream used to answer `end_of_file` forever, which is now
  `eof_action(eof_code)`. `peek_char` at the end leaves the stream at it, not
  past it. `user_input` resets, so a terminal can be read again after ^D.
  (`22b12d0`)

- **CI runs on `ubuntu-24.04`, not `ubuntu-latest`.** `ubuntu-latest` becomes
  Ubuntu 26 on 2026-10-19. Pinned, a new compiler arrives as a change to the
  workflow rather than as a failing run. The Linux jobs are now named
  `ubuntu-24.04 / clang` and `ubuntu-24.04 / gcc`. (`c11e760`)

### Fixed

- **A file loads its neighbours from beside itself.** A relative path in a file
  being loaded was resolved against the directory the interpreter was started
  in, so a program split into files ran only from there. It is looked for
  beside the loading file first, as SWI-Prolog does, and then where it was
  before, so old paths still work; the grammar checker now runs from anywhere.
  A file that loads itself stops with `resource_error(load_depth)`. (`3187426`)

- **`format/2` errors and resource errors print as messages,** such as
  `ERROR: format/2: not enough arguments`, where they printed as "Unhandled
  exception" and the raw term. (`3187426`)

- **Retracted clauses are freed once no choice point can reach them.** They
  were held until the predicate was abolished, so a counter retracted and
  reasserted a million times held a million clauses, 3.6 GB at peak; it holds
  one now, at 43 MB. `statistics(retained_clauses, N)` says how many are held.
  (`d936ad0`)

- **`abolish/1` no longer frees clauses a goal is still backtracking through.**
  Backtracking into a predicate abolished under it read freed memory and could
  crash; the goal now finds no more clauses. (`d936ad0`)

- **A variable where a goal stands is `call/1` of it,** as ISO has it. A cut
  bound to one cut the whole clause: `p :- G = !, G, fail.` never reached
  `p`'s next clause. It is local now, and `clause/2` shows such a body as
  `call(G)`. (`a1336d2`)

- **The reader raises `representation_error(max_arity)`.** A compound of more
  than 256 arguments was a syntax error from the reader, while `=../2` and
  `functor/3` raised the representation error ISO asks for. The parser now has
  a second way out; the error's context is `file(Name, Line)`, and the error
  printer shows it, so `consult` still says where. (`e8a75ca`)

- **A list literal may be any length.** The same "too many arguments" stopped
  any list of more than 4096 elements, from a fixed array in the reader that
  nothing documented. Lists are now built a cell at a time. (`e8a75ca`)

- **`term_variables/2` finds every variable.** It stopped at 4096 without
  saying so, and `bagof/3` and `setof/3`, which use it, inherited the cut-off;
  `read_term`'s `variables(L)` stopped at 1024. A list of a million variables
  crashed the interpreter. (`d156849`)

- **`ground/1`, `numbervars/3`, `unify_with_occurs_check/2` and `=@=` survive
  long lists.** Each recursed down list tails and died with SIGSEGV on a list
  of a million elements. They now loop on the last argument, as `unify`
  already did. (`4006577`)

- **`=@=` tells apart more than 1024 variables.** Past that it answered false,
  so a term of 2000 variables was not a variant of its own copy. (`4006577`)

- **Copying is linear in the number of variables.** The variable map under
  `copy_term`, `findall`, `assert` and every thrown ball scanned every
  variable before the one it looked up: a million variables took about five
  minutes to copy, and now take a tenth of a second. (`4006577`)

- **`read/2` and `read_term/3` refuse an output stream,** with
  `permission_error(input, stream, S)` as the character predicates do. They
  answered `end_of_file`. (`63dccdb`)

- **The prompt and `read/1` share one reader.** The prompt read standard input
  through a reader of its own, so a character pushed back by `peek_char` was
  missing from the next query and turned up in a later `get_char`.
  (`a16c715`)

- **A comment straight after a full stop is kept.** The reader consumed the
  `%` of `a.% note` as the full stop's layout, and read the comment's text as
  the next clause: a consulted file lost the clause after it. (`fcb9128`)

- **Terms nested deep in any argument no longer crash.** Every walk recursed
  on all arguments but the last, so `1+1+...+1` at 100,000 levels died with
  SIGSEGV in the collector, and the reader gave out at 5000 levels of
  brackets, arguments, lists or prefix operators. The collector, unification,
  comparison, copying, the builtins' walks, the writer, the evaluator and the
  parser now keep their pending work on stacks of their own, and a million
  levels cost a fraction of a second. Writer output, arithmetic errors and
  every clause read from the repository are unchanged against the old binary;
  queens and sort run as before and zebra 7% faster. (`d1e3088`)

- **`atomic_list_concat` joins in one pass.** It made a new atom at every
  step and atoms are never freed, so a million parts ran the machine out of
  memory. (`678e501`) Its test now joins 50,000 parts, not 200,000: run bare
  with the collector in every fourth inference, building the larger list took
  46 seconds.

- **`atomic_list_concat` splits in one pass,** where it interned every
  remainder and was quadratic: 20,000 parts took 5 seconds and now take 0.01.
  A number or a code list as the separator never matched; both are taken as
  text now, as joining takes them, so `atomic_list_concat(L, 1, a1b)` gives
  `[a, b]`. (`8a5b8a3`)

- **Reading a clause is linear in its distinct variables.** Each variable was
  found by scanning every one before it in the clause: 40,000 took 0.26
  seconds and each doubling quadrupled it. A hash on the name makes it 0.02,
  and a million 0.40; bindings and singletons come back in the same order.
  (`cabc0a0`)

- **The front page and the internals page said what was no longer so.** The
  front page described the suite's second leg as the collector "forced every
  1024 inferences", which had never collected, and gave 6,600 lines of C and
  277 tests; it is about 7,500 and 299. Eleven of the internals page's twelve
  line counts had drifted, and "the whole solver is one 606-line file" was 649.
  Re-synced at the day's closeout, and again at the second closeout, when
  eight of the twelve line counts and the front page's 7,500 had moved again.

### Tests

- 277 → 330. Seven for `open/4` and the end of stream, one changed; twelve for
  the fixes above. Nine were seen failing against the code before their fix;
  `tm_reader_list_tail` and `tm_variant_pairs` pass on both, and guard the
  code that was rewritten. `at_join_many` was not run against the old join,
  which took 0.7 seconds at a tenth of its size and grows with the square.
  Three for the split: `at_split_undoes_join` fails on the old code, and
  `at_split` and `at_split_many` pass on it, slowly in the second case. One
  for the reader's variables, `tm_reader_many_vars`, which passes on the old
  code in 0.43 seconds against 0.06. One for the dialect flag, eleven for
  lambdas, seven for error context and the variable goal, six of which fail on
  the old code, six for retracted clauses, one of which fails and one crashes
  on the old code, and five for `char_type/2` and loading from beside a file,
  all of which fail on it. `make test` also checks two printed messages.
- `tests/deep.pl`, 22 checks outside the suite. Against the code before
  `d1e3088` it dies with SIGSEGV.
- The suite's second leg, `make test-gc`, turns out never to have collected
  anything before today; every earlier count of "both legs" was one leg run
  twice. It now runs the same 296 tests bare, each collected while it runs.

## 2026-09-25

### Added

- **The character predicates.** `get_char/1,2`, `peek_char/1,2`,
  `at_end_of_stream/0,1` and `put_char/2`. Characters are read as UTF-8 and
  come back as one-character atoms, or `end_of_file` at the end and on every
  call after it, as `read/1` does. Characters and terms can be read
  alternately from one stream: both go through the stream's one reader and its
  pushback. The unused one-character slot the roadmap counted on for
  `peek_char` was removed instead of used, because a character held there would
  have been invisible to `read/1`. Reading from an output stream, or writing to
  an input one, is a `permission_error`. Six tests; the suite is at 275. (`0a37c7c`)

- **`read_term/2,3` reports singletons.** `singletons(L)` gave `[]` whatever
  was read; it now lists `Name = Var` for every named variable that occurs
  exactly once, in the order read. Names starting with an underscore count,
  as ISO has it; only the anonymous `_` does not. Two tests; the suite is at
  277. (`c7bfa74`)

### Changed

- **`put_char/1` takes exactly one character.** It wrote any atom it was given;
  `put_char(ab)` is now `type_error(character, ab)`, as ISO has it. (`0a37c7c`)

## 2026-09-12

### Added

- **The suite refuses to start while a test of the wrong arity exists.**
  `run_tests` collects every arity of `test` other than 2 and, if there is one,
  prints `test/3 exists: a test body with more than one goal needs parentheses`
  and exits 1. A test written without the parentheses now fails the suite
  instead of vanishing from it. (`9e6ea98`)

### Changed

- **Heap allocations are rounded to 8 bytes, not 16.** Eight is the alignment
  of the widest member of the term union on every platform this targets, so a
  24-byte cell occupies 24 where it occupied 32, and a list cell 40 where it
  occupied 48. Measured with the collector held off: a 200,000-element
  `numlist` allocates 93 MB instead of 115 MB, and 90,000 `X-Y` pairs 12 MB
  instead of 16 MB. A fifth off, not the quarter the roadmap estimated, because
  argument vectors were already multiples of 8. Speed unchanged: naive reverse
  at 24.7M inferences ran 1.71–1.74 s before and 1.72–1.76 s after. The
  sanitizer leg is the check that would have caught a member needing more.
  (`f3d7102`)

### Fixed

- **Thirteen tests had never run.** In the arithmetic section of
  `tests/test.pl`, thirteen tests were written as `test(name, G1, G2)` with no
  parentheses around the conjunction, so they consulted as `test/3` and `test/4`
  facts and the harness's `forall(test(Name, Goal), ...)` never reached them.
  The suite reported 256 from the first commit while the file held 269. All
  thirteen pass; they are `test/2` now, and every count that quoted 256 says
  269. (`af41122`)

### Tests

- 256 → 269. No test was added: the thirteen were there all along.

## 2026-08-28

### Added

- **Level 3 of the tutorial** — negation, the cut, terms and operators of your
  own, and the grammar notation. Ships `tutorial/level3.pl`. The figure draws
  the cut as what the engine implements: a choice point stack height, with the
  caller's entry surviving. (`afbc1cb`)
- **Level 4 of the tutorial** — exceptions, the database, and input and output,
  taking the Level 3 stock room and turning it into a program. Ships
  `tutorial/level4.pl`, `tutorial/orders.txt` and `tutorial/restock.pl`, the
  last of these a complete script driven by `initialization/1`. (`78d43c4`)
- **`make tutorials`** — loads each tutorial program and runs a query out of its
  page, so the published pages cannot drift away from the code they quote.
  Run by CI alongside `make examples`. (`78d43c4`)
- **The journal and the postmortem are published pages.** `journal.html` and
  `postmortem.html` join the site, reached from the document switcher and two
  new cards on the front page. They are rendered from `JOURNAL.md` and
  `POSTMORTEM.md` by `tools/mdpage.py`, which raises on any Markdown outside
  the subset it knows rather than dropping it, and CI's docs job keeps the
  pages and the Markdown in step. Links between the documents are rewritten
  to the pages and labelled by title, not file name. Recorded on 2026-09-27;
  the journal's day four had left it as a question. (`5658209`)

### Fixed

- **`max_arity` was three different numbers.** `current_prolog_flag(max_arity, V)`
  answered `unbounded`, `=../2` stopped at 255, the reader at 256, and
  `functor/3` at nothing at all — `functor(T, f, 100000)` built the term, and a
  large enough arity would have overflowed the `int` the arity is stored in.
  `MAX_ARITY` in `src/prolog.h` is now the single definition, set to 256; the
  reader, `=../2` and `functor/3` all use it, and the flag reports the integer
  as ISO asks. Six tests, written against the flag rather than a literal.
  (`8831038`)
- **The exercise disclosure marker rendered as `B8?A0Solutions`.** The shared
  CSS was a plain Python string, so the escape `\25B8` was read as an octal
  escape before the browser ever saw it. The block is a raw string now. This
  was on every published page. (`afbc1cb`)
- **Long note titles overlapped their own body text.** `.note-tag` was `nowrap`
  at a fixed width. It wraps now, and the stacked mobile layout puts the flex
  basis back to `auto` so the basis does not become a height. (`afbc1cb`)
- **`*emphasis*` reached six pages as literal asterisks.** The shared `inline()`
  handled `**bold**` and nothing else. Bold is substituted first, and emphasis
  requires non-space on both sides so a multiplication sign written in prose is
  left alone. (`afbc1cb`)
- A section of Level 3 said three predicates where its table listed four.
  (`ded50bd`)
- The front page gave the line count as 5,300, as it had since the first
  commit, where it was about 6,600, and the test count twice as 248.
  (`5658209`)

### Documentation

- The reference records three things it had not: there is **no logical update
  view** (a goal backtracking through a predicate sees clauses asserted after it
  started and skips ones retracted ahead of it); there is no
  `setup_call_cleanup/3`; and `dynamic/1` is a predicate rather than a prefix
  operator, so `:- dynamic foo/1.` is a syntax error here. (`78d43c4`)
- The `max_arity` story is now told consistently in the flags table, the error
  table and *Deviations and limits*, including that the reader reports the limit
  as a syntax error while `=../2` and `functor/3` raise
  `representation_error(max_arity)`. (`8831038`)
- `tutorial/level3.pl` says in the file that `max_of/3` is wrong on purpose, for
  anyone reading it without the page. (`a67b322`)

### Tests

- 250 → 256.

## 2026-08-19

### Added

- **The interpreter.** A structure-copying engine with an iterative solver: the
  continuation is an explicit list of goal frames, alternatives live on a choice
  point stack, and cut is the stack height recorded in each frame, so deep
  Prolog recursion costs heap rather than C stack. Memory is a chunked heap that
  choice points mark and backtracking rewinds, arenas for clauses and exception
  balls, and a copying collector for what backtracking cannot reclaim. With a
  full operator-precedence reader and writer, arithmetic, exceptions, grammars,
  streams, `format/1,2,3`, first-argument indexing, 162 builtin predicates, five
  example programs and a 248-test suite. (`e31b881`)
- **The project site** — `docs/` served by GitHub Pages: a front page, the
  language reference and the engine internals, generated from `tools/` and
  sharing one design system. Plus `ROADMAP.md`. (`c17f96a`, `42b5eb5`)
- **CI** — Linux and macOS, clang and gcc, warnings as errors. Each leg runs the
  suite twice (normally, and with the collector forced every 1024 inferences),
  then the examples, then the whole thing again under the address and undefined
  behaviour sanitizers. A second job regenerates `docs/` and fails if anything
  changed. This closed the roadmap's first item. (`09fcdcf`)
- **Levels 1 and 2 of the tutorial** — facts, rules and the search; then lists
  and collecting answers. (`b25bf4f`, `a47faab`)

### Fixed

Everything below was found by CI on its first run, and none of it reproduced on
the machine the interpreter was written on. See
[POSTMORTEM.md](POSTMORTEM.md).

- **`strdup` is POSIX, not C99.** Under `-std=c99` glibc does not declare it, so
  on Linux the call compiled as an implicit declaration returning `int` and the
  pointer was truncated before being stored — corrupting the stream name in
  `open/3` and the text buffer that `atom_length/2`, `atom_codes/2` and
  `format/2` use for numbers. `pl_strdup` is a four-line C99 equivalent.
  (`c486ab3`)
- **gcc's `-Wmaybe-uninitialized` fired seventeen times**, all on the same
  shape: a local passed by address to one of four accessors that gcc cannot
  prove is written on the success path. The accessors now write their outputs
  before doing anything else, which is both what callers assume and what gcc
  needed to see. Also unwraps one statement `-Wmisleading-indentation` objected
  to, reasonably. (`8fbcf05`)
- **`X is -1 << 2` was undefined behaviour.** It produced the expected `-4` on
  both compilers, but the sanitizer build now aborts on undefined behaviour
  rather than printing and continuing, so it would have failed the moment any
  program exercised it. Doing the shift unsigned gives the same two's complement
  answer with defined behaviour. Two tests cover it. (`f81293b`)

### Tests

- 248 → 250.
