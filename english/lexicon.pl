/*  english/lexicon.pl -- the words, with their parts of speech and features.

    The grammar checker described in docs/ROADMAP.md. A word is known only
    if it is listed here, or is a regular form of a listed word: the plural
    of a noun, and the -s, past, -ing and participle forms of a verb, are
    derived by the rules at the end, and irregular ones are listed beside
    the word.

    Agreement between a subject and its verb is carried in one feature term,
    agr(First, Third, SgNot2), each slot y or n:

        First    the subject is first person singular       (I)
        Third    it is third person singular                (he, the dog)
        SgNot2   it is singular and not second person       (I, he, the dog)

    A subject has all three bound; a finite verb form, fin(Agr), binds only
    the slots it cares about, so that every English agreement fact, the
    irregular forms of be among them, is one unification:

        I       agr(y,n,y)          chases  agr(_,y,_)      am    agr(y,n,y)
        he      agr(n,y,y)          chase   agr(_,n,_)      is    agr(_,y,_)
        you     agr(n,n,n)          chased  agr(_,_,_)      are   agr(n,n,_)
        they    agr(n,n,n)                                  was   agr(_,_,y)
                                                            were  agr(_,_,n)

    A verb form is fin(Agr) when it can be a sentence's first verb, or one
    of the forms an auxiliary asks for after it: base (can bark), ing (is
    barking), en (has barked, was chased). Most words are several forms:
    bark is fin(agr(_,n,_)) and base, chased is fin(_) and en.
*/

% guessed(What, Entry): a word missing from the lexicon, placed for the
% length of one check, from WordNet when it is loaded or else by its ending;
% see guess.pl. What is noun, verb(Frames), adj or adv, with the stem as
% Entry, or irregular_plural, irregular_form or doubles, for WordNet's
% irregular forms. The open classes and the spelling rules below each end
% with a clause that reads it.
:- dynamic(guessed/2).

% WordNet, as english/wordnet.pl gives it when english/wordnet_check.pl
% loads it; declared here so that without it these simply fail.
:- dynamic(wn_noun/1).
:- dynamic(wn_verb/2).
:- dynamic(wn_adj/1).
:- dynamic(wn_adv/1).
:- dynamic(wn_irregular/3).

% agr_of(+Number, -Agr): the agreement of a third-person noun phrase.
agr_of(sg, agr(n, y, y)).
agr_of(pl, agr(n, n, n)).

/* ---------------- nouns ---------------- */

% noun(Singular): a count noun whose plural follows the rules below.
noun(dog). noun(cat). noun(bird). noun(horse). noun(cow). noun(fox).
noun(lion). noun(tiger). noun(rabbit). noun(snake). noun(fish). noun(sheep).
noun(man). noun(woman). noun(child). noun(person). noun(boy). noun(girl).
noun(baby). noun(friend). noun(teacher). noun(student). noun(doctor).
noun(farmer). noun(king). noun(queen). noun(neighbour). noun(artist).
noun(mouse). noun(foot). noun(tooth). noun(goose).
noun(house). noun(garden). noun(park). noun(city). noun(village). noun(road).
noun(river). noun(forest). noun(hill). noun(school). noun(library).
noun(kitchen). noun(room). noun(table). noun(chair). noun(door).
noun(window). noun(box). noun(bag). noun(book). noun(letter). noun(story).
noun(song). noun(picture). noun(ball). noun(toy). noun(car). noun(bus).
noun(train). noun(boat). noun(bicycle). noun(apple). noun(orange).
noun(banana). noun(egg). noun(cake). noun(sandwich). noun(bone).
noun(flower). noun(tree). noun(leaf). noun(stone). noun(key). noun(clock).
noun(hour). noun(umbrella). noun(island). noun(idea). noun(question).
noun(answer). noun(game). noun(party). noun(dress). noun(watch).
noun(university). noun(unicorn). noun(uniform). noun(elephant). noun(owl).
noun(bread). noun(tea). noun(coffee). noun(rice). noun(food). noun(music).
noun(homework). noun(advice). noun(information). noun(furniture).
noun(football). noun(breakfast). noun(lunch). noun(dinner).
noun(Sg) :- guessed(noun, Sg).

