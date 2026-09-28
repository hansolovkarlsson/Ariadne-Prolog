# english/

An English grammar checker, written in Prolog as a definite clause grammar and
run on this interpreter. It says whether a sentence is grammatical and, when it
is not, which words disagree:

```
$ bin/prolog -q english/check.pl -g "check('The dogs chase a cat.'), halt"
grammatical: [S [NP the dogs] [VP chase [NP a cat]]]
$ bin/prolog -q english/check.pl -g "check('The dogs chases a cat.'), halt"
not grammatical: the verb 'chases' does not agree with its subject
$ bin/prolog -q english/check.pl -g "check('A apple is red.'), halt"
not grammatical: 'a apple' should be 'an apple'
$ bin/prolog -q english/check.pl -g "check('The old man walks in the park with his dog.'), halt"
grammatical, 2 readings:
  [S [NP the old man] [VP walks [PP in [NP the park [PP with [NP his dog]]]]]]
  [S [NP the old man] [VP walks [PP in [NP the park]] [PP with [NP his dog]]]]
$ bin/prolog -q english/check.pl -g "check('Was the cat chased by the dog?'), halt"
grammatical: [SQ was [NP the cat] [VP chased [PP by [NP the dog]]]]
$ bin/prolog -q english/check.pl -g "check('The dog has ate the cake.'), halt"
not grammatical: after 'has' the verb should be 'eaten', not 'ate'
$ bin/prolog -q english/check.pl -g "check('The dog barks not.'), halt"
not grammatical: 'barks not' should be 'does not bark'
```

It runs from any directory, since `check.pl` loads the other files from beside
itself. `make english` runs the checks in `tests.pl`.

Stage 1 of the three set out in [the roadmap](../docs/ROADMAP.md) is done: a
small lexicon, simple declarative sentences, and agreement carried in the
rules. Stage 2 is under way. Auxiliaries, negation, yes/no questions and
passives are in; relative clauses, *wh*-questions and guessing at unknown
words are not yet.

## The files

| | |
|---|---|
| `lexicon.pl` | 272 words: 91 nouns, 49 verbs, 43 adjectives, 16 adverbs, 15 prepositions, 25 determiners, 12 names, 12 pronouns, 9 modals; the forms of *be*, *have* and *do*; and 17 contractions with *n't*. Plurals and verb forms (*-s*, past, *-ing*, participle) are derived by rule, with the irregular ones listed, 386 noun and verb forms in all. |
| `grammar.pl` | The rules: statements and yes/no questions, noun phrases (with determiners, adjectives, prepositional phrases and `and`), verb phrases (a chain of auxiliaries, then a verb that is intransitive, transitive or ditransitive, or `be` with an adjective, noun phrase or place), negation, passives, adverbs. |
| `check.pl` | Text into words, the verdict, the explanation, and the bracketed trees. |
| `tests.pl` | Sentences that must pass, sentences that must fail with a named reason, and the number of readings of an ambiguous one. |

## What it checks

- **Subject and verb**: *the dogs chase*, *the dog chases*, *I am*, *you are*,
  *they were*; and a subject joined by *and* is plural.
- **Determiner and noun**: *a dog*, *these dogs*, not *a dogs* or *this dogs*.
- **A and an**, by the sound of the next word rather than its spelling: *an
  hour*, *a university*, *an old man*.
- **Pronoun case**: *she sees him*, not *him sleeps* or *she sees he*.
- **A singular noun needs a determiner**: *dogs bark*, not *dog barks*.
- **What a verb takes**: *gives* two objects, *sleeps* none.
- **The form after an auxiliary**: *can bark*, *has eaten*, *is sleeping*,
  *was chased*, not *can barks* or *has ate*.
- **The order of auxiliaries**: *might have been chased*, not *is having
  eaten* or *can can swim*.
- **Negation and questions need an auxiliary**: *does not bark* and *does
  the dog bark*, not *barks not* or *barks the dog*. *Be* needs none: *is
  not happy*, *is the dog happy*.
- **Passives** lose an object to the subject: *the cat was chased*, *the dog
  was given a bone*, not *the dog was slept*.

It says nothing about meaning. *Colorless green ideas sleep furiously* is
grammatical here, as it is in English.

## How it works

Agreement is **unification alone**. A subject and its verb meet in one feature
term, `agr(First, Third, SingularNotSecond)`: a subject binds all three slots, a
verb form only the ones it cares about, so *chases* is `agr(_,y,_)` and *were*
is `agr(_,_,n)`. Every agreement in English, the forms of *be* among them, is
then one unification, and the lexicon's opening comment has the table.

A verb phrase is **a chain of auxiliaries, then the verb**. Each word in the
chain says what form the next must have (a modal or *do* the base, *have*
the participle, *be* the *-ing* form or, for a passive, the participle) and
has a rank, and only a word ranked above it may follow: modal, perfect,
progressive, passive, verb. So English's one order comes out of a number
compared at each step. Negation goes after the first word of the chain, and
a yes/no question moves that word before the subject and parses the rest of
the chain as the statement would. A passive is the verb with its first
object taken away, since that object is now the subject.

The diagnosis uses **the same grammar**. Each agreement point goes through
`agree/5`, which threads a list of violations beside the words. Parsed with the
list closed, a violation cannot be recorded, and the grammar is strict; parsed
with it open, it finds the reading with the fewest violations and names them.

Recursion is **on the right**. A noun phrase is followed by its prepositional
phrases rather than built from a smaller noun phrase, since a left-recursive
rule such as `np --> np, pp` makes a DCG loop. Nothing in stage 2 so far has
needed one. That is the wall relative clauses may meet.
