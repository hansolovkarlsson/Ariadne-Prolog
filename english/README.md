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
$ bin/prolog -q english/check.pl -g "check('The cat that the dog chased sleeps.'), halt"
grammatical: [S [NP the cat [SBAR that [S [NP the dog] [VP chased _]]]] [VP sleeps]]
$ bin/prolog -q english/check.pl -g "check('What did the dog chase?'), halt"
grammatical: [SBARQ [WHNP what] [SQ did [NP the dog] [VP chase _]]]
$ bin/prolog -q english/check.pl -g "check('The dogs that chases the cat bark.'), halt"
not grammatical: the verb 'chases' does not agree with its subject
```

The `_` marks the gap: the place the noun phrase is missing from, which the
relative or question word stands for. A word the lexicon does not list is
placed by its ending when it has one:

```
$ bin/prolog -q english/check.pl -g "check('The zorbles blorfed the cat.'), halt"
grammatical: [S [NP the zorbles] [VP blorfed [NP the cat]]]
  (not in the lexicon: 'blorfed' taken to be a verb, from its ending)
  (not in the lexicon: 'zorbles' taken to be a noun or a verb, from its ending)
```

Contractions are cut from their word and read as the words they stand for,
and a possessive stands where a determiner would:

```
$ bin/prolog -q english/check.pl -g "check('Alice''s friend''s dog''s sleeping.'), halt"
grammatical: [S [NP [NP [NP alice] 's friend] 's dog] [VP 's [VP sleeping]]]
$ bin/prolog -q english/check.pl -g "check('They''s sleeping.'), halt"
not grammatical: the verb 's (is or has) does not agree with its subject
```

It runs from any directory, since `check.pl` loads the other files from beside
itself. `make english` runs the checks in `tests.pl`.

All three stages set out in [the roadmap](../docs/ROADMAP.md) are done. Stage 1
is a small lexicon, simple declarative sentences, and agreement carried in the
rules. Stage 2 is auxiliaries, negation, yes/no and *wh*-questions, passives,
relative clauses, a guess at unknown words, contractions and possessives.
Stage 3 is WordNet's 85,000 words, and a record of what they break, at the
end of this file.

## The files

| | |
|---|---|
| `lexicon.pl` | 283 words: 91 nouns, 49 verbs, 43 adjectives, 18 adverbs, 16 prepositions, 25 determiners, 12 names, 12 pronouns, 9 modals, 8 question and relative words (*that* is counted as a determiner); the forms of *be*, *have* and *do*; 17 contractions with *n't* and 6 others, *'s*, *'re*, *'m*, *'ve*, *'ll* and *'d*. Plurals and verb forms (*-s*, past, *-ing*, participle) are derived by rule, with the irregular ones listed, 386 noun and verb forms in all. |
| `grammar.pl` | The rules: statements, yes/no and *wh*-questions, noun phrases (with determiners, possessives, adjectives, prepositional phrases, relative clauses and `and`), verb phrases (a chain of auxiliaries, then a verb that is intransitive, transitive or ditransitive, or `be` with an adjective, noun phrase or place), negation, passives, adverbs. |
| `guess.pl` | A word the lexicon lacks, looked up in WordNet when it is loaded, or else guessed from its ending: *-ly* an adverb, *-tion* a noun, *-ful* an adjective, *-ize* a verb, and *-s*, *-ed* and *-ing* taken back to a stem that is placed the same way. |
| `check.pl` | Text into words, with contractions cut off; the verdict, the explanation, and the bracketed trees. |
| `wordnet_check.pl` | `check.pl` with WordNet's words loaded, from `wordnet.pl`, which `make wordnet` generates and git ignores. |
| `corpus.txt`, `corpus.pl` | Fifty ordinary sentences, and the run over them that `make english-wordnet` does, which fails unless the counts are the ones `corpus.pl` records. |
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
- **Contractions agree as their words do**: *they're*, not *they's*; and
  *'s* after a noun is *is*, *has* or the possessive, whichever fits: *the
  dog's sleeping*, *the dog's eaten*, *the dog's bone*.
- **Relative clauses and *wh*-questions have exactly one gap**: *the cat that
  the dog chased*, *what did the dog chase*, not *the cat that the dog chased
  the mouse*. The verb of a relative clause with no subject agrees with the
  noun: *the dogs that chase*, not *the dogs that chases*. *Whom* stands only
  for an object: *whom did Alice see*, not *whom chased the cat*.

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

A relative clause or a *wh*-question has **a gap**, threaded through the rules
beside the violations: it is waiting to be placed until a noun phrase takes
it, and a clause that must have one parses only if it was placed exactly
once. It may be an object, or a preposition's object (*the park that the dog
walks in*). A missing subject needs no gap at all, since what follows the
relative or question word is then a verb phrase, which agrees with the noun
it stands for as it would with a subject. English allows no gap inside a
subject or one half of an *and*, and the rules place none there.

A **possessive** is a determiner made of a noun phrase and *'s*: *Alice's
dog*. A possessor may itself be possessed, *Alice's friend's dog*, which
would be a rule calling itself on the left if written as English grammars
usually write it. Here it is a chain read left to right instead, each link a
noun and its *'s*.

A word missing from the lexicon is **placed by its ending**. An inflected word
is taken back to its stem by undoing the lexicon's own spelling rules (so
*blorfed* is *blorf*, *carried* is *carry*), keeping only the stems that the
rules turn back into the word. The stem is then placed by its own ending, or
taken as a noun or a verb if it has none. The guess joins the lexicon for one
check, so the word's other forms, and its agreement, come from the same rules
as a listed word's. A word with no ending to go on, *zorble* or a misspelt
*furiouslyy*, is reported rather than guessed, since guessing it would
accept any typo.

The diagnosis uses **the same grammar**. Each agreement point goes through
`agree/5`, which threads a list of violations beside the words. Parsed with the
list closed, a violation cannot be recorded, and the grammar is strict; parsed
with it open, it finds the reading with the fewest violations and names them.

Recursion is **on the right**. A noun phrase is followed by its prepositional
phrases rather than built from a smaller noun phrase, since a left-recursive
rule such as `np --> np, pp` makes a DCG loop. Nothing in stage 2 has needed
one either: a relative clause follows its noun, as its prepositional phrases
do.

## Stage 3: what a large lexicon breaks

`make wordnet` downloads WordNet 3.1 and `tools/gen_wordnet.py` turns it into
`english/wordnet.pl`: 55,213 nouns, 8,416 verbs with the frames WordNet gives
them, 17,870 adjectives, 3,642 adverbs, and 4,162 irregular forms. It is not
committed. A word the lexicon lacks is looked up there, as itself, as an
inflected form of a stem, or among the irregular forms (*flung*, *oxen*,
*grabbed*), before it is guessed from its ending. The lexicon's own words are
never looked up, so its entries are what they were, and `make english` runs
without WordNet and without the network. CI runs `make english-wordnet` in a
job of its own, with WordNet kept in its cache.

`make english-wordnet` runs the grammar's checks with WordNet loaded, and all
of them pass. It then checks the fifty sentences in `corpus.txt`, every one of
them ordinary English. On 2026-09-29, **28 were grammatical, 21 were not, and
one had a word in neither the lexicon nor WordNet**. The 22 failures are the
record, by cause:

**Nouns that take no article (5).** *Water boils*, *some homework*, *the
price of bread*, *two cups of tea*, *played football*. The grammar asks every
singular noun for a determiner, which is right for *dog* and wrong for
*water*, and WordNet does not say which nouns are which.

**Words WordNet does not have (6).** WordNet lists nouns, verbs, adjectives
and adverbs, not the small closed classes: *because* and *but* joining
clauses, *after* as a preposition, *six* and *hundred* as numbers, *nobody*.

**The lexicon's own entries, incomplete (3).** *Tell* is listed as taking two
objects, so *tells wonderful stories* fails; *open* takes one, so *the museum
opens on Sundays* fails; *early* is only an adjective, so *leave early*
fails. WordNet has all three right, but never overrides a word the lexicon
lists.

**Constructions the grammar does not have (11).** A noun phrase used as an
adverb (*last night*, *next door*); an adverb before the verb (*already
eaten*, *never seen*); *very* before an adjective; a verb that takes an
adjective (*tastes good*, *painting the kitchen blue*); an infinitive (*wants
to learn*); a clause after a verb (*think that she is right*); an imperative
(*please close the door*); *such a*; and a phrase with no verb (*two cups of
tea, please*). Three sentences fail for two of these reasons, so the counts add
to 25, not 22.

**What passed, and what that cost.** Eight of the 28 passes have two
readings. Six are real: a prepositional phrase that can attach to the noun or
the verb (*kicked the ball over the fence*). Two come from WordNet listing a
participle as an adjective as well (*the meeting was cancelled*: a state, or
something done), which is also real. Loading WordNet takes 0.08 seconds. It
first took 490 MB, because each clause had a 4 KB arena whatever its size,
which the interpreter now sizes to the clause (52 MB). A lookup reads all of
a predicate's clauses, as first-argument indexing here filters but does not
hash, so finding one noun among 55,000 takes 0.16 ms, which is fast enough.

**Since the record.** The three incomplete entries were completed the same
day: *tell* takes one object or two, *open* none or one, and *early* is an
adverb too, with *close* and *late*, which had the same gaps. That moved
three sentences, and the corpus now gives **31 grammatical, 18 not, and one
unknown**. `corpus.pl` records those counts and fails on any others, so a
sentence that moves, either way, is seen in CI and the record is updated
with it.
