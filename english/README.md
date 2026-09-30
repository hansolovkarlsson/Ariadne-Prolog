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

## Checking your own text

`check_file/1` takes a file of running text, cuts it into sentences, and
gives a line for each, then the counts. Load `wordnet_check.pl` rather than
`check.pl` for WordNet's words, after `make wordnet`:

```
$ bin/prolog -q english/wordnet_check.pl -g "check_file('story.txt'), halt"
yes (1)   The old farmer walked to the market.
yes (1)   Did his wife like the hat?
no        The dogs chases the cat.  (the verb 'chases' does not agree with its subject)
no        He sold three cows and bought a new hat!  (no reading)
unknown   Everyone was happy.  [everyone]

5 sentences: 2 grammatical, 2 not, 1 with a word the checker does not know
```

`check_file(user_input)` reads standard input instead, so text can be piped
or pasted in, `pbpaste | bin/prolog -q english/wordnet_check.pl -g
"check_file(user_input), halt"`, and `check_text/1` takes the text as an
atom. The number after *yes* is how many readings the sentence has. *No
reading* means the grammar has no rule for the sentence's shape, rather
than that some word disagrees: the stage 3 record below says which shapes
it lacks, and on ordinary English about three sentences in five pass.

A sentence ends at a full stop, question mark or exclamation mark followed
by a space, and at a blank line, so a heading is a sentence of its own. A
full stop inside a number does not end one, and nor does one after *Mr.*,
*Dr.*, *e.g.* and a few other common abbreviations; any other abbreviation
does. Punctuation inside a sentence is ignored, commas included.

All three stages set out in [the roadmap](../docs/ROADMAP.md) are done. Stage 1
is a small lexicon, simple declarative sentences, and agreement carried in the
rules. Stage 2 is auxiliaries, negation, yes/no and *wh*-questions, passives,
relative clauses, a guess at unknown words, contractions and possessives.
Stage 3 is WordNet's 85,000 words, and a record of what they break, at the
end of this file.

## The files

| | |
|---|---|
| `lexicon.pl` | 411 words, a word in two classes counted in each: 113 nouns, 50 verbs, 43 adjectives, 40 adverbs, 7 degree words (*very*), 39 prepositions, 23 determiners, 27 numbers and 4 that need one before them (*a hundred*, *two dozen*), 12 names (and any word a sentence capitalizes where a name can stand), 23 pronouns, 9 modals, 8 question and relative words (*that* is counted as a determiner), and 13 conjunctions; a number in digits is a word too; the forms of *be*, *have* and *do*; 17 contractions with *n't* and 6 others, *'s*, *'re*, *'m*, *'ve*, *'ll* and *'d*. Plurals and verb forms (*-s*, past, *-ing*, participle) are derived by rule, with the irregular ones listed, 434 noun and verb forms in all. 34 nouns are marked as mass nouns, which may stand alone in the singular, 14 as nouns of time, *last night*, and 14 adverbs as ones that may go before the verb. |
| `grammar.pl` | The rules: statements, alone or joined by a conjunction, yes/no and *wh*-questions, commands, noun phrases (with determiners, possessives, adjectives, prepositional phrases, relative clauses and `and`), verb phrases (a chain of auxiliaries, then a verb that is intransitive, transitive or ditransitive, or `be` with an adjective, noun phrase or place), negation, passives, adverbs. |
| `guess.pl` | A word the lexicon lacks, looked up in WordNet when it is loaded, or else guessed from its ending: *-ly* an adverb, *-tion* a noun, *-ful* an adjective, *-ize* a verb, and *-s*, *-ed* and *-ing* taken back to a stem that is placed the same way. |
| `check.pl` | Text into words, with contractions cut off; the verdict, the explanation, and the bracketed trees; running text into sentences, for `check_file/1`. |
| `wordnet_check.pl` | `check.pl` with WordNet's words loaded, from `wordnet.pl`, which `make wordnet` generates and git ignores. |
| `corpus.txt`, `corpus2.txt`, `corpus.pl` | Fifty ordinary sentences the grammar was built to pass; fifty from Simple English Wikipedia that it was not, with their articles in `corpus2-sources.tsv`; and the run over both that `make english-wordnet` does, which fails unless the counts are the ones `corpus.pl` records. |
| `tests.pl` | Sentences that must pass, sentences that must fail with a named reason, the number of readings of an ambiguous one, and how running text is cut into sentences. |

## What it checks

- **Subject and verb**: *the dogs chase*, *the dog chases*, *I am*, *you are*,
  *they were*, *nobody sleeps*; and a subject joined by *and* is plural. Each
  clause of a sentence joined by *and*, *but* or *because* agrees on its
  own: *the dog barks but the cats sleep*.
- **Determiner and noun**: *a dog*, *these dogs*, *six dogs*, *a hundred
  dogs*, not *a dogs*, *this dogs* or *one dogs*.
- **A and an**, by the sound of the next word rather than its spelling: *an
  hour*, *a university*, *an old man*.
