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
```

It runs from any directory, since `check.pl` loads the other files from beside
itself. `make english` runs the checks in `tests.pl`.

This is stage 1 of the three set out in [the roadmap](../docs/ROADMAP.md): a
small lexicon, simple declarative sentences, and agreement carried in the
rules.

## The files

| | |
|---|---|
| `lexicon.pl` | 262 words: 91 nouns, 48 verbs, 43 adjectives, 16 adverbs, 15 prepositions, 25 determiners, 12 names, 12 pronouns. Plurals and verb forms are derived by rule, with the irregular ones listed, 326 noun and verb forms in all. |
| `grammar.pl` | The rules: sentences, noun phrases (with determiners, adjectives, prepositional phrases and `and`), verb phrases (intransitive, transitive, ditransitive, and `be` with an adjective, noun phrase or place), adverbs. |
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

It says nothing about meaning. *Colorless green ideas sleep furiously* is
grammatical here, as it is in English.

## How it works

Agreement is **unification alone**. A subject and its verb meet in one feature
term, `agr(First, Third, SingularNotSecond)`: a subject binds all three slots, a
verb form only the ones it cares about, so *chases* is `agr(_,y,_)` and *were*
is `agr(_,_,n)`. Every agreement in English, the forms of *be* among them, is
then one unification, and the lexicon's opening comment has the table.

The diagnosis uses **the same grammar**. Each agreement point goes through
`agree/5`, which threads a list of violations beside the words. Parsed with the
list closed, a violation cannot be recorded, and the grammar is strict; parsed
with it open, it finds the reading with the fewest violations and names them.

Recursion is **on the right**. A noun phrase is followed by its prepositional
phrases rather than built from a smaller noun phrase, since a left-recursive
rule such as `np --> np, pp` makes a DCG loop. That is the wall stage 2 will
meet.
