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
full stop inside a number does not end one, and nor does one that the text
shows to be an abbreviation's: after initials, *N.* or *U.S.*; after a
short word before a number, *Vol. 3* or *No. 5*; or after *Mr.*, *Dr.*,
*e.g.*, *lit.* and a few others that are listed, since nothing in their
shape tells them from the last word of a sentence. Any other abbreviation
ends one. Inside a sentence a comma is read, and the grammar has to place
it; what stands in brackets is set aside; other punctuation is ignored. The mark at the end has to fit: a
question mark for a question, a full stop or an exclamation mark for the
rest.

All three stages set out in [the roadmap](../docs/ROADMAP.md) are done. Stage 1
is a small lexicon, simple declarative sentences, and agreement carried in the
rules. Stage 2 is auxiliaries, negation, yes/no and *wh*-questions, passives,
relative clauses, a guess at unknown words, contractions and possessives.
Stage 3 is WordNet's 85,000 words, and a record of what they break, at the
end of this file.

## The files

| | |
|---|---|
| `lexicon.pl` | 412 words, a word in two classes counted in each: 113 nouns, 50 verbs, 43 adjectives, 40 adverbs, 7 degree words (*very*), 40 prepositions, 23 determiners, 27 numbers and 4 that need one before them (*a hundred*, *two dozen*), 12 names (and any word a sentence capitalizes where a name can stand), 23 pronouns, 9 modals, 8 question and relative words (*that* is counted as a determiner), and 13 conjunctions; a number in digits is a word too; the forms of *be*, *have* and *do*; 17 contractions with *n't* and 6 others, *'s*, *'re*, *'m*, *'ve*, *'ll* and *'d*. Plurals and verb forms (*-s*, past, *-ing*, participle) are derived by rule, with the irregular ones listed, 434 noun and verb forms in all. 147 nouns are marked as mass nouns, which may stand alone in the singular, and with WordNet loaded so is any noun whose most frequent sense is a substance; 14 as nouns of time, *last night*, and 14 adverbs as ones that may go before the verb. |
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
- **Lists, with *and*, *or* or *but***: *Alice, Bob and Carol sing*, with
  the comma before *and* or without it; *the dog or the cats bark*, *or*
  agreeing with the nearest; *a doctor and teacher* under one determiner,
  which agrees with each noun, so not *these cat and dogs*, and *a
  politician, author and a member of the party*, where the first item
  has two nouns under its determiner; *big, old and happy* after a verb
  and *a big, old dog* before a noun; verb phrases, *the dog sleeps and
  eats*, *was made by Retro Studios and published by Nintendo*, each in
  the form of the first; and *either ... or*, *neither ... nor* and
  *both ... and* before a list of noun phrases or of verb phrases. A comma is read
  only in a list, between two clauses (*the dog barks, but the cat
  sleeps*, *if it rains, the dog sleeps*), between a name and the name
  that places it (*Springfield, Massachusetts*), around an appositive
  after a name (*Alice, a doctor, sleeps*) and before a last *please*;
  anywhere else it leaves the sentence with no reading, so *Alice, Bob
  sing* and *the dog, barks* fail.
- **An appositive after a name**: a comma and a noun phrase that says what
  the name is, *Mukesh Ambani, chairman of Reliance Industries*, *Alice,
  a doctor, sleeps*, *the dog sees Alice, a doctor*; one noun phrase with
  a determiner, a possessor or a bare role noun, closed by a comma or the
  end of the sentence, so *Alice, a doctor sleeps* has no reading.
- **A role noun stands bare**: a noun for a person, with *of* after it,
  needs no determiner after *be* or beside a name, *he was chairman of
  the board*, *chairman and managing director of Reliance Industries*;
  without the *of*, or for a noun that is not a person's, it still does,
  so *I am student* and *it is piece of cake* are refused. The nouns for
  people are the lexicon's own and those WordNet gives a person as the
  most frequent sense.
