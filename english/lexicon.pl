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
% Entry, or irregular_plural, irregular_form, base_participle or doubles,
% for WordNet's irregular forms; or name, for a word the sentence capitalizes, which is a
% name for that check whether the lexicon lists it or not; see names/3 in
% check.pl. The open classes and the spelling rules below each end
% with a clause that reads it.
:- dynamic(guessed/2).

% WordNet, as english/wordnet.pl gives it when english/wordnet_check.pl
% loads it; declared here so that without it these simply fail.
:- dynamic(wn_noun/1).
:- dynamic(wn_verb/2).
:- dynamic(wn_adj/1).
:- dynamic(wn_adv/1).
:- dynamic(wn_irregular/3).
:- dynamic(wn_name/1).
:- dynamic(wn_mass/1).
:- dynamic(wn_person/1).

% agr_of(+Number, -Agr): the agreement of a third-person noun phrase.
agr_of(sg, agr(n, y, y)).
agr_of(pl, agr(n, n, n)).

/* ---------------- nouns ---------------- */

% noun(Singular): a count noun whose plural follows the rules below.
noun(dog). noun(cat). noun(bird). noun(horse). noun(cow). noun(fox).
noun(lion). noun(tiger). noun(rabbit). noun(snake). noun(fish). noun(sheep).
noun(man). noun(woman). noun(child). noun(person). noun(boy). noun(girl).
% visit and walk are verbs too, and a noun here as WordNet has them, "such
% a visit", "took a walk"; a word the lexicon lists is not looked up in
% WordNet, so without these they had no noun. Not the other lexicon verbs
% WordNet has as nouns: measured on 2026-10-16, giving all forty a noun
% let thirteen faults through, "Alice wants swim" among them.
noun(visit). noun(walk).
noun(baby). noun(friend). noun(teacher). noun(student). noun(doctor).
noun(farmer). noun(king). noun(queen). noun(neighbour). noun(artist).
% kind is an adjective as well, "a kind man", and a word listed here is not
% looked up in WordNet, so its noun is listed too: "a kind of bird".
noun(kind).
noun(mouse). noun(foot). noun(tooth). noun(goose).
noun(house). noun(garden). noun(park). noun(city). noun(village). noun(road).
noun(river). noun(forest). noun(hill). noun(school). noun(library).
noun(kitchen). noun(room). noun(table). noun(chair). noun(door).
noun(window). noun(box). noun(bag). noun(book). noun(letter). noun(story).
noun(front). noun(top).
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
noun(night). noun(day). noun(week). noun(month). noun(year). noun(morning).
noun(evening). noun(afternoon).
% Words WordNet is too old to have, listed as the news uses them:
% "the largest extrasolar planet or exoplanet".
noun(exoplanet).
noun(Sg) :- guessed(noun, Sg).

% mass(Noun): a noun that can stand in the singular with no determiner,
% "water boils", "we ate dinner", and take some or much there, "some
% homework": a substance, an activity or game, a meal, and a place or time
% taken for what goes on there, "after school", "at night". Most can be counted
% as well, "a coffee", "a big dinner", which the grammar also allows.
% WordNet does not say which nouns these are, so they are listed, WordNet's
% own words among them: water, milk, rain, snow and work are not in noun/1,
% because a word listed there is never looked up in WordNet, and each of
% them is a verb as well.
mass(water). mass(milk). mass(rain). mass(snow). mass(work).
mass(bread). mass(tea). mass(coffee). mass(rice). mass(food). mass(music).
mass(homework). mass(advice). mass(information). mass(furniture).
mass(football). mass(breakfast). mass(lunch). mass(dinner).
mass(school). mass(church). mass(college). mass(bed). mass(night).
mass(office). mass(hospital). mass(prison). mass(court). mass(town).
mass(english). mass(french). mass(german). mass(spanish). mass(italian).
mass(latin). mass(greek). mass(russian). mass(chinese). mass(japanese).