- **Pronoun case**: *she sees him*, not *him sleeps* or *she sees he*.
- **Names are capitalized**: *John sleeps* and *the dog sees Leroy*, a name
  of several words, *Stanley Ralph Ross*, and a name before a noun, *the
  Congress Party*; but *the dog sees john* has a noun with no determiner,
  and so does *Dog barks*.
- **A singular noun needs a determiner**: *dogs bark*, not *dog barks*,
  unless it is a mass noun: *water boils*, *some homework*, and *much
  bread* but not *much dog*.
- **What a verb takes**: *gives* two objects, *sleeps* none, *tastes* an
  adjective, *wants* a *to*-infinitive, *thinks* a clause, *stops* an *-ing*
  form, *paints* an object and an adjective, *paint it blue*.
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

A **name** is known by its capital. The tokenizer cuts the words before it
lowercases them and notes which were capitalized, and each of those is a
name for that check, beside whatever else the word is: *Indian* is a name
and an adjective, and the grammar decides. A capitalized determiner,
pronoun, preposition, conjunction or form of *be*, *have* or *do* is not a
name, so *The Episcopal Church* is *the* and a name. The first word of a
sentence is capitalized whatever it is, so it is a name only when the word
after it is one too (*Michael Bruce Curry*), when the lexicon lists it or
WordNet writes it with a capital (*Springfield*, *John*), or when nothing
knows it at all (*Konnevesi*). Otherwise *Dog barks* would pass. A run of
names is one name, and names stand before a noun as adjectives do, *Peace
TV programs*. Only ASCII capitals are seen: the interpreter's
`downcase_atom/2` leaves *Île* as it is.

The diagnosis uses **the same grammar**. Each agreement point goes through
`agree/5`, which threads a list of violations beside the words. Parsed with the
list closed, a violation cannot be recorded, and the grammar is strict; parsed
with three places in it, it finds the reading with the fewest violations and
names them. The list was open until names let long sentences be parsed to
the end: with WordNet nearly every noun can stand bare, a violation each,
and a sentence of 28 words that no reading fits took more than six
minutes to be refused. With three places it takes one. A sentence more
than three violations from English gets no diagnosis, only *no reading*.

Recursion is **on the right**. A noun phrase is followed by its prepositional
phrases rather than built from a smaller noun phrase, since a left-recursive
rule such as `np --> np, pp` makes a DCG loop. Nothing in stage 2 has needed
one either: a relative clause follows its noun, as its prepositional phrases
do.

## Stage 3: what a large lexicon breaks

`make wordnet` downloads WordNet 3.1 and `tools/gen_wordnet.py` turns it into
`english/wordnet.pl`: 55,213 nouns, 14,783 names (the nouns WordNet writes with a capital), 8,431 verbs with the frames WordNet gives
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
three sentences, and the corpus then gave **31 grammatical, 18 not, and one
unknown**. `corpus.pl` records the current counts and fails on any others, so a
sentence that moves, either way, is seen in CI and the record is updated
with it.

The nouns that take no article went next. Nineteen are marked as mass
nouns in the lexicon, by hand, since WordNet does not say which nouns
these are: a mass noun may stand alone in the singular, and takes *some*
and the new *much*. That moved three more, and the corpus gives **34
grammatical, 15 not, and one unknown**. One of the three is a pass for the
wrong reason: *two cups of tea, please* is read as *two cups of tea please*,
*please* the verb, since the checker ignores commas. Of the five sentences
this cause held, *water boils at a hundred degrees* and *played football
after school* still fail, for a number and a preposition.

The closed classes were next: *and*, *but* and *or* join two clauses, and
*because*, *if*, *although*, *when* and six more join a clause to another,
after it or before it; the numbers, in words and in digits, with *a
hundred* and *two thousand*; *nobody*, *everyone* and the other indefinite
pronouns; and 23 more prepositions, *after* among them. WordNet has some of
these words as other classes, *before* as an adverb, *nobody* as a noun,
and a word the lexicon lists is never looked up there, so the adverbs worth
keeping are listed with them; *so* and *while* are left out as
conjunctions, since listing them would lose *so happy* and *a while*. Six
more sentences pass, and the corpus gives **40 grammatical, 10 not, and
none unknown**. The one new ambiguity is real: in *played football after
school*, *after school* can go with *played* or with *football*. The ten
that fail are all constructions, the last cause in the record.

The constructions went in last: adverbs before the verb, *has already
eaten*; degree words before an adjective, *very funny*; verbs that take an
adjective, a clause, a *to*-infinitive, an object and an infinitive, an
object and an adjective, or an *-ing* form, read from WordNet's own verb
frames, which the generator had been dropping; noun phrases as adverbs,
*last night*, *next door*; *such a*; and commands, *please close the
door*. A command is read only when nothing else can be, and no statement
can be even with a word that disagrees, because with WordNet nearly every
noun is also a verb, and *dog barks* would otherwise be the command "dog
the barks" instead of a noun missing its determiner. **All fifty sentences
now pass**, ten of them with two readings. One more of those is new, *the
lights went out*, where *out* is an adverb or, after *went* as in *went
quiet*, an adjective.