- **A phrase before the subject**: *yesterday the dog barked*, *in 2019,
  978 people lived there*, *last night the dog barked*, with a comma or
  none; but not *about the dog barked*.
- **A rough number**: *about 2,850 people*, *nearly six years*.
- **A kind of**: after *kind*, *sort* or *type*, *of* takes a singular
  noun with no determiner, *a kind of rock*, *some sort of animal*, *any
  kind of separation or break*; after other nouns it does not, *a picture
  of bird*.
- **Dates**: *on May 16, 2015*, *on 10 May 1969*, *in January 2014*.
- **Brackets are set aside**: *Nita Ambani (born 1 November 1963) is an
  Indian philanthropist* is checked as *Nita Ambani is an Indian
  philanthropist*, and what is in the brackets is not checked.
- **Adverbs after *be***: *it is also the capital*, *the dog is always
  happy*.
- **Nouns before nouns**: *the record label*, *a water polo player*, *an
  apple tree*, the modifying nouns in the singular and after any
  adjectives, and *a* or *an* by the first of them. A word that is an
  adjective as well is read as the adjective, *the stone bridge*, unless
  a noun modifier already stands before it, *a jazz bebop alto
  saxophonist*, where it is one more; *last* and *next* stay out, so *I
  saw the film last night* keeps its one reading.
- **A participle before a noun**: *the presiding bishop*, *a painted
  house*, *the barking dogs*, *managing director*, an *-ing* or *-en*
  form of a verb standing where an adjective does; a word that is an
  adjective or a noun as well, *tired*, *building*, is read as that. A
  participle after its noun, *a movie directed by*, is not read; see the
  roadmap.
- **Determiner and noun**: *a dog*, *these dogs*, *six dogs*, *a hundred
  dogs*, not *a dogs*, *this dogs* or *one dogs*.
- **A number before the noun**: *the 2020 census*, *the 2017 World
  Aquatics Championships*, *a 1968 Soviet comedy movie*, a number in
  digits first among the modifiers, after a determiner or a possessor;
  with nothing before it the digits are the determiner, *3 dogs*. *A*
  or *an* goes by the number as it is said, *an 1800 census*, *a 1968
  movie*.
- **A gerund after a preposition**: *tired of barking*, *after eating the
  cake*, *the record for being the largest cluster*, an *-ing* verb
  phrase where a noun phrase would stand.
- **Comparatives, superlatives and ordinals**: *the older dog*, *the
  biggest dog*, *the largest cluster*, a form of an adjective the lexicon
  or WordNet lists, by the spelling rules; and an ordinal in digits, *the
  27th bishop*, *1st*, *2nd*, *3rd*, one word and an adjective.
- **A and an**, by the sound of the next word rather than its spelling: *an
  hour*, *a university*, *an old man*.
- **Pronoun case**: *she sees him*, not *him sleeps* or *she sees he*.
- **Names are capitalized**: *John sleeps* and *the dog sees Leroy*, a name
  of several words, *Stanley Ralph Ross*, and a name before a noun, *the
  Congress Party*; but *the dog sees john* has a noun with no determiner.
  The first word is capitalized whatever it is, so *Woods was born* and
  *Dog barks* are each read with a name, and the verdict says so. A comma
  and a name after a name place it, *Springfield, Massachusetts*,
  *McLennan County, Texas, United States*, and the whole is one name. An
  adjective may stand before a name, *old London*, *north-eastern France*.
- **A hyphen inside a word** stays when something knows the word whole:
  a capital makes it a name, *Bernes-sur-Oise*; the lexicon or WordNet has
  it as written, *well-known*, or closed up, *north-eastern*. Otherwise
  the word is its parts, *singer-songwriter* as *singer* and
  *songwriter*.