% The rest by kind, each kind listed whole. They were chosen on 2026-09-30,
% after the second corpus had shown cancer, television and service standing
% bare; the kinds are what a learner's dictionary marks uncountable, and
% the corpus's words are three of 113.
%
% Drinks, and foods mostly eaten as a substance:
mass(beer). mass(wine). mass(juice). mass(lemonade). mass(soup).
mass(meat). mass(cheese). mass(butter). mass(pasta). mass(flour).
mass(honey). mass(jam). mass(chocolate). mass(fruit). mass(salad).
% Qualities, feelings and states:
mass(knowledge). mass(wisdom). mass(love). mass(hate). mass(fear).
mass(anger). mass(joy). mass(happiness). mass(sadness). mass(beauty).
mass(courage). mass(freedom). mass(peace). mass(justice). mass(health).
mass(wealth). mass(luck). mass(fun). mass(safety). mass(violence).
mass(poverty). mass(pollution). mass(weather). mass(traffic).
% What is done or had, named as a whole:
mass(help). mass(progress). mass(research). mass(evidence). mass(news).
mass(money). mass(energy). mass(power). mass(space). mass(time).
mass(life). mass(death). mass(education). mass(service). mass(experience).
mass(history). mass(nature). mass(travel). mass(transport).
mass(equipment). mass(luggage). mass(baggage). mass(clothing).
mass(software). mass(housework). mass(employment). mass(unemployment).
mass(doubt). mass(use). mass(custody).
% Fields of study and work:
mass(science). mass(art). mass(mathematics). mass(physics).
mass(chemistry). mass(biology). mass(geology). mass(geography).
mass(medicine). mass(law). mass(literature). mass(poetry).
mass(philosophy). mass(economics). mass(politics). mass(business).
mass(industry). mass(agriculture). mass(engineering). mass(architecture).
mass(religion). mass(technology).
% Sports and games:
mass(tennis). mass(golf). mass(chess). mass(baseball). mass(basketball).
mass(cricket). mass(rugby). mass(soccer). mass(hockey). mass(polo).
mass(volleyball). mass(swimming).
% Broadcasting:
mass(television). mass(radio).
% Illnesses:
mass(cancer). mass(flu). mass(influenza). mass(malaria). mass(diabetes).
mass(pneumonia). mass(tuberculosis). mass(measles). mass(cholera).
mass(asthma). mass(arthritis).
% And a noun WordNet places whose most frequent sense is a substance, which
% tools/gen_wordnet.py writes as wn_mass/1: iron, sand, glass, oxygen. A
% word the lexicon lists is never one of these, as it is not guessed.
mass(W) :- guessed(noun, W), wn_mass(W).

% person(Noun): a noun for a person, which may stand bare in the singular
% where it names an office, after be or beside a name, "he was chairman of
% the board", "Mukesh Ambani, chairman of Reliance Industries"; see
% role_np//3 in grammar.pl. The lexicon's own are listed; the rest are
% WordNet's, the nouns whose most frequent sense is in its category of
% people, which tools/gen_wordnet.py writes as wn_person/1.
person(man). person(woman). person(child). person(person). person(boy).
person(girl). person(baby). person(friend). person(teacher).
person(student). person(doctor). person(farmer). person(king).
person(queen). person(neighbour). person(artist).
person(W) :- guessed(noun, W), wn_person(W).

% organisation(Noun): a noun for a company or a body, which news puts
% before its name with no determiner, as it puts a person's title:
% "public relations firm Davis, Bain, and Associates", "diamond giant De
% Beers"; see title_before_name/1 in grammar.pl. After a name, the noun
% and the name make one, which stands bare as a name does, "manager of
% Millwall football club"; see named_body/1. Listed, as WordNet's
% category of groups is not generated.
organisation(firm). organisation(company). organisation(group).
organisation(giant). organisation(conglomerate). organisation(agency).
organisation(bank). organisation(airline). organisation(carrier).
organisation(maker). organisation(manufacturer). organisation(retailer).
organisation(publisher). organisation(studio). organisation(network).
organisation(label). organisation(band). organisation(broadcaster).
organisation(club). organisation(team). organisation(party).

