/*  english/lexicon.pl -- the words, with their parts of speech and features.

    Stage 1 of the grammar checker described in docs/ROADMAP.md. A word is
    known only if it is listed here, or is a regular form of a listed word:
    the plural of a noun, the -s, past and other forms of a verb are derived
    by the rules at the end, and irregular ones are listed beside the word.

    Agreement between a subject and its verb is carried in one feature term,
    agr(First, Third, SgNot2), each slot y or n:

        First    the subject is first person singular       (I)
        Third    it is third person singular                (he, the dog)
        SgNot2   it is singular and not second person       (I, he, the dog)

    A subject has all three bound; a verb form binds only the slots it cares
    about, so that every English agreement fact, the irregular forms of be
    among them, is one unification:

        I       agr(y,n,y)          chases  agr(_,y,_)      am    agr(y,n,y)
        he      agr(n,y,y)          chase   agr(_,n,_)      is    agr(_,y,_)
        you     agr(n,n,n)          chased  agr(_,_,_)      are   agr(n,n,_)
        they    agr(n,n,n)                                  was   agr(_,_,y)
                                                            were  agr(_,_,n)
*/

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

% irregular_plural(Singular, Plural).
irregular_plural(man, men).       irregular_plural(woman, women).
irregular_plural(child, children). irregular_plural(person, people).
irregular_plural(mouse, mice).    irregular_plural(foot, feet).
irregular_plural(tooth, teeth).   irregular_plural(goose, geese).
irregular_plural(sheep, sheep).   irregular_plural(fish, fish).
irregular_plural(leaf, leaves).

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

/* ---------------- determiners ---------------- */

% det(Word, Number, Sound): Number is sg, pl or unbound for either; Sound is
% the initial sound the next word must have, vowel or consonant, or unbound.
det(the,   _,  _).
det(a,     sg, consonant).
det(an,    sg, vowel).
det(this,  sg, _).   det(that,  sg, _).
det(these, pl, _).   det(those, pl, _).
det(every, sg, _).   det(each,  sg, _).
det(some,  pl, _).   det(many,  pl, _).   det(several, pl, _).
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

prep(in). prep(on). prep(under). prep(near). prep(behind). prep(with).
prep(without). prep(from). prep(to). prep(into). prep(over). prep(by).
prep(for). prep(at). prep(across).

adv(quickly). adv(slowly). adv(quietly). adv(loudly). adv(happily).
adv(sadly). adv(often). adv(always). adv(never). adv(sometimes).
adv(today). adv(yesterday). adv(again). adv(carefully). adv(well).
adv(furiously).

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
verb(push,   [trans]).            verb(open,   [trans]).
verb(close,  [trans]).            verb(visit,  [trans]).
verb(help,   [trans]).            verb(want,   [trans]).
verb(need,   [trans]).            verb(know,   [trans]).
verb(bite,   [trans]).            verb(hear,   [trans]).
verb(build,  [trans]).            verb(paint,  [intrans, trans]).
verb(stop,   [intrans, trans]).   verb(give,   [ditrans]).
verb(send,   [trans, ditrans]).   verb(show,   [trans, ditrans]).
verb(bring,  [trans, ditrans]).   verb(tell,   [ditrans]).
verb(buy,    [trans, ditrans]).   verb(teach,  [trans, ditrans]).

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
irregular_past(stop, stopped).

% be is the copula, and every one of its forms is irregular.
% be_form(Word, Agr).
be_form(am,   agr(y, n, y)).
be_form(is,   agr(_, y, _)).
be_form(are,  agr(n, n, _)).
be_form(was,  agr(_, _, y)).
be_form(were, agr(_, _, n)).

/* ---------------- forms ---------------- */

% noun_form(?Word, -Singular, -Number)
noun_form(Word, Sg, sg) :- noun(Sg), Word = Sg.
noun_form(Word, Sg, pl) :- noun(Sg), plural(Sg, Word).

plural(Sg, Pl) :- irregular_plural(Sg, Pl0), !, Pl = Pl0.
plural(Sg, Pl) :- s_form(Sg, Pl).

% verb_form(?Word, -Base, -Agr): the present forms agree with the subject,
% the past form agrees with any.
verb_form(Word, Base, agr(_, y, _)) :- verb(Base, _), s_form(Base, Word).
verb_form(Word, Base, agr(_, n, _)) :- verb(Base, _), Word = Base.
verb_form(Word, Base, agr(_, _, _)) :- verb(Base, _), past(Base, Word).

past(Base, Past) :- irregular_past(Base, P), !, Past = P.
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