% mass(Noun): a noun that can stand in the singular with no determiner,
% "water boils", "we ate dinner", and take some or much there, "some
% homework": a substance, an activity or game, a meal. Most can be counted
% as well, "a coffee", "a big dinner", which the grammar also allows.
% WordNet does not say which nouns these are, so they are listed, WordNet's
% own words among them: water, milk, rain, snow and work are not in noun/1,
% because a word listed there is never looked up in WordNet, and each of
% them is a verb as well.
mass(water). mass(milk). mass(rain). mass(snow). mass(work).
mass(bread). mass(tea). mass(coffee). mass(rice). mass(food). mass(music).
mass(homework). mass(advice). mass(information). mass(furniture).
mass(football). mass(breakfast). mass(lunch). mass(dinner).

% irregular_plural(Singular, Plural).
irregular_plural(man, men).       irregular_plural(woman, women).
irregular_plural(child, children). irregular_plural(person, people).
irregular_plural(mouse, mice).    irregular_plural(foot, feet).
irregular_plural(tooth, teeth).   irregular_plural(goose, geese).
irregular_plural(sheep, sheep).   irregular_plural(fish, fish).
irregular_plural(leaf, leaves).
irregular_plural(Sg, Pl) :- guessed(irregular_plural, Sg-Pl).

% proper(Name): a name, third person singular, taking no determiner.
proper(alice). proper(bob). proper(carol). proper(david). proper(emma).
proper(frank). proper(london). proper(paris). proper(tom). proper(anna).
proper(oscar). proper(ingrid).

/* ---------------- pronouns ---------------- */

% pronoun(Word, Agr, Case): Case is subj, obj, or unbound for either.
pronoun(i,    agr(y, n, y), subj).
pronoun(me,   agr(y, n, y), obj).
pronoun(you,  agr(n, n, n), _).
pronoun(he,   agr(n, y, y), subj).
pronoun(him,  agr(n, y, y), obj).
pronoun(she,  agr(n, y, y), subj).
pronoun(her,  agr(n, y, y), obj).
pronoun(it,   agr(n, y, y), _).
pronoun(we,   agr(n, n, n), subj).
pronoun(us,   agr(n, n, n), obj).
pronoun(they, agr(n, n, n), subj).
pronoun(them, agr(n, n, n), obj).

/* ---------------- relative and question words ---------------- */

% rel_pronoun(Word, Case): a word that opens a relative clause, "the dog
% that barks", with the case of the noun phrase it stands for. which and who
% are not told apart by the noun, since that is a matter of meaning.
rel_pronoun(that,  _).
rel_pronoun(which, _).
rel_pronoun(who,   _).
rel_pronoun(whom,  obj).

% wh_pronoun(Word, Case): a word that asks for a noun phrase.
wh_pronoun(who,  _).
wh_pronoun(whom, obj).
wh_pronoun(what, _).

% wh_det(Word): a word that asks, before a noun: "which dog".
wh_det(which). wh_det(what).

% wh_adverb(Word): a word that asks for a place, time, reason or manner.
wh_adverb(where). wh_adverb(when). wh_adverb(why). wh_adverb(how).

/* ---------------- determiners ---------------- */

% det(Word, Number, Sound): Number is sg, pl or unbound for either, or mass
% for a determiner that takes only a mass noun, much; some takes a mass
% noun as well as a plural, and see det_agrees/6 in grammar.pl. Sound is
% the initial sound the next word must have, vowel or consonant, or unbound.
det(the,   _,  _).
det(a,     sg, consonant).
det(an,    sg, vowel).
det(this,  sg, _).   det(that,  sg, _).
det(these, pl, _).   det(those, pl, _).
det(every, sg, _).   det(each,  sg, _).
det(some,  pl, _).   det(many,  pl, _).   det(several, pl, _).
det(much,  mass, _).
det(few,   pl, _).   det(no,    _,  _).
det(my,    _,  _).   det(your,  _,  _).   det(his,     _,  _).
det(its,   _,  _).   det(our,   _,  _).   det(their,   _,  _).
det(one,   sg, _).   det(two,   pl, _).   det(three,   pl, _).
det(four,  pl, _).