% time_noun(Noun): a noun that makes an adverb of time with last, next,
% this, every or each before it, "last night", "every day"; see
% adverbial_np/2 in grammar.pl. time, summer, winter, spring and autumn are
% WordNet's, as each is a verb there too.
time_noun(night). time_noun(day). time_noun(week). time_noun(month).
time_noun(year). time_noun(morning). time_noun(evening).
time_noun(afternoon). time_noun(weekend). time_noun(time).
time_noun(summer). time_noun(winter). time_noun(spring). time_noun(autumn).

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
proper(W) :- guessed(name, W).

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

% The reflexive pronouns stand only where an object does, "blew himself
% up", "Alice saw herself", and never as a subject, "himself sleeps". Who
% they stand for is not checked, so "Alice saw myself" passes: the subject
% does not reach the object here, and the agreement has no gender, so
% "Alice saw himself" could not be refused either way. Settled by Hans on
% 2026-10-16, as a known cost. Straight after a subject one stresses it,
% "the king himself came", and agrees with it; see emphatic//5 in
% grammar.pl.
pronoun(W, Agr, obj) :- reflexive(W, Agr).

reflexive(myself,     agr(y, n, y)).
reflexive(yourself,   agr(n, n, n)).
reflexive(himself,    agr(n, y, y)).
reflexive(herself,    agr(n, y, y)).
reflexive(itself,     agr(n, y, y)).
reflexive(oneself,    agr(n, y, y)).
reflexive(ourselves,  agr(n, n, n)).
reflexive(yourselves, agr(n, n, n)).
reflexive(themselves, agr(n, n, n)).

% The indefinite pronouns are third person singular, and one form serves
% for subject and object: "nobody answered", "I saw nobody". WordNet lists
% some as nouns, "a nobody", which the lexicon's entry replaces.
pronoun(W, agr(n, y, y), _) :- indefinite(W).

indefinite(nobody).   indefinite(somebody).  indefinite(anybody).
indefinite(everybody). indefinite(someone).  indefinite(anyone).
indefinite(everyone). indefinite(nothing).   indefinite(something).
indefinite(anything). indefinite(everything).

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
det(much,  mass, _).  det(such,  pl, _).
det(few,   pl, _).   det(no,    _,  _).   det(any,   _,  _).
det(either, sg, _).  det(neither, sg, _). det(both,  pl, _).
det(my,    _,  _).   det(your,  _,  _).   det(his,     _,  _).
det(its,   _,  _).   det(our,   _,  _).   det(their,   _,  _).
det(W,     Num, _) :- number_word(W, Num).

% her is both a determiner and an object pronoun: "her dog", "saw her".
det(her,   _,  _).

% number_word(Word, Number): a number, which is a determiner, "six dogs", or
% a noun phrase of its own, "the shop closes at six". One is singular and
% every other number plural; a number written in digits, 6 or 3.5, is a
% word of its own, see words/2 in check.pl.
number_word(one, sg).
number_word(W, pl) :- number_name(W).
number_word(W, Num) :-
    digits(W),
    ( W == '1' -> Num = sg ; Num = pl ).

% month(Word): a month, for dates; see date//1 in grammar.pl. Capitalized,
% each is a name as well, "in January".
month(january). month(february). month(march). month(april). month(may).
month(june). month(july). month(august). month(september).
month(october). month(november). month(december).

% weekday(Word): a day of the week, which may go before a date with the,
% "Thursday the 2 August".
weekday(monday). weekday(tuesday). weekday(wednesday). weekday(thursday).
weekday(friday). weekday(saturday). weekday(sunday).

% time_word(Word): a time of day in digits, 13:44, which words/2 in
% check.pl keeps as one word; meridiem(Word), a.m. or p.m.; and
% time_zone(Word), a zone that may follow a time, "13:44 UTC".
time_word(W) :-
    atom(W), atomic_list_concat([H, M], ':', W),
    catch(( atom_number(H, HN), atom_number(M, MN) ), _, fail),
    integer(HN), HN >= 0, HN =< 24, integer(MN), MN >= 0, MN =< 59.
meridiem('a.m.'). meridiem('p.m.').

% score(Word): two numbers in digits joined by a hyphen, 7-6, 1-4, which
% words/2 in check.pl keeps as one word from a hyphen or an en dash. Each
% is short, three digits or fewer, and has no 0 before it; otherwise the
% two are a catalogue number, a name's own, "the star GSC 02620-00648".
score(W) :-
    hyphened_digits(W, A, B), short_number(A), short_number(B).