A corpus that passes entirely has stopped measuring anything. The fifty
sentences were chosen before the grammar grew to meet them, but it did
grow to meet them, and the next record needs sentences it has not seen.

## The second corpus: text it was not built against

`corpus2.txt` holds fifty sentences that nobody chose with the grammar in
mind. The rule was written down before any of the text was seen: draw
articles from Simple English Wikipedia with the API's random list, in the
main namespace; take the first two sentences of each article's lead, as
plain text and verbatim; skip an article whose lead has fewer than two
sentences; stop at fifty. The draw was made on 2026-09-29 and took 25
articles out of the first 28; three had a one-sentence lead.
`corpus2-sources.tsv` lists each article with the revision it was taken
from, so the text can be checked against its source. The sentences are
Wikipedia's, under [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/).

The sentences were cut with the checker's own splitter, which is under test
too, and it cut two of the fifty in the wrong place, after *lit.* in *El
Gordo (lit. The Fat One)* and after the *U.S.* in *She was the U.S.
Representative*. Two more of the sixty leads drawn were cut after *Vol.*
and *N.* The file keeps the true sentences, and the four cuts are a finding
of their own.

On 2026-09-29, **none was grammatical, 19 were not, and 31 had a word in
neither the lexicon nor WordNet**. Random articles are mostly people, places
and works, so the text is denser in names, dates and brackets than the
first corpus, and that is the text the checker will meet. The record, by
cause, found by cutting each failing sentence down until it passed:

**Names (most of the 31, and more of the 19).** The lexicon has twelve
names, *Alice* to *Ingrid*, and the tokenizer lowercases every word, so the
capital that marks a name is gone before the grammar sees it. A name
WordNet does not have is unknown: *Konnevesi*, *Nintendo*, *Ambani*. A name
it has as a common noun needs a determiner: *Woods was born in
Springfield* fails as *woods* with no article, and *John sleeps* fails the
same way. Names of more than one word, *East Coast Main Line*, are read as
nouns and adjectives. This one cause keeps most sentences from being read
at all, so the causes below are what the rest showed when cut down.

**Joining nouns and adjectives with *or*, and lists.** *I saw cats and
dogs* passes and *I saw cats or dogs* does not; *big or small* fails too.
A list with commas, *a politician, author and a member of the party*,
fails, and so does *a psychologist and businessman*, two nouns under one
determiner.

**Nouns that take no article, again.** The nineteen mass nouns were marked
by hand, and this text needs more: *cancer*, *television*, *service*, and
the months, *in January*.

**Nouns before nouns.** *The record label*, *feature movies*, *a rock
formation*, *Peace TV programs*, *a Spanish-language newspaper*: the
grammar has no noun used as a modifier.

**Constructions the grammar lacks.** A participle after its noun, *a movie
directed by*, and *the dogs chased by the cat bark*; a participle before
it, *the presiding bishop*; *a kind of*, *any kind of*; *also* after *be*,
*it is also the capital*; a phrase before the subject, *In geology, a
fracture is*, and *As of the census*; *about* with a number; *sworn in*;
*for being the voice*; a place and its region with a comma, *Springfield,
Massachusetts*; dates, *May 16, 2015*, *born 10 May 1969*; and anything in
brackets.

**Words it does not have.** Superlatives: *largest*, and *biggest*, are
unknown, since WordNet lists *large* and the forms are not derived from
it. An ordinal in digits, *the 27th king*, has no reading. The en dash in a range of dates is read as
a word. *U.S.* is read as the letters *u* and *s*.

**Time.** Most sentences take a tenth of a second. Five took between two and
six seconds, and one took 116: *They would have been derived from the Class
91 locomotives that entered service on the East Coast Main Line in 1989*,
which is then rejected for the wrong reason, *main* with no determiner. A
plain DCG redoes every shared sub-parse on each backtrack, and a long
sentence full of words that WordNet lists as nouns, verbs and adjectives at
once has a great many. That is the cost the roadmap said would decide
between a chart parser and tabling, and it has arrived before left
recursion did. The run over both corpora now takes two and a half minutes,
most of it this one sentence.

Names went first, as the largest cause (above, under *How it works*).
The corpus then gives **6 grammatical, 34 not, and 10 unknown**. Of the ten,
four are the en dash in a range of dates, two are superlatives, and the rest
are *foley*, an IPA transcription, Cyrillic, and *Île*. The passes were read,
and two of the six are passes for the wrong reason. *It stars Yevgeny
Leonov, Irina Skobtseva, and Valentina Talyzina* is two people, not three,
since without its commas the first two names run together. And all ten
readings of *They would have been derived from the Class 91 locomotives that
entered service* read *the Class* followed by a relative clause, *91
locomotives that entered*, with *service* as its verb: there is no rule yet
for a name followed by a number. The sentence that took 116 seconds takes
25 now, as its name is read as one, and the whole run takes a little under
three minutes.