% her is both a determiner and an object pronoun: "her dog", "saw her".
det(her,   _,  _).

/* ---------------- adjectives, prepositions, adverbs ---------------- */

adj(big). adj(small). adj(little). adj(large). adj(old). adj(young).
adj(new). adj(good). adj(bad). adj(happy). adj(sad). adj(angry).
adj(tired). adj(hungry). adj(quiet). adj(loud). adj(fast). adj(slow).
adj(red). adj(blue). adj(green). adj(yellow). adj(black). adj(white).
adj(brown). adj(tall). adj(short). adj(long). adj(warm). adj(cold).
adj(clever). adj(kind). adj(brave). adj(funny). adj(strange). adj(empty).
adj(beautiful). adj(ugly). adj(honest). adj(orange). adj(early). adj(late).
adj(colorless).
adj(A) :- guessed(adj, A).

prep(in). prep(on). prep(under). prep(near). prep(behind). prep(with).
prep(without). prep(from). prep(to). prep(into). prep(over). prep(by).
prep(for). prep(at). prep(across). prep(of).

adv(quickly). adv(slowly). adv(quietly). adv(loudly). adv(happily).
adv(sadly). adv(often). adv(always). adv(never). adv(sometimes).
adv(today). adv(yesterday). adv(again). adv(carefully). adv(well).
adv(furiously). adv(early). adv(late).
adv(A) :- guessed(adv, A).

/* ---------------- verbs ---------------- */

% verb(Base, Frames): Frames lists what the verb takes after it:
%   intrans   nothing            the dog sleeps
%   trans     one noun phrase    the dog chases a cat
%   ditrans   two noun phrases   alice gives the dog a bone
verb(sleep,  [intrans]).          verb(bark,   [intrans]).
verb(run,    [intrans]).          verb(walk,   [intrans, trans]).
verb(swim,   [intrans]).          verb(laugh,  [intrans]).
verb(cry,    [intrans]).          verb(smile,  [intrans]).
verb(sing,   [intrans, trans]).   verb(dance,  [intrans]).
verb(fly,    [intrans]).          verb(arrive, [intrans]).
verb(wait,   [intrans]).          verb(play,   [intrans, trans]).
verb(eat,    [intrans, trans]).   verb(drink,  [intrans, trans]).
verb(read,   [intrans, trans]).   verb(write,  [intrans, trans, ditrans]).
verb(chase,  [trans]).            verb(see,    [trans]).
verb(like,   [trans]).            verb(love,   [trans]).
verb(hate,   [trans]).            verb(find,   [trans]).
verb(lose,   [trans]).            verb(carry,  [trans]).
verb(watch,  [intrans, trans]).   verb(catch,  [trans]).
verb(push,   [trans]).            verb(open,   [intrans, trans]).
verb(close,  [intrans, trans]).            verb(visit,  [trans]).
verb(help,   [trans]).            verb(want,   [trans]).
verb(need,   [trans]).            verb(know,   [trans]).
verb(bite,   [trans]).            verb(hear,   [trans]).
verb(build,  [trans]).            verb(paint,  [intrans, trans]).
verb(stop,   [intrans, trans]).   verb(give,   [ditrans]).
verb(send,   [trans, ditrans]).   verb(show,   [trans, ditrans]).
verb(bring,  [trans, ditrans]).   verb(tell,   [trans, ditrans]).
verb(buy,    [trans, ditrans]).   verb(teach,  [trans, ditrans]).
verb(have,   [trans]).
verb(Base, Frames) :- guessed(verb(Frames), Base).