% percentage(Word): a number and a per cent sign, "40%", which words/2 in
% check.pl keeps as one word.
percentage(W) :-
    atom(W), atom_concat(N, '%', W), N \== '', number_word(N, _).

catalogue_number(W) :-
    hyphened_digits(W, A, B), \+ ( short_number(A), short_number(B) ).

hyphened_digits(W, A, B) :-
    atom(W), atomic_list_concat([A, B], '-', W), digits(A), digits(B).

short_number(D) :-
    atom_length(D, N), N =< 3,
    \+ ( N > 1, sub_atom(D, 0, 1, _, '0') ).

% currency(Sign): a sign that goes before an amount, "$5", "US$5.1
% billion", "£20", which words/2 in check.pl keeps as a word.
currency('$'). currency('£'). currency('€').
time_zone(W) :- memberchk(W, [utc, gmt, bst, cet, cest, eet, eest, est, edt,
                              cst, cdt, mst, mdt, pst, pdt, aest, aedt, acst,
                              awst, ist, jst, nzst, nzdt]).

% digits(Word): a number written in digits, 91 or 3.5 or 1,000. Not an
% ordinal, 27th, which is an adjective; see ordinal/1.
digits(W) :-
    atom(W), atom_chars(W, [C|Cs]), digit(C),
    forall(member(X, Cs), ( digit(X) ; X == '.' ; X == ',' )).

% ordinal(Word): an ordinal written in digits, 27th, 1st, 2nd, 3rd, which
% words/2 in check.pl keeps as one word. It stands where an adjective
% does, "the 27th bishop", "Oregon's 5th district".
ordinal(W) :-
    atom(W), atom_chars(W, Cs), append(Ds, [A, B], Cs), Ds = [_|_],
    maplist(digit, Ds), atom_chars(S, [A, B]), memberchk(S, [st, nd, rd, th]).

number_name(two). number_name(three). number_name(four). number_name(five).
number_name(six). number_name(seven). number_name(eight). number_name(nine).
number_name(ten). number_name(eleven). number_name(twelve).
number_name(thirteen). number_name(fourteen). number_name(fifteen).
number_name(sixteen). number_name(seventeen). number_name(eighteen).
number_name(nineteen). number_name(twenty). number_name(thirty).
number_name(forty). number_name(fifty). number_name(sixty).
number_name(seventy). number_name(eighty). number_name(ninety).

% big_number(Word): a number that needs one before it, "a hundred", "two
% thousand"; see determiner//3 in grammar.pl.
big_number(hundred). big_number(thousand). big_number(million).
big_number(billion). big_number(trillion). big_number(dozen).

digit(C) :- char_type(C, digit(_)).

/* ---------------- adjectives, prepositions, adverbs ---------------- */

adj(big). adj(small). adj(little). adj(large). adj(old). adj(young).
adj(new). adj(good). adj(bad). adj(happy). adj(sad). adj(angry).
adj(tired). adj(hungry). adj(quiet). adj(loud). adj(fast). adj(slow).
adj(red). adj(blue). adj(green). adj(yellow). adj(black). adj(white).
adj(brown). adj(tall). adj(short). adj(long). adj(warm). adj(cold).
adj(clever). adj(kind). adj(brave). adj(funny). adj(strange). adj(empty).
adj(beautiful). adj(ugly). adj(honest). adj(orange). adj(early). adj(late).
adj(colorless).
adj(extrasolar).
adj(A) :- guessed(adj, A).
adj(A) :- ordinal(A).
% A measure before a noun, a number and a singular noun joined by a hyphen,
% read as one adjective: "a two-day trip", "remanded to 2-day police
% custody", where the number alone would be taken for the determiner.
adj(A) :- measure_adj(A).

measure_adj(A) :-
    atom(A), sub_atom(A, _, _, _, '-'),
    atomic_list_concat([N, U], '-', A),
    ( digits(N) ; number_word(N, _) ), noun_form(U, _, sg).