- **A singular noun needs a determiner**: *dogs bark*, not *dog barks*,
  unless it is a mass noun: *water boils*, *some homework*, and *much
  bread* but not *much dog*. 147 are listed by kind (drinks,
  qualities and feelings, fields of study, sports, illnesses, *knowledge*,
  *television*, *cancer*), and a noun WordNet gives a substance as its
  most frequent sense is one too: *iron*, *sand*, *glass*.
- **What a verb takes**: *gives* two objects, *sleeps* none, *tastes* an
  adjective, *wants* a *to*-infinitive, *thinks* a clause, *stops* an *-ing*
  form, *paints* an object and an adjective, *paint it blue*.
- **The form after an auxiliary**: *can bark*, *has eaten*, *is sleeping*,
  *was chased*, not *can barks* or *has ate*.
- **The order of auxiliaries**: *might have been chased*, not *is having
  eaten* or *can can swim*.
- **A request without a verb**: a noun phrase and *please* with a comma
  between them, *two cups of tea, please*, *please, the bill*, read on
  the terms a command is, only when nothing else reads the sentence.
  The comma tells it from a statement, since *please* is a verb too:
  *the dogs please* is a statement, and *a coffee please* one with its
  verb disagreeing.
- **The mark at the end fits the sentence**: a question ends with a
  question mark, and a statement or a command with a full stop or an
  exclamation mark, so *The dog barks?* and *Does the dog bark.* are both
  refused. Text with no mark at the end is taken as it is.
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
name, so *The Episcopal Church* is *the* and a name, and nor is a number
or *please*. The first word of a sentence is capitalized whatever it is,
and nothing in the word tells *Woods was born* from *Dog barks*, since
WordNet has *woods* only in lowercase; so it is a name too, and when the
sentence is read no other way the verdict says so, *'woods' is read as a
name, since it begins the sentence with a capital*. The exception is a
word that is a plural and no singular, *Dogs bark*, *Leaves fall*, which
stays its noun, so that *Dogs barks* is still refused. A run of names is
one name, and names stand before a noun as adjectives do, *Peace TV
programs*. Capitals past ASCII count where the interpreter's case table
has them, Latin-1, Latin Extended-A, Greek and basic Cyrillic: *Île*,
*Çorlu*, *Αθήνα*, *Москва*.

A **list** is one rule, shared by noun phrases, nouns under one
determiner and adjectives: the items after the first are separated by
commas, and the last is joined by a conjunction, with a comma before it
or none. The comma is a word of its own, so a rule has to place it. Until
lists, the tokenizer threw commas away with the rest of the punctuation,
and a sentence could pass because of it: *two cups of tea, please* read
*please* as a verb, and *Alice, Bob and Carol* read *Alice Bob* as one
name. Joined by *and*, noun phrases are plural. Joined by *or*, they agree
with the last, which is the nearest to the verb, as English has it. Nouns
under one determiner may be one thing or several, *a doctor and teacher*
against *the cat and dog are hungry*, so the number is left to the verb
unless the determiner decides it. *The dogs and cats* has two readings,
*the* over both nouns or over the first alone, and the grammar keeps both.

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
`english/wordnet.pl`: 57,176 nouns, 15,025 names (the nouns WordNet writes with a capital), 8,696 verbs with the frames WordNet gives
them, 20,734 adjectives, 3,749 adverbs, and 4,325 irregular forms, hyphenated
words among them, *well-known*, *part-time*. It is not
committed. A word the lexicon lacks is looked up there, as itself, as an
inflected form of a stem, among the irregular forms (*flung*, *oxen*,
*grabbed*), as a comparative or superlative of an adjective (*largest*),
or, for a hyphenated word, closed up (*north-eastern* as
*northeastern*), before it is guessed from its ending. The lexicon's own words are
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
of their own. Since 2026-09-30 the splitter cuts all four right, and none
of the other 56 leads differently: initials and a short word before a
number are known by their shape, and *lit.* is listed.

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