% irregular_past(Base, Past).
irregular_past(run, ran).      irregular_past(swim, swam).
irregular_past(sing, sang).    irregular_past(fly, flew).
irregular_past(eat, ate).      irregular_past(drink, drank).
irregular_past(read, read).    irregular_past(write, wrote).
irregular_past(see, saw).      irregular_past(find, found).
irregular_past(lose, lost).    irregular_past(catch, caught).
irregular_past(know, knew).    irregular_past(bite, bit).
irregular_past(hear, heard).   irregular_past(build, built).
irregular_past(give, gave).    irregular_past(send, sent).
irregular_past(bring, brought). irregular_past(tell, told).
irregular_past(buy, bought).   irregular_past(teach, taught).
irregular_past(have, had).    irregular_past(sleep, slept).
irregular_past(Base, Past) :- guessed(irregular_form, Base-Past).

% irregular_participle(Base, Participle): the en form, where it is not the
% past: "has eaten", not "has ate".
irregular_participle(run, run).       irregular_participle(swim, swum).
irregular_participle(sing, sung).     irregular_participle(fly, flown).
irregular_participle(eat, eaten).     irregular_participle(drink, drunk).
irregular_participle(write, written). irregular_participle(see, seen).
irregular_participle(know, known).    irregular_participle(bite, bitten).
irregular_participle(give, given).    irregular_participle(show, shown).
irregular_participle(Base, P) :- guessed(irregular_form, Base-P).

% irregular_third(Base, Form): the -s form, where the rule does not make it.
irregular_third(have, has).

% doubles(Base): the final consonant doubles before -ed and -ing.
doubles(run). doubles(swim). doubles(stop).
doubles(Base) :- guessed(doubles, Base).

/* ---------------- auxiliaries ---------------- */

% An auxiliary comes before the verb and decides its form: a modal or do
% takes the base (can bark, does bark), have the participle (has barked),
% be the -ing form (is barking) or, for a passive, the participle (was
% chased). Each is listed with its forms, as the verbs are.

% modal(Word): finite, agreeing with any subject, and with no other forms.
modal(can). modal(could). modal(will). modal(would). modal(shall).
modal(should). modal(may). modal(might). modal(must).

% do_form(Word, Form): do supports a verb that has no auxiliary of its
% own, in a question or with not; it has only finite forms.
do_form(do,   fin(agr(_, n, _))).
do_form(does, fin(agr(_, y, _))).
do_form(did,  fin(_)).

% have_form(Word, Form): have as the perfect auxiliary. It has no en form:
% "has had eaten" is not English. Have as a verb is in verb/2.
have_form(have,   fin(agr(_, n, _))).
have_form(have,   base).
have_form(has,    fin(agr(_, y, _))).
have_form(had,    fin(_)).
have_form(having, ing).

% be_form(Word, Form): be as the copula, the progressive and the passive.
% Every one of its forms is irregular.
be_form(am,    fin(agr(y, n, y))).
be_form(is,    fin(agr(_, y, _))).
be_form(are,   fin(agr(n, n, _))).
be_form(was,   fin(agr(_, _, y))).
be_form(were,  fin(agr(_, _, n))).
be_form(be,    base).
be_form(being, ing).
be_form(been,  en).

% neg_contraction(Word, Auxiliary): an auxiliary with not joined to it.
neg_contraction('don\'t', do).       neg_contraction('doesn\'t', does).
neg_contraction('didn\'t', did).     neg_contraction('can\'t', can).
neg_contraction(cannot, can).        neg_contraction('couldn\'t', could).
neg_contraction('won\'t', will).     neg_contraction('wouldn\'t', would).
neg_contraction('shouldn\'t', should). neg_contraction('mustn\'t', must).
neg_contraction('isn\'t', is).       neg_contraction('aren\'t', are).
neg_contraction('wasn\'t', was).     neg_contraction('weren\'t', were).
neg_contraction('hasn\'t', has).     neg_contraction('haven\'t', have).
neg_contraction('hadn\'t', had).

% clitic(Word, Auxiliary): a contraction cut from the word before it, "she's"
% as she and 's; see words/2 in check.pl. 's is is or has, 'd would or had,
% and 's is also the possessive, which the grammar reads for itself.
clitic('\'s', is).    clitic('\'s', has).   clitic('\'re', are).
clitic('\'m', am).    clitic('\'ve', have). clitic('\'ll', will).
clitic('\'d', would). clitic('\'d', had).

