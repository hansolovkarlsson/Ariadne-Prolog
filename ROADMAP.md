# Roadmap

Known work, roughly in the order it would pay off. Everything under the first
three headings is a consequence of decisions described in the
[engine internals](https://hansolovkarlsson.github.io/cprolog/internals.html)
document; nothing is speculative. *Built on the interpreter* holds programs
written in Prolog that live in this repository and run on it.

Finished work moves to [CHANGELOG.md](CHANGELOG.md). [POSTMORTEM.md](POSTMORTEM.md)
covers the defects the project has found in itself, including the ones that
produced some of the entries below.

## Near term

- **Splitting an atom is quadratic.** `atomic_list_concat/3` in split mode
  interns every remainder on the way, as joining did until 2026-09-27; a
  builtin as for `'$join'` would make it linear.

## Medium term

- **Reclaiming retracted clauses.** A retracted clause is held until its
  predicate is abolished, because a choice point may still point at it. A
  reference count or a generation stamp would let the common case be freed.

- **Lambdas.** There is no `yall`, so `maplist([X]>>Goal, L)` does not work and
  every partial application needs a named helper. A small `>>` implementation
  would remove a papercut that shows up constantly in list code.

- **Error context.** The second argument of `error/2` is an unbound variable,
  except where the reader gives `file(Name, Line)`. Filling in the predicate
  indicator where the error was raised would make messages considerably more
  useful.

## Structural

These change the shape of the system rather than adding to it.

- **Collecting while choice points are live.** The collector only runs when the
  choice point stack is empty, because heap marks depend on allocation order
  that a copying collector destroys. Doing better means mark-and-slide
  compaction over a cell heap with object headers — at which point the design
  is most of a WAM. This is the single biggest limitation.

- **Unbounded integers.** Integers are 64-bit and overflow raises
  `evaluation_error(int_overflow)`. Bignums would need an allocation strategy
  for numbers that outlive backtracking.

- **Modules.** The predicate table is flat, so every program shares one
  namespace.

- **Tabling and constraints.** Both are large, self-contained projects that the
  current solver has no hooks for.

## Built on the interpreter

- **An English grammar checker, written as DCGs, in `english/`.** A lexicon
  that records each word's parts of speech and features, a grammar of `-->`
  rules, and `phrase/2` as the parser: a sentence is grammatical when a parse
  exists. Nothing in the interpreter breaks without it. What it buys is the
  first program here that leans on DCG translation and `phrase/2,3` as hard as
  their intended use does; today only the suite and tutorial level 3 touch
  them. Decided 2026-09-25 and **not started**; the journal's day five has the
  reasoning. Three stages, each worth stopping at:

  1. A few hundred words, simple declarative sentences, and agreement carried
     as a rule argument (`sentence --> noun_phrase(N), verb_phrase(N).`), so
     that "the dogs chases" and "a dogs" are rejected by unification alone.
     A weekend to two weeks.
  2. What each verb takes after it, questions, negation, passives and relative
     clauses, and morphology rules for words missing from the lexicon. Months,
     part-time.
  3. A lexicon generated from WordNet or Wiktionary, and a record of what
     breaks. Broad coverage of real text is out of scope: rule-based grammars
     that aim for it have taken decades.

  The known wall is left recursion: a rule such as `NP -> NP PP` makes a plain
  DCG loop, and shared sub-parses are redone on every backtrack. Stage 1 avoids
  it by writing such rules right-recursively. Past that, the answer is
  *Tabling* under *Structural*, which gives this entry a case for that one.

## Not planned

- **Competing on raw speed.** Calling a predicate copies its clause, which is
  what a compiling system avoids; that costs a factor of a few against SWI and
  is the price of an engine small enough to read in an afternoon.
- **A distinct string type.** Double-quoted text follows the `double_quotes`
  flag, as in ISO.