prep(in). prep(on). prep(under). prep(near). prep(behind). prep(with).
prep(without). prep(from). prep(to). prep(into). prep(over). prep(by).
prep(for). prep(at). prep(across). prep(of).
prep(after). prep(before). prep(during). prep(through). prep(between).
prep(around). prep(about). prep(against). prep(since). prep(until).
prep(along). prep(among). prep(above). prep(below). prep(beside).
prep(inside). prep(outside). prep(toward). prep(towards). prep(within).
prep(beyond). prep(throughout). prep(underneath).
prep(via).

% bare_pp(Prep, Noun): a countable noun that stands bare after one
% preposition, in a set phrase: "on trial", "on foot", "by email", "by
% car", "via email". See pp//5 in grammar.pl.
bare_pp(on, trial). bare_pp(on, foot). bare_pp(on, duty).
bare_pp(on, strike). bare_pp(on, holiday). bare_pp(on, leave).
bare_pp(by, email). bare_pp(by, phone). bare_pp(by, telephone).
bare_pp(by, mail). bare_pp(by, post). bare_pp(by, letter).
bare_pp(by, car). bare_pp(by, bus). bare_pp(by, train).
bare_pp(by, plane). bare_pp(by, boat). bare_pp(by, taxi).
bare_pp(by, bicycle). bare_pp(by, hand).
bare_pp(via, email). bare_pp(via, phone). bare_pp(via, telephone).
bare_pp(via, satellite).

% particle(Word): a preposition that may stand after a verb with nothing
% after it, "sworn in", "carried on", "came by"; see modifiers//5 in
% grammar.pl.
particle(in). particle(on). particle(over). particle(through).
particle(along). particle(around). particle(about). particle(across).
particle(by).
% adv_particle(Word): an adverb that goes with a verb and may stand before
% its object, "picked up the box", "put forth the proposal"; see
% complements//7 in grammar.pl. None is a preposition, so the phrase is
% not read again as one.
adv_particle(up). adv_particle(down). adv_particle(out). adv_particle(off).
adv_particle(away). adv_particle(back). adv_particle(forth).
% as is listed because WordNet has it as a noun, the Roman coin, and with
% nothing else knowing it "best known as the chairperson" became a noun
% phrase headed by as once a participle could stand before a noun, and
% one corpus sentence took fifty seconds to be refused instead of one.
prep(as).

% prep_pair(First, Second): a preposition of two words, "as of the
% census", "out of the box", "because of the rain"; see preposition//1
% in grammar.pl. The pair is read only before a noun phrase, and does
% not make its first word known on its own: out keeps the adverb and
% the adjective WordNet gives it, "the lights went out", which a word
% the lexicon knows is never looked up for.
prep_pair(as, of).        prep_pair(out, of).       prep_pair(because, of).
prep_pair(instead, of).   prep_pair(according, to). prep_pair(due, to).
prep_pair(next, to).      prep_pair(prior, to).     prep_pair(close, to).

% prep_triple(First, Second, Third): a preposition of three words with a
% noun inside that takes no determiner there, "as part of the project",
% "in front of the house", "on behalf of the club". The noun keeps
% whatever else it is, as a pair's first word does.
prep_triple(as, part, of).     prep_triple(in, front, of).
prep_triple(on, top, of).      prep_triple(in, charge, of).
prep_triple(on, behalf, of).   prep_triple(in, spite, of).
prep_triple(in, addition, to). prep_triple(in, place, of).

adv(quickly). adv(slowly). adv(quietly). adv(loudly). adv(happily).
adv(sadly). adv(often). adv(always). adv(never). adv(sometimes).
adv(today). adv(yesterday). adv(again). adv(carefully). adv(well).
adv(furiously). adv(early). adv(late).
% Prepositions and conjunctions that WordNet has as adverbs too, "never seen
% before", "he left, though": a listed word is never looked up there, so
% the adverb is listed here with them.
adv(after). adv(before). adv(through). adv(between). adv(around).
adv(about). adv(along). adv(above). adv(below). adv(inside). adv(outside).
adv(within). adv(beyond). adv(throughout). adv(underneath). adv(though).
adv(quite). adv(rather). adv(too). adv(really). adv(fairly).
adv(extremely).