/* ---------------- forms ---------------- */

% noun_form(?Word, -Singular, -Number)
noun_form(Word, Sg, sg) :- noun(Sg), Word = Sg.
noun_form(Word, Sg, pl) :- noun(Sg), plural(Sg, Word).

plural(Sg, Pl) :- irregular_plural(Sg, Pl0), !, Pl = Pl0.
plural(Sg, Pl) :- s_form(Sg, Pl).

% verb_form(?Word, -Base, -Form): the present forms agree with the subject,
% the past form agrees with any; the others follow an auxiliary.
verb_form(Word, Base, fin(agr(_, y, _))) :- verb(Base, _), third(Base, Word).
verb_form(Word, Base, fin(agr(_, n, _))) :- verb(Base, _), Word = Base.
verb_form(Word, Base, fin(_))            :- verb(Base, _), past(Base, Word).
verb_form(Word, Base, base)              :- verb(Base, _), Word = Base.
verb_form(Word, Base, ing)               :- verb(Base, _), ing(Base, Word).
verb_form(Word, Base, en)                :- verb(Base, _), participle(Base, Word).

third(Base, Form) :- irregular_third(Base, F), !, Form = F.
third(Base, Form) :- s_form(Base, Form).

participle(Base, P) :- irregular_participle(Base, P0), !, P = P0.
participle(Base, P) :- past(Base, P).

% ing(+Base, -Form): running, chasing, seeing, playing.
ing(Base, Form) :-
    doubles(Base), !, atom_chars(Base, Cs), last(Cs, C),
    atomic_list_concat([Base, C, ing], Form).
ing(Base, Form) :- atom_concat(_, ee, Base), !, atom_concat(Base, ing, Form).
ing(Base, Form) :-
    atom_concat(Stem, e, Base), !, atom_concat(Stem, ing, Form).
ing(Base, Form) :- atom_concat(Base, ing, Form).

past(Base, Past) :- irregular_past(Base, P), !, Past = P.
past(Base, Past) :-
    doubles(Base), !, atom_chars(Base, Cs), last(Cs, C),
    atomic_list_concat([Base, C, ed], Past).
past(Base, Past) :-
    atom_concat(Stem, e, Base), !, atom_concat(Stem, ed, Past).
past(Base, Past) :-
    consonant_y(Base, Stem), !, atom_concat(Stem, ied, Past).
past(Base, Past) :- atom_concat(Base, ed, Past).

% s_form(+Base, -Form): the -s ending of a noun plural or of a verb:
% boxes, watches, cries, plays, dogs.
s_form(Base, Form) :- sibilant(Base), !, atom_concat(Base, es, Form).
s_form(Base, Form) :- consonant_y(Base, Stem), !, atom_concat(Stem, ies, Form).
s_form(Base, Form) :- atom_concat(Base, s, Form).

sibilant(W) :- atom_concat(_, s, W).
sibilant(W) :- atom_concat(_, x, W).
sibilant(W) :- atom_concat(_, z, W).
sibilant(W) :- atom_concat(_, ch, W).
sibilant(W) :- atom_concat(_, sh, W).

consonant_y(Word, Stem) :-
    atom_concat(Stem, y, Word),
    atom_chars(Stem, Cs), last(Cs, C), \+ vowel_letter(C).

/* ---------------- sound ---------------- */

% sound(+Word, -Sound): whether Word begins with a vowel or a consonant
% sound, which is what chooses between a and an. The spelling decides,
% except for the words listed.
sound(Word, Sound) :- sound_exception(Word, S), !, Sound = S.
sound(Word, Sound) :-
    atom_chars(Word, [C|_]),
    ( vowel_letter(C) -> Sound = vowel ; Sound = consonant ).

sound_exception(hour, vowel).        sound_exception(honest, vowel).
sound_exception(university, consonant). sound_exception(unicorn, consonant).
sound_exception(uniform, consonant). sound_exception(one, consonant).

vowel_letter(a). vowel_letter(e). vowel_letter(i). vowel_letter(o).
vowel_letter(u).