Lists and *or* went next. The corpus counts stayed at **6, 34 and 10**, but
two sentences moved. *Examples are joints or faults* now passes, and *Leroy
is a city in McLennan County, Texas, United States* now fails: its commas
set a place beside its region, which is a construction the grammar does not
have, and the pass had come from the commas being dropped. *It stars
Yevgeny Leonov, Irina Skobtseva, and Valentina Talyzina* still passes, now
as three people. The first corpus loses one: *two cups of tea, please* has
no verb, and with its comma read it is refused, as it should be, since the
grammar has no rule for a request without one. It records 49 grammatical
and 1 not. The run over both corpora takes two minutes, a minute less than
before, since a comma now ends readings that ran on past it.

Most of the second corpus's lists sit in sentences that fail for another
cause first. Cut down, *he is an Irish psychologist and businessman* and *he
was a pianist, singer and composer* pass. *A French record producer, DJ and
remixer* waits for nouns before nouns, and *an Indian politician, author and
a member of the Congress Party* for a list that mixes nouns under one
determiner with a noun phrase of its own.

A name followed by a number was next, *Class 91*, *Apollo 11*: the number
may belong to the name before it, and a first word followed by a number
may be a name, *Class 93 is*. It may also not belong, so *Alice gave Bob 3
dogs* has two readings, one giving dogs to someone called Bob 3. No
sentence of the corpus moved. *They would have been derived from the Class
91 locomotives that entered service* now reads *the Class 91 locomotives*
as it should, but *entered service* then needs *service* to stand without
an article, which it may not yet, so the sentence still passes only as *the
Class that 91 locomotives service*: English in form, and not what it says.
With *the service* it has the right reading.

Nouns before nouns came next: a noun in the singular may stand between the
adjectives and the noun they go with, *a platform video game*, *the NBC
television network*. With WordNet nearly every word is a noun, so a word
that is an adjective or a name there is read as that and not again as a
noun, or *the nineteenth century* and *the film last night* would each
have gained a reading; the first corpus's counts of readings did not move.
The second corpus gains one sentence, *Donkey Kong Country Returns is a
platform video game for the Nintendo Wii game console*, and gives **7
grammatical, 33 not, and 10 unknown**. Cut down, *the owner of the record
label*, *a break in a rock formation*, *comedy routines* and *a French
record producer, DJ and remixer* all pass; the sentences they come from
still fail on dates, brackets, *any kind of* and the rest. The run takes
three minutes, from two and a half, since every noun can now be tried as
the start of a longer one.

On 2026-09-30 the interpreter learned case past ASCII, for Latin-1, Latin
Extended-A, Greek and basic Cyrillic, and a capital there marks a name
like any other. One sentence moved: *It is in Île-de-France in the
Val-d'Oise department in north France* had *Île* as an unknown word, and
now fails on what follows it instead. The Cyrillic title in *Zigzag of
Success (Russian: Зигзаг удачи)* now has one unknown word, *удачи*, where
it had two. The corpus gives **7 grammatical, 34 not, and 9 unknown**.

Mass nouns came next, and the rule of the day before held: a word is not
added because a corpus sentence needs it. They were added by kind, 113 of them
chosen from what a learner's dictionary marks uncountable, and three of them, *cancer*, *television* and *service*, were
the corpus's; the rest of each kind came with them. WordNet gave the rest:
a noun whose most frequent sense is in its substance category is a mass
noun, 2,354 of them. That category is nearly all uncountable, with some
noise the other way, *log* and *crystal*, which may now stand bare
unchallenged; the food category beside it holds *apple* and *pizza*, and
was left out. The months needed nothing, since a capital already makes
*January* a name. The corpus gives **8 grammatical, 33 not, and 9 unknown**,
*he has worked in feature movies and television* the new pass. The *Class
91* sentence now passes for the right reason as well as the wrong one: of
its 36 readings, 18 read *the Class 91 locomotives that entered service*,
and 18 still read *the Class that 91 locomotives service*, since nothing
in the grammar prefers one reading to another.

