# Roadmap

Known work, roughly in the order it would pay off. Everything under the first
three headings is a consequence of decisions described in the
[engine internals](https://hansolovkarlsson.github.io/Ariadne-Prolog/internals.html)
document; nothing is speculative. *Built on the interpreter* holds programs
written in Prolog that live in this repository and run on it.

Finished work moves to [CHANGELOG.md](CHANGELOG.md). [POSTMORTEM.md](POSTMORTEM.md)
covers the defects the project has found in itself, including the ones that
produced some of the entries below.

## Near term

## Medium term

- **Revise and extend the tutorials.** The four levels in `tutorial/`, and
  the pages generated from them, were written early, before much of today's
  library and error reporting existed. Check each against the interpreter
  as it is now, fix what has drifted, and add material where the levels
  leave gaps. Deferred on 2026-09-28: not before grammar stage 2 is under
  way.

- **More examples, covering the whole language.** `examples/` has five
  programs: hanoi, queens, zebra, calc and family. Add enough that every
  part of the language has a small, runnable example. That means
  arithmetic, lists, cut and negation, `findall/3` and its kin, assert and
  retract, exceptions, DCGs, streams and files, `format/2`, lambdas and
  `char_type/2`. Each one gets a line in `make examples`. Deferred on
  2026-09-28, like the tutorials.

- **Document the source for readers learning from it.** The project began
  as a teaching interpreter, so the code should explain itself. Each file in
  `src/`, `lib/boot.pl` and `english/` gets a header saying what it is for,
  what it holds, and how it fits with the other files. Today most C files
  open with one line. Each function, and each Prolog predicate in the
  library, gets a comment saying what it does and how it works. The
  internals page covers the design as a whole, and these comments should
  point to it rather than repeat it. Deferred on 2026-09-28, like the
  tutorials.

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
  2. **Done on 2026-09-29**, in [the changelog](CHANGELOG.md), two days
     after stage 1 against an estimate of months: auxiliaries, negation,
     yes/no and *wh*-questions, passives, relative clauses, a guess at a
     word missing from the lexicon from its ending, contractions and
     possessives. What it leaves out, each a small piece of its own:
     - *who* against *which*, which needs every noun marked as a person or
       a thing;
     - a preposition before its relative word, *the park in which the dog
       walks*;
     - a possessor with a prepositional phrase, *the king of France's dog*.
  3. **Done on 2026-09-29**, in [the changelog](CHANGELOG.md): WordNet 3.1's
     words, generated at build time by `make wordnet`, and a record of what
     they break in [english/README.md](../english/README.md), from fifty
     ordinary sentences of which 28 passed. Broad coverage of real text is
     out of scope: rule-based grammars that aim for it have taken decades.
     Everything the record found was done the same day, and all fifty
     sentences now pass. A second corpus, fifty sentences from Simple
     English Wikipedia that the grammar was not built against, passes none:
     19 are rejected and 31 have a word it does not know. Its record, by
     cause, is in the same README. Names, its largest cause, were done
     the same day, then lists with *and* and *or* and the commas they
     need, a number after a name, nouns before nouns, and on 2026-09-30
     mass nouns, a phrase before the subject, a rough number, *a kind of*
     and adverbs after *be*, dates, and brackets set aside; it passes 18.
     On 2026-10-01 a name at the start of a sentence that WordNet has
     only in lowercase, *Woods was born*, *Sedan is a commune*, and a comma
     between a name and the name that places it, *Springfield,
     Massachusetts*, hyphenated words, *Bernes-sur-Oise*, *north-eastern*,
     an adjective before a name, *north-eastern France*, comparatives,
     superlatives and ordinals in digits, *largest*, *27th*, and a gerund
     after a preposition, *the record for being the largest cluster*, and
     what lists left, verb phrases joined, *either ... or*, and a list
     whose first item has two nouns under one determiner; it passes
     30. On 2026-10-02 an appositive after a name, *Alice, a doctor,
     sleeps*, and the bare role noun it needs, *He was chairman of the
     Health Service Executive*, and a participle before a noun, *the
     presiding bishop*, *managing director*; it passes 33. What is left:
     - a request without a verb, *two cups of tea, please*, which the
       first corpus now refuses; an adjective after a noun modifier,
       *jazz bebop alto saxophonist*; a number before the noun, *the 2020
       census*, *the 2017 World Aquatics Championships*;
     - a participle after a noun, *a movie directed by*, *a network
       broadcasting from Dubai*: written on 2026-09-30 with the
       participle before a noun and held behind the parser, below. The
       pair were correct, 417 checks passing, but the corpus run went
       from 172 to 397 seconds of CPU for no corpus sentence gained, and
       to 366 even with them kept out of the diagnosis. On 2026-10-02 the
       half before the noun went in on its own, *the presiding bishop*,
       *managing director*, at 197 seconds against 184 once two costs
       outside it were found, in `english/README.md`; the half after the
       noun opens a verb phrase after every noun and is still the
       parser's. Its rules are in `scratch/participles.patch` on the
       machine it was written on, and are short to write again.

  The known wall is left recursion: a rule such as `NP -> NP PP` makes a plain
  DCG loop, and shared sub-parses are redone on every backtrack. Stage 1 avoids
  it by writing such rules right-recursively, and stage 2 needed none either:
  the auxiliary chain, relative clauses and possessives all read left to
  right. Past that, there are two answers: a chart or left-corner parser
  written in Prolog, which is days, or *Tabling* under *Structural*, which is
  months. Which one is a decision for the first rule that cannot be written
  on the right, taken from what it costs then. The second corpus brought the
  other half of the wall first: one sentence of 23 words takes 116 seconds,
  since every word WordNet lists as a noun, a verb and an adjective at once
  multiplies the sub-parses that are redone. Speed may force the decision
  before left recursion does. Participles were the first feature whose
  cost the parser could not absorb: each noun opens a whole verb phrase,
  and the corpus's two slowest sentences went from 36 seconds and under
  12 to 117 and 328.

## Not planned

- **Competing on raw speed.** Calling a predicate copies its clause, which is
  what a compiling system avoids; that costs a factor of a few against SWI and
  is the price of an engine small enough to read in an afternoon.
- **A distinct string type.** Double-quoted text follows the `double_quotes`
  flag, as in ISO.