% degree(Word): a word that goes before an adjective and says how much,
% "very old", "quite happy". Those that are adverbs as well are listed as
% adverbs above, since a word listed here is never looked up in WordNet.
degree(very). degree(quite). degree(rather). degree(too).
degree(really). degree(fairly). degree(extremely).

% frequency(Word): an adverb of time or frequency, which may stand before
% the verb, "has already eaten", "never sleeps"; see pre_adverbs//1 in
% grammar.pl. Any adverb in -ly may too. Most are WordNet's.
frequency(never). frequency(always). frequency(often).
frequency(sometimes). frequency(already). frequency(just).
frequency(still). frequency(also). frequency(ever). frequency(even).
frequency(only). frequency(seldom). frequency(rarely). frequency(usually).
adv(A) :- guessed(adv, A).

/* ---------------- conjunctions ---------------- */

% coordinator(Word): joins two clauses as equals, "I like coffee but my
% brother prefers tea". and also joins noun phrases, in grammar.pl.
coordinator(and). coordinator(but). coordinator(or). coordinator(nor).

% correlative(Word, Conjunction): a word before the first of a list that
% says which conjunction joins it: "either the dog or the cat", "neither
% sleeps nor eats", "both the dog and the cat". Each is a determiner too.
correlative(either, or). correlative(neither, nor). correlative(both, and).

% subordinator(Word): opens a clause that goes with another, before it or
% after it: "he opened the window because the room was hot", "if it rains
% we stay". so and while are left out: listing them would lose WordNet's
% so, "so happy", and while, "a while".
subordinator(because). subordinator(although). subordinator(though).
subordinator(if). subordinator(unless). subordinator(since).
subordinator(until). subordinator(before). subordinator(after).
subordinator(when).

/* ---------------- verbs ---------------- */

% verb(Base, Frames): Frames lists what the verb takes after it:
%   intrans   nothing            the dog sleeps
%   trans     one noun phrase    the dog chases a cat
%   ditrans   two noun phrases   alice gives the dog a bone
% and pred, obj_pred, clause, inf, obj_inf and ing, which complements//7
% in grammar.pl sets out.
verb(sleep,  [intrans]).               verb(bark,   [intrans]).
verb(run,    [intrans]).               verb(walk,   [intrans, trans]).
verb(swim,   [intrans]).               verb(laugh,  [intrans]).
verb(cry,    [intrans]).               verb(smile,  [intrans]).
verb(sing,   [intrans, trans]).        verb(dance,  [intrans]).
verb(fly,    [intrans]).               verb(arrive, [intrans]).
verb(wait,   [intrans]).               verb(play,   [intrans, trans]).
verb(eat,    [intrans, trans]).        verb(drink,  [intrans, trans]).
verb(read,   [intrans, trans]).        verb(write,  [intrans, trans, ditrans]).
verb(chase,  [trans]).                 verb(see,    [trans, clause]).
verb(like,   [trans, inf, ing]).       verb(love,   [trans, inf, ing]).
verb(hate,   [trans, inf, ing]).       verb(find,   [trans, obj_pred, clause]).
verb(lose,   [trans]).                 verb(carry,  [trans]).
verb(watch,  [intrans, trans]).        verb(catch,  [trans]).
verb(push,   [trans]).                 verb(open,   [intrans, trans]).
verb(close,  [intrans, trans]).        verb(visit,  [trans]).
verb(help,   [trans, obj_inf]).        verb(want,   [trans, inf, obj_inf]).
verb(need,   [trans, inf, obj_inf]).   verb(know,   [trans, clause]).
verb(bite,   [trans]).                 verb(hear,   [trans, clause]).
verb(build,  [trans]).                 verb(paint,  [intrans, trans, obj_pred]).
verb(stop,   [intrans, trans, ing]).   verb(give,   [ditrans]).
verb(send,   [trans, ditrans]).        verb(show,   [trans, ditrans]).
verb(bring,  [trans, ditrans]).        verb(tell,   [trans, ditrans, obj_inf]).
verb(buy,    [trans, ditrans]).        verb(teach,  [trans, ditrans, obj_inf]).
verb(have,   [trans]).                 verb(please, [intrans, trans]).
verb(do,     [trans]).
verb(Base, Frames) :- guessed(verb(Frames), Base).