A phrase before the subject came next, of the kinds that can follow the
verb: an adverb, a prepositional phrase, or a time phrase such as *last
night*. The one sentence it moved was a pass for the wrong reason at
first: *About 2,850 people lived there in January 2014* passed with
*about* as an adverb over the whole sentence, or as *[about 2,850]* standing
before *people lived there*, and neither is what it says. A rough number,
*about 2,850 people*, *nearly six dogs*, gave it the reading it means, and
*about* and *nearly*, with *too* and *quite*, stopped opening sentences as
adverbs; *really* and *rather* still do. It keeps one reading it does not
mean, *[about 2,850] people lived there*, which is English in form. The
corpus gives **9 grammatical, 32 not, and 9 unknown**.

*A kind of* and adverbs after *be* were next, each small. *Kind* had been
an adjective only, and since a word the lexicon lists is not looked up in
WordNet, it had no noun; *any* was no determiner. After *kind*, *sort* or
*type*, *of* now takes a singular noun with no determiner, or several
joined, and *some* takes *sort* and *kind* in the singular. The copula takes
the adverbs a verb may have before it. The corpus gives **10 grammatical, 31
not, and 9 unknown**: *In geology, a fracture is any kind of separation or
break in a rock formation* passes, with three readings that differ only in
where *in a rock formation* goes, and it needed the phrase before the
subject from earlier in the day as well.

Dates came next. A month and a number already read as a name and a
number, *January 2014*, *May 16*, so two forms were added: a month, its
day, a comma and its year, *April 14, 1948*, and the day before the month,
*10 May 1969*. The corpus gives **11 grammatical, 30 not, and 9 unknown**:
*It was founded on April 14, 1948 by Stanley Ralph Ross* passes, with the
one reading it means. Most of the corpus's other dates stand in brackets,
*(born 10 May 1969)*, and wait for those.

Brackets were the last of the constructions, and they were not read but set
aside: a parenthesis stands outside its sentence's grammar, and what goes
in one, a date range, *born* and a date, a translation, a pronunciation, is
open-ended. The sentence is checked without it, and nothing in it is
checked, an unknown word included. A bracket never closed is dropped like
other punctuation, and a sentence all in brackets is read as it is. Before
this, the bracket marks were dropped and their contents left in the
sentence. The corpus gives **18 grammatical, 29 not, and 3 unknown**. Seven
sentences pass, each read as it means: a name, *is* or *was*, and a noun
phrase, *Frank Dolphin (born January 1959) is an Irish psychologist and
businessman*, *Anastassiya Yeremina (born 19 February 2000) is a
Kazakhstani female water polo player*. Six of the nine unknown had their
unknown word in brackets, the en dash in a range of dates most of all. Two
sentences went from unknown to not: *Sedan* begins its sentence and is
read as the noun, as *Woods* is, and *Zigzag of Success* has no reading.
The run takes three and a half minutes, as more sentences are now parsed
to the end.

On 2026-10-01 the first word of a sentence became a name like any other
capitalized word. It had been one only with more to go on, since it is
capitalized whatever it is: the word after it a name too, the lexicon or
WordNet listing it as one, or nothing knowing it at all. That kept *Dog
barks* a bare noun, and with it *Woods was born* and *Sedan is a commune*,
since WordNet has *woods* and *sedan* only in lowercase; nothing in the
word tells the two apart. Now all three are read with a name, and the
verdict says so when the sentence is read no other way: *'woods' is read
as a name, since it begins the sentence with a capital*. A word that is a
plural and no singular, *Dogs*, *Leaves*, stays its noun, so *Dogs barks*
is still refused, and a number and *please* are no names, so *Hundred dogs
bark* and *Please close the door* read as before. Two readings that print
alike, the name and the mass noun in *Bread is good*, are now counted
once. The corpus still gives **18 grammatical, 29 not, and 3 unknown**:
*Woods was born in Springfield* passes, and *Sedan is a commune in the
Ardennes department and Grand Est region of France* passes, but each
corpus sentence stops on something else, the comma in *Springfield,
Massachusetts*, and *north-eastern France*, a hyphenated word WordNet has
only closed up before a name that takes no adjective. *Elm was a
municipality* is read past its first word too, and stops on its list. The
run takes 3:41.

