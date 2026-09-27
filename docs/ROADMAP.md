# Roadmap

Known work, roughly in the order it would pay off. Everything under the first
three headings is a consequence of decisions described in the
[engine internals](https://hansolovkarlsson.github.io/ariadne-prolog/internals.html)
document; nothing is speculative. *Built on the interpreter* holds programs
written in Prolog that live in this repository and run on it.

Finished work moves to [CHANGELOG.md](CHANGELOG.md). [POSTMORTEM.md](POSTMORTEM.md)
covers the defects the project has found in itself, including the ones that
produced some of the entries below.

## Near term

- **`char_type/2` and `code_type/2`.** Neither exists, so a program that
  splits text into words tests letters by comparing character codes, as
  `english/check.pl` does. Found by the grammar checker on 2026-09-27; the
  common types (`alpha`, `digit`, `space`, `upper`, `lower`, `punct`) would
  cover it.

- **`consult/1` inside a file resolves paths against the current directory.**
  SWI-Prolog resolves them against the directory of the file being loaded, so
  a program split into files loads from anywhere. Here it loads only from the
  directory its paths were written for, which is why `english/check.pl` and
  `tutorial/restock.pl` must be run from the top of the repository. Found by
  the grammar checker on 2026-09-27. Trying the loading file's directory first
  and the current one second would keep both working.

## Medium term

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
  their intended use does. Decided 2026-09-25; the journal's day five has the
  reasoning. Three stages, each worth stopping at:

  1. **Done on 2026-09-27**, in [the changelog](CHANGELOG.md): 262 words,
     simple declarative sentences, agreement by unification alone, a
     diagnosis that names what disagrees, and, earlier than planned, what each
     verb takes after it, since simple sentences cannot be checked without it.
  2. Questions, negation, passives and relative clauses, and morphology rules
     for words missing from the lexicon. Months, part-time.
  3. A lexicon generated from WordNet or Wiktionary, and a record of what
     breaks. Broad coverage of real text is out of scope: rule-based grammars
     that aim for it have taken decades.

  The known wall is left recursion: a rule such as `NP -> NP PP` makes a plain
  DCG loop, and shared sub-parses are redone on every backtrack. Stage 1 avoids
  it by writing such rules right-recursively. Past that, there are two
  answers: a chart or left-corner parser written in Prolog, which is days, or
  *Tabling* under *Structural*, which is months. Which one is a decision for
  when stage 2 meets its first left-recursive rule, taken from what it costs
  then.

## Not planned

- **Competing on raw speed.** Calling a predicate copies its clause, which is
  what a compiling system avoids; that costs a factor of a few against SWI and
  is the price of an engine small enough to read in an afternoon.
- **A distinct string type.** Double-quoted text follows the `double_quotes`
  flag, as in ISO.