% extra_frame(Base, Frame): a frame WordNet does not give the verb, which
% complements//7 in grammar.pl sets out:
%   obj_as    a noun phrase, as, and an adjective
%             they described the prospects as grim
%   obj_ing   a noun phrase and an -ing verb phrase, read in the passive
%             only: the planet was discovered orbiting the star
%   yet_inf   yet and a to-infinitive, after have
%             the body has yet to be recovered
%   obj_bare  a noun phrase and a bare infinitive, active only
%             monday saw the new edition go online, she made the dog sleep
extra_frame(describe, obj_as).   extra_frame(regard, obj_as).
extra_frame(view, obj_as).       extra_frame(see, obj_as).
extra_frame(define, obj_as).     extra_frame(portray, obj_as).
extra_frame(depict, obj_as).     extra_frame(characterize, obj_as).
extra_frame(characterise, obj_as). extra_frame(label, obj_as).
extra_frame(classify, obj_as).   extra_frame(treat, obj_as).
extra_frame(consider, obj_as).   extra_frame(rate, obj_as).
extra_frame(discover, obj_ing).  extra_frame(find, obj_ing).
extra_frame(see, obj_ing).       extra_frame(hear, obj_ing).
extra_frame(watch, obj_ing).     extra_frame(notice, obj_ing).
extra_frame(spot, obj_ing).      extra_frame(catch, obj_ing).
extra_frame(observe, obj_ing).   extra_frame(leave, obj_ing).
extra_frame(keep, obj_ing).
extra_frame(have, yet_inf).
extra_frame(see, obj_bare).      extra_frame(hear, obj_bare).
extra_frame(watch, obj_bare).    extra_frame(make, obj_bare).
extra_frame(let, obj_bare).      extra_frame(feel, obj_bare).
extra_frame(notice, obj_bare).   extra_frame(observe, obj_bare).
extra_frame(help, obj_bare).

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
irregular_past(do, did).
irregular_past(Base, Past) :- guessed(irregular_form, Base-Past).

% irregular_participle(Base, Participle): the en form, where it is not the
% past: "has eaten", not "has ate".
irregular_participle(run, run).       irregular_participle(swim, swum).
irregular_participle(sing, sung).     irregular_participle(fly, flown).
irregular_participle(eat, eaten).     irregular_participle(drink, drunk).
irregular_participle(write, written). irregular_participle(see, seen).
irregular_participle(know, known).    irregular_participle(bite, bitten).
irregular_participle(give, given).    irregular_participle(show, shown).
irregular_participle(do, done).
irregular_participle(Base, Base) :- guessed(base_participle, Base).
irregular_participle(Base, P) :- guessed(irregular_form, Base-P).

% irregular_third(Base, Form): the -s form, where the rule does not make it.
irregular_third(have, has).
irregular_third(do, does).

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

% plural_modifier(Noun): a plural that stands before another noun, as a
% singular does, "human rights violations", "the foreign affairs
% committee", "a sports car". Only these: any plural there would read
% "the cats chase dogs" as the noun phrase "the cats chase" and the verb
% "dogs".
plural_modifier(rights). plural_modifier(affairs). plural_modifier(sports).
plural_modifier(arms). plural_modifier(sales). plural_modifier(savings).
plural_modifier(customs). plural_modifier(goods). plural_modifier(relations).
plural_modifier(communications). plural_modifier(operations).
plural_modifier(services). plural_modifier(systems). plural_modifier(games).
plural_modifier(weapons). plural_modifier(drugs). plural_modifier(women).
plural_modifier(children). plural_modifier(news). plural_modifier(earnings).

% noun_form(?Word, -Singular, -Number)
noun_form(Word, Sg, sg) :- noun(Sg), Word = Sg.
noun_form(Word, Sg, pl) :- noun(Sg), plural(Sg, Word).
noun_form(Word, Word, pl) :- plural_noun(Word).

% plural_noun(Word): a noun that is plural and has no singular, "the police
% have", "cattle graze". WordNet lists police as a noun and a verb, and
% gives no number, so it was singular, and "the police have reported" was
% refused. Listed, police is no longer looked up there, and "to police the
% streets" has no verb, the cost of any word the lexicon lists.
plural_noun(police). plural_noun(cattle). plural_noun(vermin).