The comma that places a name came the same day: a name, a comma and a
name after it are one name, *Springfield, Massachusetts*, *McLennan
County, Texas, United States*, and may go on, as the second does. Names
only: *Mukesh Ambani, chairman and managing director* waits, with
*chairman* as a bare noun, which the grammar refuses elsewhere too, *He
was chairman of the Health Service Executive*. The rule leaves the
shorter name open, since in *In London, Alice sleeps* the comma ends the
phrase before the subject, so *Alice, Bob and Carol sleep* now has two
readings, *Bob* a name of his own or the place of *Alice*; and *Alice,
Bob sing* is now refused as a name with a plural verb rather than as no
sentence at all, and *Alice, Bob sings* passes. That is what names alone
can tell. The corpus gives **21 grammatical, 26 not, and 3 unknown**:
*Woods was born in Springfield, Massachusetts*, *Leroy is a city in
McLennan County, Texas, United States*, and *Peace TV is a nonprofit
satellite television network broadcasting globally from Dubai, United
Arab Emirates*, the last with *broadcasting* read as a noun that ends the
noun phrase, which is English in form and not what it means; the
participle it is waits for the parser. The run takes 3:18.

Hyphens came after, since the Sedan sentence, read past its first word,
stopped on *north-eastern France*: the tokenizer had cut at the hyphen,
and *north eastern France* has a noun before an adjective. A hyphen
between letters now stays in its word, and the word stays whole when
something knows it: a capital makes it a name, *Bernes-sur-Oise*,
*Chavez-DeRemer*; the lexicon or WordNet has it as written, *well-known*,
*part-time*, which `tools/gen_wordnet.py` had left out with every
hyphenated lemma and now keeps, 5,477 of them; or WordNet has it closed
up, *north-eastern* as *northeastern*, and the word takes the closed
word's entries. Otherwise it is its parts, *singer-songwriter* as
*singer* and *songwriter*, each placed on its own, which is what it was
before. With that, an adjective may stand before a name, *old London*,
*north-eastern France*, the adjective not a name itself, so that *United
States* stays one name. The corpus gives **24 grammatical, 23 not, and 3
unknown**: the Sedan sentence, *Bernes-sur-Oise is a commune*, and *It is
in Île-de-France in the Val-d'Oise department in north France*. The run
takes 2:56.

Superlatives and ordinals were the last of the day. *Largest* was unknown,
two of the three unknown sentences: WordNet lists *larger* and *bigger* as
words of their own but no superlative, and the lexicon derives no forms
for an adjective. A word in *-er* or *-est* whose stem, by the spelling
rules, is an adjective the lexicon or WordNet has, *older*, *largest*,
*happiest*, *biggest*, is now that adjective's and an adjective itself.
An ordinal in digits, *27th*, had been cut into *27* and *th*; it is one
word and an adjective, and a number in digits is now digits alone. The
corpus gives **26 grammatical, 23 not, and 1 unknown**. The two
*largest* sentences went from unknown to not, each stopping on something
after it: *the record for being the largest cluster*, a gerund clause
after a preposition, and *the largest distant galaxy cluster seen as of
2011*, a participle. *The 27th presiding bishop* stops on its participle
too. Two sentences with an ordinal passed outright, *She was the U.S.
Representative for Oregon's 5th congressional district from 2023 to
2025* and the sentence before it, each with the reading it means among
the ways *from 2023 to 2025* can attach. The run takes 3:11.

A gerund after a preposition followed: *tired of barking*, *after eating
the cake*, *the record for being the largest cluster*, an *-ing* verb
phrase where a noun phrase would stand, its first word in the *-ing*
form as after a verb that takes one. The first version let the verb
phrase rule decide that, as the verb's rule does, and the corpus run that
had taken three minutes was stopped at fifteen: with agreement relaxed
for the diagnosis, every noun WordNet also lists as a verb opened a verb
phrase after every preposition: *Class 93 is the traction classification
assigned to the electric locomotives that were to enter service as part
of British Rail's InterCity 250 project on the West Coast Main Line*,
thirty words and five prepositions, is refused in three seconds with the
guard and had not been refused after seven minutes without it. The rule is now entered only
when the next word is an *-ing* form, a lookahead the diagnosis does not
relax, so *after eat the cake* gets no diagnosis where it might have had
one. The corpus gives **28 grammatical, 21 not, and 1 unknown**: *It has
(2014) the record for being the largest distant galaxy cluster we have
discovered* and *He was also known for being the voice of Mickey Mouse
from 1947 to 1977*. The run takes 3:14.

What lists left came last. Verb phrases had never been joined at all:
*the dog sleeps and eats* had no reading, since *and* joined statements
and noun phrases only. A verb phrase may now be followed by others in
the same form, by the list rule noun phrases use, *barks, eats and
sleeps*, *was made by Retro Studios and published by Nintendo*, and
*either*, *neither* or *both* before a list of noun phrases or verb
phrases fixes its conjunction, *either the dog or the cat sleeps*,
*neither sleeps nor eats*. The first item of a list of noun phrases may
be a determiner with nouns after it set off by commas, *an Indian
politician, author and a member of the Congress Party*, where *author*
had needed a determiner. The corpus gives **30 grammatical, 19 not, and 1
unknown**: *It was made by Retro Studios and published by Nintendo*, with
a reading that joins *published* to *was* and one that joins it to *was
made*, both English in form, and the Syed Ahmed sentence. Two more that
looked like lists were not: *jazz bebop alto saxophonist* is an adjective
after noun modifiers, and *the 2017 World Aquatics Championships and 2019
World Aquatics Championships* a number before the noun; both are on the
roadmap. The run takes 3:19.

On 2026-10-02 came the appositive after a name, and the bare role noun it
needs: a comma and a noun phrase that says what the name is, *Alice, a
doctor, sleeps*, closed by a comma or the end of the sentence, as the
list rule's comma is read only in a list; and a noun for a person, with
*of* after it, standing without its determiner after *be* and beside a
name, *he was chairman of the board*. The person nouns are the lexicon's
own and WordNet's, the nouns whose most frequent sense is in its category
of people, which `tools/gen_wordnet.py` now writes as `wn_person/1`, as it
writes the substances. The *of* is the licence and is read inside the
noun phrase, so *was chairman of the board* has one reading and not the
two that *was the chairman of the board* has; without it *I am student*
is still refused, which a learner's checker should do. The corpus gives
**31 grammatical, 18 not, and 1 unknown**: *He was chairman of the Health
Service Executive (HSE)*. *She is the wife of Mukesh Ambani, chairman and
managing director of Reliance Industries* reads its appositive and stops
on *managing*, which WordNet has only as a form of the verb: a participle
before a noun, the half of the participle change that costs a lookahead
and not a verb phrase after every noun. The corpus alone runs in 2:54.