plural(Sg, Pl) :- irregular_plural(Sg, Pl0), !, Pl = Pl0.
plural(Sg, Pl) :- s_form(Sg, Pl).

% participle_word(+Word): an -ing or -en form of a verb, "chasing",
% "chased", "eaten", whatever else the word may be. participle_adj(+Word):
% one that may stand before a noun as an adjective does, "the presiding
% bishop", "a painted house", "managing director": not an adjective or a
% noun as well, which are read as those already, "tired", "building".
% Each answer is kept per word while the placements stand, since
% verb_form/3 with the word given walks every verb for each of its forms,
% a millisecond, and the grammar asks at every word a noun phrase could
% start at and after every noun: without this one corpus sentence went
% from a third of a second to fifty. with_placements/3 in guess.pl clears
% them with the placements.
:- dynamic(participle_memo/3).

participle_word(W) :- memo(word, W, ( verb_form(W, _, ing) ; verb_form(W, _, en) )).
participle_adj(W)  :- memo(adj, W, ( participle_word(W), \+ adj(W), \+ noun_form(W, _, _) )).

memo(Kind, W, _) :- participle_memo(Kind, W, Yes), !, Yes == yes.
memo(Kind, W, Goal) :-
    ( call(Goal) -> Yes = yes ; Yes = no ),
    assertz(participle_memo(Kind, W, Yes)),
    Yes == yes.

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

% ing(+Base, -Form): running, chasing, seeing, playing, dying.
ing(Base, Form) :-
    doubles(Base), !, atom_chars(Base, Cs), last(Cs, C),
    atomic_list_concat([Base, C, ing], Form).
ing(Base, Form) :- atom_concat(_, ee, Base), !, atom_concat(Base, ing, Form).
% die, lie, tie: dying, lying, tying. Without this die gave diing, and
% "dying" was found only as a form of dye, which WordNet has as
% transitive, so "dying of cancer" had no reading.
ing(Base, Form) :- atom_concat(Stem, ie, Base), !, atom_concat(Stem, ying, Form).
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

% degree_inflection(+Word, -Base, -Degree): Word is an adjective's
% comparative or superlative by the spelling rules, older, larger,
% happier, bigger, oldest, largest, happiest, biggest, and Base is the
% adjective it would be, which the caller checks. guess.pl reads it for a
% word the lexicon lacks and places the form as an adjective itself,
% since the lexicon derives no forms for an adjective.
degree_inflection(W, B, D) :-
    member(D-E, [comparative-er, superlative-est]),
    atom_concat(S0, E, W), atom_length(S0, N), N >= 2,
    (   B = S0
    ;   atom_concat(S0, e, B)
    ;   atom_concat(Si, i, S0), atom_concat(Si, y, B)
    ;   atom_chars(S0, Cs), append(Bs, [C, C], Cs), \+ vowel_letter(C),
        append(Bs, [C], Bs1), atom_chars(B, Bs1)
    ).

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
sound(Word, Sound) :- digits(Word), !, digits_sound(Word, Sound).
sound(Word, Sound) :-
    atom_chars(Word, [C|_]),
    ( vowel_letter(C) -> Sound = vowel ; Sound = consonant ).

% digits_sound(+Digits, -Sound): a number in digits as it is said, "an
% 1800 census", "a 1968 movie": eight, eleven and eighteen begin with a
% vowel, eleven and eighteen when they are the whole number or its first
% two of four figures, eighteen hundred.
digits_sound(W, vowel) :- atom_chars(W, ['8'|_]), !.
digits_sound(W, vowel) :-
    atom_chars(W, [A, B|Rest]), atomic_list_concat([A, B], P),
    memberchk(P, ['11', '18']), ( Rest == [] ; length(Rest, 2) ), !.
digits_sound(_, consonant).

sound_exception(hour, vowel).        sound_exception(honest, vowel).
sound_exception(university, consonant). sound_exception(unicorn, consonant).
sound_exception(uniform, consonant). sound_exception(one, consonant).

vowel_letter(a). vowel_letter(e). vowel_letter(i). vowel_letter(o).
vowel_letter(u).