That half came the same day: an *-ing* or *-en* form of a verb that is
not an adjective or a noun as well stands before a noun as an adjective
does, *the presiding bishop*, *a painted house*, *managing director*. It
was measured before it was believed, sentence by sentence on a copy of
the tree against the commit before it, and the first measure said no: the
corpus run went from 184 to 318 seconds of CPU, and *Nita Ambani ... is
an Indian philanthropist and businesswoman, best known as the chairperson
of the Reliance Foundation* from a third of a second to fifty, for no
reading gained. Two causes, both outside the rule. The test for a
participle asks `verb_form/3` with the word given, which walks every verb
for each of its forms, a millisecond, and the grammar asks it at every
word a noun phrase could start at; the answer is now kept per word while
the sentence's placements stand. And *as* was not in the lexicon, so
WordNet supplied it, as a noun, the Roman coin: *best known as* became a
noun phrase headed by *as* once the participle could swallow *known*,
and the relaxed search ran on from there, where before it had stopped at
*known*. *As* is now a preposition, which also took *He was sworn in as
the sixteenth Governor* from nineteen seconds to a tenth. With both, the
run is 197 seconds of CPU against 184, the difference nearly all in one
sentence, *They would have been derived from the Class 91 locomotives
that entered service on the East Coast Main Line in 1989*, where
*entered service* may now open a subject inside the relative clause, and
every attachment of the phrases after it is tried before that fails. The
corpus gives **33 grammatical, 16 not, and 1 unknown**: the Ambani
sentence, and *He was the 27th presiding bishop and primate of The
Episcopal Church*. `make english-wordnet`, the checks and both corpora,
takes 3:40.

The request without a verb closed the first corpus the same day: a noun
phrase and *please* with a comma between them, *two cups of tea,
please*, *please, the bill*, is read on the terms a command is, only
when nothing else reads the sentence, and the comma is what tells it
from a statement, since *please* is a verb as well and *the dogs please*
is one; *a coffee please* stays a statement whose verb disagrees. The
sentence had passed while commas were thrown away, with *please* the
verb, and was refused once they were read. The rule cost seventy
seconds at first: a command is tried on every sentence nothing else
reads, and the request parsed a noun phrase for each of them before the
*please* was missed. It is now entered only when a *please* is somewhere
in what is left to read, the guard the possessive uses, and the run is
3:30. The first corpus gives **50 grammatical**, and so guards
everything it has and measures nothing, which is what it is for.

Then the adjective after a noun modifier, which turned out to be a noun
after one: *alto* in *a jazz bebop alto saxophonist* is a noun as well
as an adjective in WordNet, and a noun modifier was never read from a
word that is an adjective, since *stone* and *last* are both and *the
stone bridge* would have had a reading for each. After a noun modifier
the adjectives have been read, so such a word there can be nothing but
one more noun modifier, and it now is; *last* and *next* stay out, as
they stand before a noun only in *last night*, which keeps *I saw the
film last night* at one reading. A plain adjective after a noun
modifier, *a world famous singer*, is still not read. The corpus gives
**34 grammatical, 15 not, and 1 unknown**: the Woods sentence, whose
list of four nouns the grammar already had. `make english-wordnet` takes
2:43, down from 3:30, since that sentence had been the slowest in the
corpus, eighty seconds to refuse, and now has a reading and no
diagnosis to search for.

The number before the noun came last of the four: a number in digits
first among the modifiers, after a determiner or a possessor, *the 2020
census*, *the 2017 World Aquatics Championships*, *a 1968 Soviet comedy
movie*; with nothing before it the digits stay the determiner, *3
dogs*, so that sentence keeps one reading. The rule was cheap and the
Kazakhstan sentence was not: once it could be read, the strict parse of
it ran for minutes, where it had been refused in nine seconds, and a
ten-word cut took three. Cutting further found the cost in the names
and not the number: *the World Aquatics Championships and World
Aquatics Championships* took six times longer for every word of the
runs. A noun phrase could end at any word of a capitalized run, since
each is a noun in WordNet as well, and then try the rest as a relative
clause with no relative word, which starts the same search again one
word on. A head that is a name now does not end before another name,
which is what `name//1` already does for a run read whole. The corpus
gives **35 grammatical, 14 not, and 1 unknown**: the Kazakhstan
sentence, with five readings, the two phrases attached two ways and
*2019* read as a determiner of its own. `make english-wordnet` takes
1:12, down from 2:43: the Woods and the Class 91 sentences had the
same shape in them, *East Coast Main Line*, and every sentence with a
run of names paid for it. *As of the 2020 United States census* reads
its number and stops on *as of*, a preposition of two words.

