/*  english/grammar.pl -- English sentences, as a DCG.

    sentence(Tree, V0, V) parses a list of words into a tree. V0 and V are a
    difference list of agreement violations, threaded beside the words:

        phrase(sentence(T, [], []), Words)     is grammatical
        phrase(sentence(T, Vs, []), Words)     parses, and Vs says what
                                               disagrees

    The first is the checker: with the list closed, a violation cannot be
    recorded, so every agreement is enforced, by unification alone. The second
    is the diagnosis: the same rules, allowed to record where features did not
    unify. There is one grammar, not a strict one and a lenient one.

    A verb phrase is a chain of auxiliaries and then the verb: "might have
    been chased". Each auxiliary decides the form of the verb after it and
    which auxiliaries may follow it, so the chain comes out in English's
    order and no other; negation goes after the first, and a yes/no question
    puts the first before the subject.

    A relative clause or a wh-question has a gap: a noun phrase missing from
    where it would stand, "the cat that the dog chased _", "what did the dog
    chase _". The gap is threaded through the rules as G0 and G, gap
    while it is still to be placed and nogap once it has been, so a clause
    that must have one has it exactly once. It may stand for an object, or
    the object of a preposition; a missing subject is simpler, since the
    rest is only a verb phrase, and has rules of its own. No gap is placed
    inside a subject or in either half of an and, as English allows neither.
    When a preposition goes before the relative word, "the park in which
    the dog walks _", the gap is a whole prepositional phrase, ppgap, and
    only a prepositional phrase can place it.

    Recursion is on the right throughout: a noun phrase is followed by its
    prepositional phrases and relative clause, never built from a smaller
    noun phrase, since a rule such as np --> np, pp would make a DCG loop.
    See docs/ROADMAP.md.
*/

% agree(+What, ?X, ?Y, ?V0, ?V): X and Y agree, or, when the violation list
% is open, What records that they did not.
agree(_, X, Y, V, V) :- X = Y, !.
agree(What, _, _, [What|V], V).

% violation(+What, ?V0, ?V): What is recorded, which only the diagnosis can
% do; for the strict grammar this is a rule that fails.
violation(What, [What|V], V).

/* ---------------- sentences ---------------- */

% A statement; a yes/no question, the first verb before the subject and
% then what that verb takes, as in the statement: "does the dog bark", "is
% the dog happy"; and a wh-question.
sentence(T, V0, V) --> declarative(T, V0, V).
sentence(T, V0, V) --> question(T, nogap, nogap, V0, V).
sentence(T, V0, V) --> wh_question(T, V0, V).

% declarative(-Tree, V0, V): a statement, alone or joined to others.
declarative(T, V0, V) -->
    statement(S, nogap, nogap, V0, V1),
    clauses_after(S, T, V1, V).
% A gerund phrase is a subject too, singular, "wrangling between the
% teams may have yielded its first casualty", and only first in the
% sentence: inside one, "the dog sleeps after eating the cakes sleeps"
% would read with "eating the cakes" the subject of a clause after
% "after". It is entered only when an -ing form comes first, as after a
% preposition, see ing_ahead//0.
declarative(T, V0, V) -->
    gerund_statement(S, V0, V1),
    clauses_after(S, T, V1, V).

gerund_statement(s(ger(VP0), VP), V0, V) -->
    ing_ahead,
    verb_phrase(ing, 2, subject, VP0, nogap, nogap, V0, V1),
    { agr_of(sg, Agr) },
    verb_phrase(fin(Agr), 1, subject, VP, nogap, nogap, V1, V).
declarative(sub_first(C, S1, T), V0, V) -->
    [C], { subordinator(C) },
    statement(S1, nogap, nogap, V0, V1),
    optional_comma,
    statement(S2, nogap, nogap, V1, V2),
    clauses_after(S2, T, V2, V).

% A statement may open with a phrase of the kind that can follow the verb,
% an adverb, a prepositional phrase or a noun phrase of time, with a comma
% after it or none: "yesterday the dog barked", "in 2019, 978 people lived
% there", "last night the dog barked". The phrase goes with the statement
% after it, which may open with another. A word that only makes a number
% rough, "about", "nearly", is no adverb there, nor are "too" and "quite":
% "about the dog barked" is no sentence.
declarative(fronted(A, T), V0, V) -->
    fronted(A, V0, V1),
    optional_comma,
    declarative(T, V1, V).

fronted(adv(A), V, V) --> [A], { adv(A), \+ approximator(A), \+ inner_adverb(A) }.

% inner_adverb(Word): an adverb that qualifies a word inside the sentence
% and never opens one, "too", "quite". Other degree words can: "really,
% the dog barked", "rather, the dog slept".
inner_adverb(too). inner_adverb(quite).
fronted(PP, V0, V) --> pp(PP, nogap, nogap, V0, V).
fronted(npadv(D, N), V, V) --> [D, N], { adverbial_np(D, N) }.

% imperative(-Tree, V0, V): a command, its verb in the base form and no
% subject: "close the door", "please be quiet", "don't bark". check.pl reads
% a sentence this way only when it has no other reading, and cannot be read
% as a statement even with a word that disagrees, since with WordNet nearly
% every noun is a verb as well: "dog barks" is a singular noun without its
% determiner, not the command "dog the barks". A question with a fault
% does not count: "close the door" is not "does the door close" gone
% wrong.
imperative(imp(P1, Neg, VP, P2), V0, V) -->
    please(P1), imperative_not(Neg),
    base_ahead,
    verb_phrase(base, 5, imperative, VP, nogap, nogap, V0, V),
    please(P2).

% A request without a verb: a noun phrase and please, with a comma
% between them, "two cups of tea, please", "please, the bill". It is read
% on the same terms as a command, since please is a verb as well and
% "the dogs please" is a statement. The comma is what tells the two
% apart, so "a coffee please" is still the statement, with its verb
% disagreeing. please_ahead: a please is somewhere in what is left to
% read. A command is tried on every sentence nothing else reads, and
% without this the noun phrase was parsed for each of them before the
% please was missed, which cost the corpus run seventy seconds.
imperative(request(P1, NP, P2), V0, V) -->
    please_ahead,
    request_please(P1),
    noun_phrase(_, obj, NP, nogap, nogap, V0, V),
    request_please(P2),
    { P1 \== P2 }.

please_ahead(S, S) :- memberchk(please, S).

request_please(please) --> [please, ','].
request_please(please) --> [',', please].
request_please(none) --> [].

please(please) --> [please].
please(please) --> [',', please].
please(none) --> [].

% optional_comma: the comma English often puts between two clauses: "the
% dog barks, but the cat sleeps", "if it rains, the dog sleeps", "close the
% door, please". It is read only where a rule allows one; anywhere else a
% comma leaves the sentence with no reading.
optional_comma --> [','].
optional_comma --> [].

imperative_not(not) --> [do, not].
imperative_not(not) --> ['don\'t'].
imperative_not(none) --> [].

% base_ahead: the next word has a base form, so the verb is not blamed for
% being in another: "chases the dog" is no command at all.
base_ahead([W|S], [W|S]) :- ( verb_form(W, _, base) ; be_form(W, base) ), !.

% clauses_after(+First, -Tree, V0, V): the statement First alone, or joined
% to the statements after it, each by a conjunction: "I like coffee but my
% brother prefers tea", "he opened the window because the room was hot".
% A clause may also open with its subordinator, "because the room was hot
% he opened the window", which is the last rule for sentence//3. The chain
% is read left to right and nests on the right, so no rule calls itself on
% the left.
clauses_after(S, S, V, V) --> [].
clauses_after(S1, joined(C, S1, T), V0, V) -->
    optional_comma,
    [C], { coordinator(C) ; subordinator(C) },
    statement(S2, nogap, nogap, V0, V1),
    clauses_after(S2, T, V1, V).
% A semicolon joins two statements with no word between them, "Anglo's
% stake will jump to 85%; the government has an option".
clauses_after(S1, joined(';', S1, T), V0, V) -->
    [';'],
    statement(S2, nogap, nogap, V0, V1),
    clauses_after(S2, T, V1, V).

% statement(-Tree, G0, G, V0, V). The subject is never the gap.
statement(s(NP, VP), G0, G, V0, V) -->
    noun_phrase(Agr, subj, NP0, nogap, nogap, V0, V1),
    emphatic(Agr, E, V1, V2),
    { E == none -> NP = NP0 ; NP = emph(NP0, E) },
    verb_phrase(fin(Agr), 1, subject, VP, G0, G, V2, V).

% emphatic(+Agr, -Word, V0, V): a reflexive pronoun straight after a
% subject, which it stresses, "the king himself came", "who himself had
% been considered", and agrees with as the verb does: "they himself came"
% is refused. Only after a subject, since after an object "Alice saw the
% dog herself" stresses the subject and would be read as "the dog
% herself". Word is none when there is none.
emphatic(_, none, V, V) --> [].
emphatic(Agr, W, V0, V) -->
    [W], { reflexive(W, RAgr), agree(reflexive(W), RAgr, Agr, V0, V) }.

% question(-Tree, G0, G, V0, V): a yes/no question.
question(q(Tok, NP, Neg, Items), G0, G, V0, V) -->
    [Tok], { head_word(Tok, W, Neg0), head(W, Kind, Base, F),
             inverts(Kind, Tok, V0, V1) },
    noun_phrase(Agr, subj, NP, nogap, nogap, V1, V2),
    { form_ok(fin(Agr), subject, Tok, F, V2, V3) },
    after_subject(Neg0, Neg),
    rest(Kind, Base, Tok, fin(Agr), Items, G0, G, V3, V).

% Only an auxiliary, or be, goes before the subject; a verb needs do:
% "does the dog bark", not "barks the dog".
inverts(Kind, _, V, V) :- Kind \== lex.
inverts(lex, Tok, V0, V) :- violation(question_do(Tok), V0, V).

% In a question, not comes after the subject unless it is joined to the
% verb: "does the dog not bark", "doesn't the dog bark".
after_subject(none, not) --> [not].
after_subject(_, none) --> [].

% A wh-question asks for a noun phrase, or for a place, time, reason or
% manner. When it asks for the subject the rest is a verb phrase, "who
% chased the cat"; otherwise it is a yes/no question with the gap in it,
% "what did the dog chase _". Asking for a place needs no gap: "where does
% the dog sleep".
wh_question(wh(W, VP), V0, V) -->
    wh_phrase(W, Agr, Word, Case, V0, V1),
    { agree(case(Word), Case, subj, V1, V2) },
    verb_phrase(fin(Agr), 1, subject, VP, nogap, nogap, V2, V).
wh_question(wh(W, Q), V0, V) -->
    wh_phrase(W, _, _, _, V0, V1),
    question(Q, gap, nogap, V1, V).
wh_question(wh(whadv(A), Q), V0, V) -->
    [A], { wh_adverb(A) },
    question(Q, nogap, nogap, V0, V).
% A preposition may go before what is asked for, and the question then
% has a prepositional phrase missing: "in which park does the dog sleep
% _", "with whom did Alice walk _". Not who, as in a relative clause.
wh_question(wh(whpp(P, W), Q), V0, V) -->
    preposition(P), wh_phrase(W, _, Word, _, V0, V1), { Word \== who },
    question(Q, ppgap, nogap, V1, V).

% wh_phrase(-Tree, -Agr, -Word, -Case, V0, V): who, whom, what, or which or
% what before a noun, "which dogs".
wh_phrase(wh_pro(W), Agr, W, Case, V, V) -->
    [W], { wh_pronoun(W, Case), agr_of(sg, Agr) }.
wh_phrase(wh_np(D, N), Agr, D, _, V0, V) -->
    [D], { wh_det(D) },
    nominal(Num, _, _, N, V0, V),
    { agr_of(Num, Agr) }.

/* ---------------- noun phrases ---------------- */

% noun_phrase(-Agr, +Case, -Tree, G0, G, V0, V). Noun phrases joined by and
% are plural: "the dog and the cat chase", "Alice, Bob and Carol sing".
% Joined by or they agree with the last, as English does with the nearest:
% "the dog or the cats bark", "the dogs or the cat barks". A noun phrase can be the gap
% itself, taking no words, when one is waiting to be placed. A gap is never
% a subject, so it stands only where nothing agrees with it and any
% relative or question word may stand: whom in a subject's place is caught
% by the rules for a missing subject.
noun_phrase(_, _, gap, gap, nogap, V, V) --> [].
noun_phrase(Agr, Case, T, G, G, V0, V) --> np_list(Agr, Case, T, V0, V).

np_list(Agr, Case, T, V0, V) -->
    correlative_word(Pre, Cs),
    np_first(Case, T1, V0, V1),
    joined(np_item(Case), np_last(Case), Cs, Items, C, V1, V),
    { last(Items, Last-_), coord_agr(C, Last, Agr), pairs_values(Items, Ts),
      correlated(Pre, coord(C, [T1|Ts]), T) }.

% A noun phrase, or a list, and as well as with a noun phrase, set off by
% commas: "Ion, Ohanesian and Miscoci, as well as their guide, Mohamed
% Munaf, were under the protection", which agrees as the first does. It
% is closed by a comma, or the end, or the comma that closed the noun
% phrase's own appositive, "their guide, Mohamed Munaf,". Entered only
% when as well as is ahead.
noun_phrase(Agr, Case, as_well(T1, T2), G, G, V0, V) -->
    as_well_ahead,
    np_base(Agr, Case, T1, V0, V1),
    [',', as, well, as],
    as_well_rest(Case, T2, V1, V).

as_well_ahead(S, S) :- append(_, [as, well, as|_], S), !.

np_base(Agr, Case, T, V0, V) --> simple_np(Agr, Case, T, V0, V).
np_base(Agr, Case, T, V0, V) --> np_list(Agr, Case, T, V0, V).

as_well_rest(Case, T, V0, V, S0, S) :-
    phrase(noun_phrase(_, Case, T, nogap, nogap, V0, V), S0, S1),
    (   S1 = [','|S]
    ;   S1 == [], S = []
    ;   append(Read, S1, S0), last(Read, ','), S = S1
    ).

np_item(Case, A-T, V0, V) --> simple_np(A, Case, T, V0, V).
% The last of a list is no as well as phrase, which goes after the whole
% list, "Ion and Miscoci, as well as their guide", not after Miscoci.
np_last(Case, A-T, V0, V) -->
    noun_phrase(A, Case, T, nogap, nogap, V0, V), { T \= as_well(_, _) }.

coord_agr(and, _, agr(n, n, n)).
coord_agr(or, Agr, Agr).
coord_agr(nor, Agr, Agr).

% correlative_word(-Word, -Conjunctions): either, neither or both before a
% list, which fixes the conjunction that joins it, or nothing, and the
% list may take any. correlated/3 puts the word in the tree.
correlative_word(Pre, [C]) --> [Pre], { correlative(Pre, C) }.
correlative_word(none, [and, or, but]) --> [].

correlated(none, T, T) :- !.
correlated(Pre, T, corr(Pre, T)).

% np_first(+Case, -Tree, V0, V): the first of a list of noun phrases: a
% noun phrase, or a determiner with nouns after it set off by commas and
% no conjunction, "a politician, author" in "a politician, author and a
% member of the party", where the list's own conjunction comes later. The
% nouns agree with the determiner as under nominal_list.
np_first(Case, T, V0, V) --> simple_np(_, Case, T, V0, V).
np_first(_, np(det(D), coord(',', [N1|Ns])), V0, V) -->
    determiner(D, DNum, DSound),
    core_nominal(Num1, First, Head1, N1),
    comma_nominals(Items), { Items = [_|_] },
    { pairs_keys_values(Items, NumHeads, Ns),
      det_agrees_each([Num1-Head1|NumHeads], D, DNum, V0, V1),
      sound(First, Sound),
      agree(article(D, First), DSound, Sound, V1, V) }.

comma_nominals([(Num-Head)-N|Is]) -->
    [','], core_nominal(Num, _, Head, N), comma_nominals(Is).
comma_nominals([]) --> [].

% joined(:Item, :Last, +Conjunctions, -Items, -Conjunction, V0, V): what
% follows the first of a list: "and B", ", B and C", ", B, and C". Items
% after the first are separated by commas and the last is joined by the
% conjunction, with a comma before it or none, once there has been a
% comma. Item reads each but the last, and Last the last, which for a noun
% phrase may itself be a list: "the dog and the cat and the mouse". A
% comma is read only in a list, so "the dog, the cat" alone is no noun
% phrase. The rule is shared by noun phrases, nouns under one determiner
% and adjectives.
joined(Item, Last, Cs, [X], C, V0, V) -->
    [C], { memberchk(C, Cs) }, call(Last, X, V0, V).
joined(Item, Last, Cs, [X|Xs], C, V0, V) -->
    [','], call(Item, X, V0, V1),
    after_comma(Item, Last, Cs, Xs, C, V1, V).

after_comma(Item, Last, Cs, Xs, C, V0, V) --> joined(Item, Last, Cs, Xs, C, V0, V).
after_comma(_, Last, Cs, [X], C, V0, V) -->
    [',', C], { memberchk(C, Cs) }, call(Last, X, V0, V).
noun_phrase(Agr, Case, T, G, G, V0, V) -->
    simple_np(Agr, Case, T, V0, V).

simple_np(Agr, Case, pro(W), V0, V) -->
    [W], { pronoun(W, Agr, PCase),
           agree(case(W), PCase, Case, V0, V) }.
% An indefinite pronoun with a to-infinitive whose object it is,
% "something to eat", "had anything to do with the proposal", "nothing to
% do with it".
simple_np(Agr, _, inf_rel(pro(W), VP), V0, V) -->
    [W], { indefinite(W), pronoun(W, Agr, _) },
    [to], verb_phrase(base, 2, to, VP, gap, nogap, V0, V).
simple_np(Agr, _, name(N), V, V) -->
    name(N), { agr_of(sg, Agr) }.
simple_np(Agr, _, appos(name(N), NP), V0, V) -->
    name(N), [','], name_appositive(NP, V0, V), apposition_end,
    { agr_of(sg, Agr) }.
simple_np(Agr, _, np(nom(As, n(N), [])), V, V) -->
    plain_adjectives(As), name(N), { agr_of(sg, Agr) }.
simple_np(Agr, _, date(D), V, V) -->
    date(D), { agr_of(sg, Agr) }.
simple_np(Agr, _, time(T), V, V) -->
    time(T), { agr_of(sg, Agr) }.
simple_np(Agr, _, money(M), V, V) -->
    money(M), { agr_of(sg, Agr) }.
simple_np(Agr, _, num(W), V, V) -->
    [W], { number_word(W, Num), agr_of(Num, Agr) }, \+ [of].
% A quantity, of, and the noun phrase it is a part of, "many of the
% rockets", "eight of them", "some of the cake". The phrase agrees as the
% quantity does, or for some, all and their like as the noun phrase after
% of does: "some of the cake is", "some of the cakes are". A number
% alone is no noun phrase before of, as "saw two of the dogs" read with
% "of the dogs" on the verb.
% A percentage is a noun phrase, "jump from 45% to 85%", and takes of with
% what it is a part of, as a quantity does, and with a name or a title and
% a name as well, "40% of diamond giant De Beers"; it agrees as that does,
% "40% of the cake is", "40% of the dogs are".
simple_np(Agr, _, num(W), V, V) -->
    [W], { percentage(W), agr_of(sg, Agr) }, \+ [of].
simple_np(Agr, _, part(W, NP), V0, V) -->
    [W], { percentage(W) }, [of],
    percent_of(NP, Num, V0, V), { agr_of(Num, Agr) }.
simple_np(Agr, _, part(Q, NP), V0, V) -->
    [Q], { partitive(Q, QNum) }, [of],
    partitive_np(NP, Num0, V0, V),
    { QNum == inner -> Num = Num0 ; Num = QNum },
    { agr_of(Num, Agr) }.
simple_np(Agr, _, T, V0, V) -->
    det_np(Agr, T0, V0, V1), np_appositive(T0, T, V1, V).
% A multiple before a noun phrase with a determiner, "twice the size of
% Jupiter", "1.7 times the size", "three times the price"; the phrase
% agrees as the noun phrase does.
simple_np(Agr, _, mult(M, T), V0, V) -->
    multiple(M), det_np(Agr, T, V0, V).
simple_np(Agr, _, T, V0, V) -->
    nominal(Num, _, Head, N, V0, V1),
    { \+ names_only(N), \+ leads_number(N),
      (   ( title_before_name(N) ; named_body(N) ) -> V2 = V1
      ;   bare_ok(Head, Num, V1, V2)
      ),
      agr_of(Num, Agr) },
    np_appositive(np(N), T, V2, V).

% named_body(+Nominal): a name before a singular noun for a body, with
% nouns between or none, which is that body's name and stands bare as a
% name does: "manager of Millwall football club". Only such a noun, so
% "Alice saw Bob dog" is still refused.
named_body(nom([name(_)|_], n(Head), _)) :-
    noun_form(Head, _, sg), organisation(Head).

% partitive(Word, Number): a quantity that goes before of, and its
% number, or inner for one that takes the number of the noun phrase after
% of.
partitive(W, Num) :- number_word(W, Num).
partitive(many, pl). partitive(few, pl). partitive(several, pl).
partitive(both, pl).
partitive(each, sg). partitive(either, sg). partitive(neither, sg).
partitive(some, inner). partitive(all, inner). partitive(most, inner).
partitive(any, inner). partitive(none, inner). partitive(half, inner).
partitive(much, inner).

% partitive_np(-Tree, -Number, V0, V): what a quantity is a part of: a
% definite noun phrase, with the, a possessor or a demonstrative, "of the
% rockets", "of their seven encounters", or an object pronoun, "of them";
% not "two of a dog".
partitive_np(NP, Num, V0, V) -->
    det_np(Agr, NP, V0, V), { definite_np(NP), agr_of(Num, Agr) }.
partitive_np(pro(W), Num, V, V) --> [W], { partitive_pronoun(W, Num) }.

definite_np(np(poss(_), _)).
definite_np(np(det(D), _)) :-
    atomic_list_concat([W|_], ' ', D), definite_det(W, _).

percent_of(NP, Num, V0, V) --> partitive_np(NP, Num, V0, V).
percent_of(name(N), sg, V, V) --> name(N).
percent_of(np(N), Num, V0, V) -->
    nominal(Num, _, _, N, V0, V), { title_before_name(N) }.

partitive_pronoun(them, pl). partitive_pronoun(us, pl).
partitive_pronoun(you, pl). partitive_pronoun(it, sg).

% title_before_name(+Nominal): a singular noun for a person and the name
% straight after it, which news puts with no determiner: "musician Michael
% Jackson", "former Massachusetts governor Mitt Romney". The noun is one
% role_np/3 would take, so "Alice saw dog Rex" is still refused, or one
% for a company, "public relations firm Davis, Bain, and Associates",
% "diamond giant De Beers"; see organisation/1.
title_before_name(nom(_, n(Head), [name(_)|_])) :-
    noun_form(Head, _, sg), ( person(Head) ; organisation(Head) ), !.

% det_np(-Agr, -Tree, V0, V): a noun phrase with a determiner or a
% possessor before its noun, which is what may stand beside a name as an
% appositive.
det_np(Agr, np(det(D), N), V0, V) -->
    determiner(D, DNum, DSound),
    core_nominal(Num1, First, Head1, nom(As, n(Head1), [])),
    { copy_term(DNum, DNum1),
      det_agrees(D, Head1, DNum1, Num1, V0, V1),
      sound(First, Sound),
      agree(article(D, First), DSound, Sound, V1, V2) },
    noun_posts(Head1, Posts1, V2, V3),
    det_np_end(D, DNum, Num1, Head1, nom(As, n(Head1), Posts1), N, Agr, V3, V).

% det_np_end(+Det, ?DetNumber, +Number, +Head, +Nominal, -Tree, -Agr, V0, V):
% what follows the first noun after a determiner, once its phrases are
% read: its relative clause, and the noun phrase is that noun; or more
% nouns under the same determiner, "a doctor and teacher", "the
% municipality of Glarus Süd and canton of Glarus", where each noun may
% have phrases of its own. The phrases are read once, before the two are
% told apart, since reading them again for each would double the search
% at every noun phrase inside them; and the determiner is checked against
% the first noun before them, so that "an American television sitcom
% series" is not read on as the plural series, which "an" refuses only at
% the end.
det_np_end(_, _, Num, _, nom(As, H, Posts0), nom(As, H, Posts), Agr, V0, V) -->
    { agr_of(Num, Agr) },
    post_relative(Posts0, Agr, Rels, V0, V1),
    { H = n(Head), rel_fits(Head, Rels, V1, V),
      append(Posts0, Rels, Posts) }.
det_np_end(D, DNum, Num1, Head1, N1, coord(C, [N1|Ns]), Agr, V0, V) -->
    nouns_after(N1, Head1, Items, C, V0, V1),
    { pairs_keys_values(Items, NumHeads, Ns),
      det_agrees_each(NumHeads, D, DNum, V1, V),
      pairs_keys([Num1-Head1|NumHeads], Nums),
      coord_num(C, DNum, Nums, Num),
      agr_of(Num, Agr) }.
% nouns_after(+First, +Head, -Items, -Conjunction, V0, V): the nouns after
% the first under one determiner. A first noun with no phrases of its own
% begins a list as joined//7 reads it. One with phrases is joined to one
% more noun by and or or and no comma, "the municipality of Glarus Süd
% and canton of Glarus", so that "the wife of Mukesh Ambani, chairman and
% managing director" is not three nouns under the; and not after kind and
% its like, whose of already takes a list, "any kind of separation or
% break".
nouns_after(nom(_, _, []), _, Items, C, V0, V) -->
    joined(nom_item, nom_last, [and, or], Items, C, V0, V).
nouns_after(nom(_, _, [_|_]), Head, [X], C, V0, V) -->
    { \+ kind_noun(Head) },
    [C], { memberchk(C, [and, or]) },
    nom_last(X, V0, V).

% The before a name, "the Sernf", "the Hague", "the Rhine": a river, a
% place or a thing that has the in its name. Only the, as "a Sernf" is
% not English in the same way, and the name is singular.
det_np(Agr, np(det(the), nom([], n(N), [])), V, V) -->
    [the], name(N), { agr_of(sg, Agr) }.
det_np(Agr, np(poss(P), N), V0, V) -->
    possessive_ahead,
    possessor(P, V0, V1),
    nominal(Num, _, _, N, V1, V),
    { agr_of(Num, Agr) }.
% A possessor before a name that ends in a plural noun, "Jackson's MJJ
% Productions has terminated", singular as a name is, where the names
% before a noun read it as plural. Not before other names, which the
% names before a noun read already, "the People's Republic of China",
% and would read twice.
det_np(Agr, np(poss(P), nom([], n(N), [])), V0, V) -->
    possessive_ahead,
    possessor(P, V0, V),
    name(N), { plural_name(N), agr_of(sg, Agr) }.

plural_name(N) :-
    atomic_list_concat(Ws, ' ', N), last(Ws, W),
    noun_form(W, _, pl), \+ noun_form(W, _, sg).
% A possessor before a quantity, "Alice's three dogs", "the farmer's many
% cows", which the noun agrees with as it would with a determiner.
det_np(Agr, np(poss(P), nom([num(W)|As], n(Head), Posts)), V0, V) -->
    possessive_ahead,
    possessor(P, V0, V1),
    [W], { quantity(W, QNum) },
    nominal(Num, _, Head, nom(As, n(Head), Posts), V1, V2),
    { agree(det_noun(W, Head), QNum, Num, V2, V),
      agr_of(Num, Agr) }.

% apposition(-Tree, V0, V): a noun phrase a comma sets beside a name to say
% what the name is: "Mukesh Ambani, chairman of Reliance Industries",
% "Syed Ahmed, an Indian politician", "Alice, the doctor, sleeps". It is
% one noun phrase with a determiner or a possessor, or a bare role noun,
% and not a list, a pronoun or a name, since a name after the comma places
% the first, "Springfield, Massachusetts". A comma closes it, or the end
% of the sentence: "Alice, a doctor sleeps" has no reading, as "the dog,
% barks" has none.
apposition(T, V0, V) --> det_np(_, T, V0, V).
apposition(T, V0, V) --> role_np(T, V0, V).

% name_appositive(-Tree, V0, V): after a name and its comma, an
% appositive, or a participle phrase, "Christophe Le Friant, better known
% by his stage name Bob Sinclar, is a record producer"; see
% supplement//3.
name_appositive(T, V0, V) --> apposition(T, V0, V).
name_appositive(T, V0, V) --> supplement_body(T, V0, V).

apposition_end --> [','].
apposition_end([], []).

% apposition_close: as apposition_end, but not a comma before and or or,
% where the noun phrase after the first comma is the second of a list,
% "the dog, the cat, and the bird".
apposition_close --> [','], \+ [and], \+ [or].
apposition_close([], []).

% np_appositive(+NP, -Tree): a name a comma sets after a noun phrase to
% say which one it is, "her stage name, Barbara, from her grandmother",
% "the doctor, Alice, sleeps". It is closed as the appositive after a
% name is, by a comma or the end, so "the doctor, Alice and Bob" is
% still a list and not a noun phrase and a name.
% A noun phrase that ends in a name takes none, since a comma and a name
% after a name place it, "a city in McLennan County, Texas", and that is
% read by name//1.
np_appositive(T, T, V, V) --> [].
np_appositive(T, appos(T, name(N)), V, V) -->
    { \+ ends_in_name(T) },
    [','], name(N), apposition_end.
np_appositive(T, appos(T, A), V0, V) -->
    [','], np_apposition(A, V0, V), apposition_close.
np_appositive(T, appos(T, A), V0, V) -->
    [','], supplement_body(A, V0, V), [','].

% np_apposition(-Tree, V0, V): what else a comma may set after a noun
% phrase: another noun phrase with a determiner or a possessor, "Italy's
% lower house, the Chamber of Deputies"; a title and a name, "the
% nominee, former governor Mitt Romney". A participle phrase, "his
% sacking, announced on Tuesday, has come", is closed by a comma only,
% since one at the end is read on the verb phrase, "is a businesswoman,
% best known as the chairperson", and would be read twice.
np_apposition(T, V0, V) --> det_np(_, T, V0, V).
np_apposition(np(N), V0, V) -->
    nominal(_, _, _, N, V0, V), { title_before_name(N) }.

% ends_in_name(+Tree): the last word of a noun phrase is a name.
ends_in_name(name(_)).
ends_in_name(appos(_, T)) :- ends_in_name(T).
ends_in_name(np(_, nom(_, n(H), Posts))) :-
    (   Posts == [] -> proper(H)
    ;   last(Posts, P), ends_in_name(P)
    ).
ends_in_name(np(_, coord(_, Ns))) :- last(Ns, N), ends_in_name(np(x, N)).
ends_in_name(pp(_, NP)) :- ends_in_name(NP).
ends_in_name(coord(_, Ts)) :- last(Ts, T), ends_in_name(T).

% role_np(-Tree, V0, V): a noun for an office stands bare in the singular
% where it says what someone is, after be and beside a name: "he was
% chairman of the board", "Mukesh Ambani, chairman and managing director
% of Reliance Industries". The noun is one for a person, person/1 in the
% lexicon or WordNet's category of people, and of follows it, or follows
% the last of a run joined by and or or. Neither is relaxed by the
% diagnosis, so "I am student" and "he is doctor" are still refused as a
% noun without its determiner.
role_np(np(N), V0, V) --> role_nominal(N, V0, V).
role_np(np(coord(C, [N1|Ns])), V0, V) -->
    role_core(N1),
    joined(role_item, role_last, [and, or], Ns, C, V0, V).

role_core(N) --> core_nominal(sg, _, Head, N), { person(Head) }.
role_item(N, V, V) --> role_core(N).
role_last(N, V0, V) --> role_nominal(N, V0, V).

% The of phrase is read here and not left to the verb, since it is what
% lets the noun stand bare: "was chairman of the board" has one reading.
role_nominal(nom(As, n(Head), [Of|Posts]), V0, V) -->
    role_core(nom(As, n(Head), [])),
    pp(Of, nogap, nogap, V0, V1), { Of = pp(of, _) },
    nominal_rest(sg, Head, Posts, V1, V).

% date(-Date): a date with its year, "May 16, 2015", or with its day first,
% "10 May 1969", "10 May". A month and a number with no comma, "May 16",
% "January 2014", is already a name followed by a number, and is not read
% again here. With the before its day, "the 2nd of August", "the 2
% August", and so with a day of the week before that, "Thursday the 2
% August"; a day of the week before a date without the, "Thursday 2
% August", is a name and a number already.
date(D) --> [M, Day, ',', Y], { month(M), day(Day), year(Y),
                                 atomic_list_concat([M, Day, Y], ' ', D) }.
date(D) --> [Day, M], { day(Day), month(M) }, date_year(Ys),
            { atomic_list_concat([Day, M|Ys], ' ', D) }.
date(D) --> date_weekday(Ws), [the, Day], { day_of_month(Day) },
            date_of(Os), [M], { month(M) }, date_year(Ys),
            { append([Ws, [the, Day], Os, [M], Ys], Words),
              atomic_list_concat(Words, ' ', D) }.

% time(-Time): a time of day, "13:44", "12:30 p.m.", "5 p.m.", with its
% zone after it or none, "13:44 UTC", "12:30 p.m. AEST". The zone is one
% time_zone/1 lists, so that a name after a time is not read as one.
time(T) --> [H], { time_word(H) }, time_meridiem(Ms), time_zone_after(Zs),
            { atomic_list_concat([H|Ms], ' ', T0),
              atomic_list_concat([T0|Zs], ' ', T) }.
time(T) --> [H, M], { day(H), atom_number(H, N), N =< 12, meridiem(M) },
            time_zone_after(Zs),
            { atomic_list_concat([H, M|Zs], ' ', T) }.

% money(-Amount): a sum with its currency sign, "$5", "£20", "US$5.1
% billion", the country before the sign or none. It is singular, as a
% sum is: "$5 billion was spent".
money(M) --> money_country(Cs), [C], { currency(C) }, [N], { digits(N) },
             money_big(Bs),
             { append([Cs, [C], [N], Bs], Ws), atomic_list_concat(Ws, ' ', M) }.

money_country(['US']) --> ['US'].
money_country([]) --> [].

money_big([B]) --> [B], { big_number(B) }.
money_big([]) --> [].

time_meridiem([M]) --> [M], { meridiem(M) }.
time_meridiem([]) --> [].

time_zone_after([Z]) --> [Z], { time_zone(Z) }.
time_zone_after([]) --> [].

date_weekday([W]) --> [W], { weekday(W) }.
date_weekday([]) --> [].

date_of([of]) --> [of].
date_of([]) --> [].

% day_of_month(Word): a day in digits, 2, or as an ordinal, 2nd.
day_of_month(W) :- day(W).
day_of_month(W) :-
    ordinal(W), atom_chars(W, Cs), append(Ds, [_, _], Cs),
    atom_chars(D, Ds), day(D).

date_year([Y]) --> [Y], { year(Y) }.
date_year([]) --> [].

day(W) :- digits(W), catch(atom_number(W, N), _, fail), integer(N), N >= 1, N =< 31.
year(W) :- digits(W), catch(atom_number(W, N), _, fail), integer(N), N >= 1.

% name(-Name): a name of one word or more, each a name: "Alice", "Stanley
% Ralph Ross", "East Coast Main Line". Name is the words joined by spaces.
% A name takes every name that follows it, so a run of them is one name
% and is not tried again split in two at each place it could be. A number
% in digits after a name may be part of it, "Class 91", "Apollo 11", but
% need not be, since in "he gave Bob 3 apples" it is the next phrase's.
% A comma and a name after a name may place it, "Springfield,
% Massachusetts", "McLennan County, Texas, United States", and the whole
% is one name; it need not, since in "In London, Alice sleeps" the comma
% ends the phrase before the subject, so that reading is left open. Of
% and a name after a name are part of it, "Zigzag of Success", "Statue
% of Liberty", "University of Oxford"; a name takes no prepositional
% phrase otherwise, so this is the only way "Zigzag of Success is" can
% be read, and "I saw Alice of London" has that reading and the one
% with "of London" on the verb.
name(N) -->
    [W], { proper(W) }, name_rest(Ws), name_of(Os), name_places(Ps),
    { append([W|Ws], Os, Words), atomic_list_concat(Words, ' ', N0),
      atomic_list_concat([N0|Ps], ', ', N) }.

name_of([of, W|Ws]) --> [of, W], { proper(W) }, name_rest(Ws).
name_of([]) --> [].

name_rest([W|Ws]) --> [W], { proper(W) }, !, name_rest(Ws).
name_rest([D|Ws]) --> [D], { ( digits(D) ; catalogue_number(D) ) }, name_rest(Ws).
name_rest([]) --> [].

name_places([P|Ps]) -->
    [',', W], { proper(W) }, name_rest(Ws),
    { atomic_list_concat([W|Ws], ' ', P) }, name_places(Ps).
name_places([]) --> [].

% names_only(+Nominal): names before a noun that is a name too, "Samsung
% Bluewings", "Texas United States", where United is an adjective as well.
% With no determiner that is the name read as one, and reading it again as
% names before a noun would count the same words twice.
names_only(nom([A|As], n(H), _)) :-
    proper(H),
    forall(member(X, [A|As]), ( X = name(_) ; X = adj(W), proper(W) )).

% determiner(-Det, -Number, -Sound): a determiner; such before a or an,
% "such a sunset"; a number that takes one before it, "a hundred", "two
% thousand"; or a number with a word before it that makes it rough,
% "about six", "about two thousand", or more than one, "more than
% twenty"; or a definite
% determiner before a quantity, "the three Romanian journalists", "their
% seven encounters", "these few dogs". Each one of two words or three
% counts as one word.
determiner(D, DNum, DSound) --> [D], { det(D, DNum, DSound) }.
determiner(D, sg, S) -->
    [such, A], { ( A == a ; A == an ), det(A, sg, S),
                 atomic_list_concat([such, A], ' ', D) }.
determiner(D, pl, _) -->
    [A, B], { ( A == a ; number_word(A, _) ), big_number(B),
              atomic_list_concat([A, B], ' ', D) }.
determiner(D, Num, _) -->
    [A, N], { approximator(A), number_word(N, Num),
              atomic_list_concat([A, N], ' ', D) }.
determiner(D, pl, _) -->
    [A, N, B], { approximator(A), ( N == a ; number_word(N, _) ), big_number(B),
                 atomic_list_concat([A, N, B], ' ', D) }.
determiner(D, Num, _) -->
    [A, than, N], { comparative_quantity(A), number_word(N, Num),
                    atomic_list_concat([A, than, N], ' ', D) }.
determiner(D, Num, _) -->
    [A, N], { definite_det(A, ANum), quantity(N, Num), ANum = Num,
              atomic_list_concat([A, N], ' ', D) }.
% An adjective of order between them, "the past few days", "the last
% three years", "the other two", and a big number after the number, "the
% two hundred".
determiner(D, pl, _) -->
    [A, J, N], { definite_det(A, _), order_adj(J), quantity(N, pl),
                 atomic_list_concat([A, J, N], ' ', D) }.
determiner(D, pl, _) -->
    [A, N, B], { definite_det(A, _), number_word(N, _), \+ digits(N),
                 big_number(B), atomic_list_concat([A, N, B], ' ', D) }.

order_adj(past). order_adj(last). order_adj(next). order_adj(first).
order_adj(previous). order_adj(final). order_adj(other).
order_adj(remaining). order_adj(coming).

% definite_det(Word, Number): a determiner that may stand before a
% quantity, "the three", "those few", "our many"; these and those only
% before a plural one.
definite_det(the, _).
definite_det(these, pl). definite_det(those, pl).
definite_det(D, _) :- memberchk(D, [my, your, his, her, its, our, their]).

% quantity(Word, Number): a number in words, or few or many, which may
% follow a definite determiner or a possessor, "the three dogs", "Alice's
% many friends". A number in digits is not one, as it is read already
% among the modifiers, "the 2020 census", see leading_number//1.
quantity(W, Num) :- number_word(W, Num), \+ digits(W).
quantity(few, pl).
quantity(many, pl).

% approximator(Word): a word that goes before a number to say it is not
% exact, "about 2,850 people", "nearly six years", "over a thousand" not
% among them, as the number must be one word.
approximator(about). approximator(around). approximator(nearly).
approximator(almost). approximator(approximately). approximator(roughly).
approximator(over). approximator(under).

% multiple(-Words): twice, or a number and times, "1.7 times", "three
% times", which goes before a noun phrase.
multiple(twice) --> [twice].
multiple(M) --> [N, times], { number_word(N, _), atomic_list_concat([N, times], ' ', M) }.

% comparative_quantity(Word): a word that goes before than and a number,
% "more than twenty officials", "fewer than ten dogs", the three words
% one determiner. Than is read nowhere else.
comparative_quantity(more). comparative_quantity(fewer).
comparative_quantity(less).

% possessor(-Tree, V0, V): a noun phrase and 's, standing where a
% determiner would: "Alice's dog", "the old farmer's dog". A possessor can
% itself be possessed, "Alice's friend's dog", which is a chain read left
% to right, each link a noun and its 's, so no rule calls itself on the
% left. A possessor has no prepositional phrase or relative clause here.
% possessive_ahead: an 's is somewhere in what is left to read. A possessor
% is tried at every noun phrase, and without this a sentence with no 's in
% it took half as long again for the search.
possessive_ahead(S, S) :- memberchk('\'s', S).

possessor(P, V0, V) -->
    possessor_base(B, V0, V1), ['\'s'],
    possessor_chain(B, P, V1, V).

possessor_chain(P, P, V, V) --> [].
possessor_chain(B, P, V0, V) -->
    core_nominal(_, _, _, N), ['\'s'],
    possessor_chain(np(poss(B), N), P, V0, V).

possessor_base(name(N), V, V) --> name(N).
possessor_base(np(det(D), N), V0, V) -->
    [D], { det(D, DNum, DSound) },
    core_nominal(Num, First, Head, N0),
    { det_agrees(D, Head, DNum, Num, V0, V1),
      sound(First, Sound),
      agree(article(D, First), DSound, Sound, V1, V2) },
    possessor_pps(N0, N, V2, V).

% possessor_pps(+Nominal0, -Nominal, V0, V): the prepositional phrases
% after a possessor with a determiner, before its 's: "the king of
% France's dog", "the man in the hat's dog". The 's then belongs to the
% whole phrase, and "the king of France's dog" has a second reading,
% the king of France's dog, which English has as well.
possessor_pps(N, N, V, V) --> [].
possessor_pps(nom(As, H, []), nom(As, H, [PP|PPs]), V0, V) -->
    pp(PP, nogap, nogap, V0, V1), pps(PPs, V1, V).
possessor_base(np(N), V0, V) -->
    core_nominal(Num, _, Head, N),
    { \+ leads_number(N), bare_ok(Head, Num, V0, V) }.
% A title and a name, "musician Michael Jackson's legal team".
possessor_base(np(N), V, V) -->
    core_nominal(sg, _, Head, nom(As, n(Head), [])),
    name(Name),
    { N = nom(As, n(Head), [name(Name)]),
      \+ leads_number(N), title_before_name(N) }.

% Nouns joined under one determiner: "a doctor and teacher", "the bishop
% and primate of the church", "these cats and dogs". The determiner agrees
% with each noun, and what follows the last, a prepositional phrase or a
% relative clause, belongs to it. Joined by or, the phrase takes the
% number of the last noun. Joined by and, singular nouns are one thing
% or several: "a doctor and teacher" is one person, "the cat and dog
% are hungry" two animals, so after a determiner that allows either the
% phrase may be either.
nom_item(Num-Head-N, V, V) --> core_nominal(Num, _, Head, N).
nom_last(Num-Head-N, V0, V) --> nominal(Num, _, Head, N, V0, V).

det_agrees_each([], _, _, V, V).
det_agrees_each([Num-Head|NHs], D, DNum, V0, V) :-
    copy_term(DNum, DNum1),
    det_agrees(D, Head, DNum1, Num, V0, V1),
    det_agrees_each(NHs, D, DNum, V1, V).

coord_num(or, _, Nums, Num) :- last(Nums, Num).
coord_num(and, DNum, Nums, Num) :-
    (   memberchk(pl, Nums) -> Num = pl
    ;   DNum == sg -> Num = sg
    ;   member(Num, [sg, pl])
    ).

% bare_ok(+Head, +Number, V0, V): a noun with no determiner is plural, "dogs
% bark", or a mass noun, "water boils"; a singular count noun needs one.
bare_ok(Head, sg, V, V) :- mass(Head), !.
bare_ok(Head, Num, V0, V) :- agree(bare(Head), Num, pl, V0, V).

% det_agrees(+Det, +Head, ?DetNumber, +Number, V0, V): the determiner and
% the noun agree in number. A singular mass noun also takes some and much,
% "some homework", "much bread"; much takes nothing else. Some takes a
% singular kind or sort too, "some sort of animal".
det_agrees(D, Head, DNum, sg, V, V) :-
    mass(Head), ( DNum == mass ; D == some ), !.
det_agrees(some, Head, _, sg, V, V) :- kind_noun(Head), !.
det_agrees(D, Head, DNum, Num, V0, V) :-
    agree(det_noun(D, Head), DNum, Num, V0, V).

% core_nominal(-Number, -FirstWord, -HeadNoun, -Tree): adjectives and a
% noun. A head that is a name does not end before another name: "World
% Aquatics Championships" is one run, and a nominal that stopped at
% "World" and tried the rest as a relative clause started the same search
% again one word on, six times the cost for every word of the run; a
% name is read whole for the same reason, see name//1.
core_nominal(Num, First, Head, nom(As, n(Head), [])) -->
    modifiers(As),
    [Head], { noun_form(Head, _, Num) },
    head_ends(Head),
    { first_word(As, Head, First) }.

head_ends(Head, S, S) :- \+ ( proper(Head), S = [W|_], proper(W) ).

name_after([name(N)]) --> name(N).
name_after([]) --> [].

% nominal(-Number, -FirstWord, -HeadNoun, -Tree, V0, V): adjectives, the
% noun, the prepositional phrases after it, and a relative clause.
nominal(Num, First, Head, nom(As, n(Head), Posts), V0, V) -->
    core_nominal(Num, First, Head, nom(As, n(Head), [])),
    nominal_rest(Num, Head, Posts, V0, V).

% nominal_rest(+Number, +HeadNoun, -Posts, V0, V): what follows the noun:
% a name that says which one, "the record label Yellow Productions", "the
% river Thames", "my friend Alice", then the prepositional phrases and a
% relative clause. The name is read only after a head that is not a
% name itself, see head_ends//1, so "Leroy Ross the cat" has no reading.
nominal_rest(Num, Head, Posts, V0, V) -->
    noun_posts(Head, PPs, V0, V1),
    { agr_of(Num, Agr) },
    post_relative(PPs, Agr, Rels, V1, V2),
    { rel_fits(Head, Rels, V2, V),
      append(PPs, Rels, Posts) }.

% post_relative(+Posts, +Agr, -Rels, V0, V): the relative clause after
% what follows a noun, none after a to-infinitive: "the proposal to
% strengthen the provisions has been rejected" read "the proposal to
% strengthen [that] the provisions has been _" as well.
post_relative(Posts, _, [], V, V) --> { last(Posts, inf(_)) }.
post_relative(Posts, Agr, Rels, V0, V) -->
    { \+ last(Posts, inf(_)) },
    relative(Agr, Rels, V0, V).

% noun_posts(+HeadNoun, -Posts, V0, V): what follows the noun before a
% relative clause: the name, the of after kind, and the prepositional
% phrases.
noun_posts(Head, PPs, V0, V) -->
    name_after(Ns),
    kind_of(Head, KPs, V0, V1),
    pps(PPs0, V1, V2),
    noun_inf(Head, Is, V2, V),
    { append([Ns, KPs, PPs0, Is], PPs) }.

% noun_inf(+HeadNoun, -Trees, V0, V): a to-infinitive after a noun that
% takes one, "the proposal to strengthen the provisions", "an option to
% increase its stake", after its prepositional phrases, "the proposal
% from Donner to strengthen". Only the nouns inf_noun/1 lists: any noun
% would read every "saw the dog to win" twice, with the infinitive on the
% noun and as the verb's purpose.
noun_inf(Head, [inf(VP)], V0, V) -->
    { noun_form(Head, Sg, _), inf_noun(Sg) },
    [to], verb_phrase(base, 2, to, VP, nogap, nogap, V0, V).
noun_inf(_, [], V, V) --> [].

inf_noun(ability). inf_noun(attempt). inf_noun(bid). inf_noun(chance).
inf_noun(decision). inf_noun(effort). inf_noun(failure). inf_noun(motion).
inf_noun(offer). inf_noun(opportunity). inf_noun(option). inf_noun(order).
inf_noun(permission). inf_noun(plan). inf_noun(promise). inf_noun(proposal).
inf_noun(refusal). inf_noun(request). inf_noun(resolution). inf_noun(right).

% modifiers(-Trees): what goes before the noun: its adjectives and names,
% then the nouns that modify it, "the old stone bridge", "the NBC
% television network", "water polo player". A noun there is in the
% singular, "record label" and not "records label". It is not a name or
% an adjective, which are read as those already: WordNet has "stone" and
% "last" as adjectives and nouns, and "the stone bridge" or "the film last
% night" would otherwise have a reading for each. After a noun modifier,
% though, a word that is a noun as well as an adjective is one more noun
% modifier, "a jazz bebop alto saxophonist", since the adjectives have
% been read by then and it can be nothing else; "last" and "next" stay
% out, as they are read before a noun only in "last night", see
% adverbial_np/2, so "I saw the film last night" keeps its one reading.
% An adjective that is not a noun may follow a noun modifier too, the
% two making one adjective, "a water resistant watch", "a world famous
% singer"; one that is a noun as well is the noun modifier already. Nor
% an adverb: "the municipality farthest south" would read with south its
% head.
modifiers(Ms) -->
    leading_number(Ds), adjectives(As), noun_modifiers(Ns),
    { append([Ds, As, Ns], Ms) }.

% leading_number(-Trees): a number in digits first among the modifiers,
% "the 2020 census", "the 2017 World Aquatics Championships", "a 1968
% Soviet comedy movie", or a score, "a 1-4 defeat". It follows a determiner or a possessor: with
% nothing before it the digits are the determiner, "3 dogs", and the
% noun phrases that take no determiner leave it out, see
% leads_number/1.
leading_number([num(D)]) --> [D], { ( digits(D) ; score(D) ) }.
leading_number([]) --> [].

% modifier_noun(+Word): a noun that may stand before another, in the
% singular, or one with no singular, "a police officer", "a cattle ranch",
% or a plural that English puts there, "human rights violations"; see
% plural_modifier/1.
modifier_noun(W) :- noun_form(W, _, sg), !.
modifier_noun(W) :- plural_noun(W).
modifier_noun(W) :- plural_modifier(W).

% leads_number(+Nominal): a number in digits opens it.
leads_number(nom([num(_)|_], _, _)).

noun_modifiers([nmod(W)|Ns]) -->
    [W], { modifier_noun(W), \+ proper(W), \+ adj(W) }, more_noun_modifiers(Ns).
noun_modifiers([]) --> [].

more_noun_modifiers([nmod(W)|Ns]) -->
    [W], { modifier_noun(W), \+ proper(W), \+ time_det(W) }, more_noun_modifiers(Ns).
more_noun_modifiers([adj(W)|Ns]) -->
    [W], { adj(W), \+ noun_form(W, _, _), \+ adv(W), \+ proper(W) },
    more_noun_modifiers(Ns).
more_noun_modifiers([]) --> [].

% adjectives(-Trees): the adjectives before a noun, and any name, which
% stands there as an adjective does: "the Congress Party", "Peace TV
% programs". A name that is also an adjective is read as the adjective
% only, so "the Indian politician" has one reading and not two.
adjectives([AP|As]) --> adj_phrase(AP), adjectives(As).
adjectives([AP, sep(S)|As]) -->
    adj_phrase(AP), adj_sep(S), adjectives(As), { As = [A|_], A \= name(_) }.
adjectives([name(W)|As]) --> [W], { proper(W), \+ adj(W) }, adjectives(As).
adjectives([name(W), name(D)|As]) -->
    [W, D], { proper(W), digits(D) }, adjectives(As).
adjectives([part(W)|As]) --> [W], { participle_adj(W) }, adjectives(As).
adjectives([]) --> [].

% A participle stands before a noun as an adjective does, "the presiding
% bishop", "a painted house", "managing director"; participle_adj/1 in
% lexicon.pl says which words. It costs one word of lookahead and the
% noun must follow, so the diagnosis cannot run with it; a participle
% after its noun, "a movie directed by", opens a verb phrase after every
% noun, and waits for the parser, see docs/ROADMAP.md.

% plain_adjectives(-Trees): one or more adjectives before a name, "old
% London", "north-eastern France", "a big, old dog" as before a noun, none
% of them a name itself, since "United States" is one name and not an
% adjective and a name.
plain_adjectives([AP|As]) --> adj_phrase(AP), { plain(AP) }, plain_rest(As).

plain_rest([]) --> [].
plain_rest([AP|As]) --> adj_phrase(AP), { plain(AP) }, plain_rest(As).
plain_rest([sep(S), AP|As]) --> adj_sep(S), adj_phrase(AP), { plain(AP) }, plain_rest(As).

plain(adj(A)) :- \+ proper(A).
plain(adjp(_, A)) :- \+ proper(A).

% adj_sep(-Words): between two adjectives before a noun, a comma, a
% conjunction, or both: "a big, old dog", "a big and old dog", "a small
% but strong dog".
adj_sep([',']) --> [','].
adj_sep([C]) --> [C], { adj_coordinator(C) }.
adj_sep([',', C]) --> [',', C], { adj_coordinator(C) }.

adj_coordinator(and). adj_coordinator(or). adj_coordinator(but).

% adj_group(-Tree): an adjective after a verb, alone or in a list: "big",
% "big or small", "big, old and happy".
adj_group(T) --> adj_phrase(A), adj_group_rest(A, T).

adj_group_rest(A, A) --> [].
adj_group_rest(A, adj_coord(C, [A|As])) -->
    joined(adj_item, adj_item, [and, or, but], As, C, _, _).

adj_item(A, V, V) --> adj_phrase(A).

% adj_phrase(-Tree): an adjective, with the degree words before it: "old",
% "very old", "really quite old".
adj_phrase(T) --> degrees(Ds), [A], { adj(A) }, { Ds == [] -> T = adj(A) ; T = adjp(Ds, A) }.

degrees([D|Ds]) --> [D], { degree(D) }, degrees(Ds).
degrees([]) --> [].

% first_word(+Adjectives, +Head, -First): the word the noun phrase's
% determiner stands before, which chooses between a and an: "an old man",
% "a very old man".
first_word([adj(A)|_], _, A) :- !.
first_word([adjp([D|_], _)|_], _, D) :- !.
first_word([name(W)|_], _, W) :- !.
first_word([nmod(W)|_], _, W) :- !.
first_word([part(W)|_], _, W) :- !.
first_word([num(D)|_], _, D) :- !.
first_word([], Head, Head).

% kind_of(+Head, -PPs, V0, V): after kind, sort, type and their like, of and
% a singular noun with no determiner, "a kind of rock", "some sort of
% animal", where a noun that is counted would otherwise need one. A plural
% or a mass noun there is an ordinary prepositional phrase, "a kind of
% rocks", "a kind of bread". Two or more may be joined, "any kind of
% separation or break".
kind_of(Head, [pp(of, np(N))], V0, V) -->
    { kind_noun(Head) },
    [of], nominal(sg, _, H, N, V0, V), { \+ mass(H) }.
kind_of(Head, [pp(of, np(coord(C, [N|Ns])))], V0, V) -->
    { kind_noun(Head) },
    [of], core_nominal(sg, _, _, N),
    joined(kind_item, kind_last, [and, or], Ns, C, V0, V).
kind_of(_, [], V, V) --> [].

kind_item(N, V, V) --> core_nominal(sg, _, _, N).
kind_last(N, V0, V) --> nominal(sg, _, _, N, V0, V).

kind_noun(kind). kind_noun(kinds). kind_noun(sort). kind_noun(sorts).
kind_noun(type). kind_noun(types). kind_noun(variety). kind_noun(form).

pps([PP|PPs], V0, V) -->
    pp(PP, nogap, nogap, V0, V1), { \+ set_phrase(PP) }, pps(PPs, V1, V).
pps([], V, V) --> [].

pp(pp(P, NP), G0, G, V0, V) -->
    preposition(P), noun_phrase(_, obj, NP, G0, G, V0, V).
pp(pp(P, VP), G0, G, V0, V) -->
    preposition(P), ing_ahead, verb_phrase(ing, 2, P, VP, G0, G, V0, V).
% A countable noun stands bare after one preposition in a set phrase, "on
% trial", "by email", with the phrases a noun takes after it, "on trial
% regarding the deaths"; see bare_pp/2. It goes with a verb, or after be,
% and not after a noun, so "walks to the garden by car" has one reading;
% see pps//3.
pp(pp(P, np(nom([], n(N), Posts))), G, G, V0, V) -->
    preposition(P), [N], { bare_pp(P, N) },
    nominal_rest(sg, N, Posts, V0, V).
% As takes a bare role noun, as be does: "sacked as manager of the club".
pp(pp(as, NP), G, G, V0, V) --> [as], role_np(NP, V0, V).

set_phrase(pp(P, np(nom([], n(N), _)))) :- bare_pp(P, N).

% preposition(-Prep): one word, or two or three that make one, "as of the
% census", "out of the box", "as part of the project", "in front of the
% house", which prep_pair/2 and prep_triple/3 list; the words count as
% one, as the two-word determiners do.
preposition(P) --> [P], { prep(P) }.
preposition(P) --> [A, B], { prep_pair(A, B), atomic_list_concat([A, B], ' ', P) }.
preposition(P) -->
    [A, B, C], { prep_triple(A, B, C), atomic_list_concat([A, B, C], ' ', P) }.

% prep_ahead: the next words are a preposition.
prep_ahead(S, S) :- phrase(preposition(_), S, _), !.

% A preposition may take an -ing verb phrase in place of a noun phrase,
% "tired of barking", "after eating the cake", "the record for being the
% largest cluster", "after having eaten". The rule is entered only when
% the next word is an -ing form, which the diagnosis does not relax:
% without that, with agreement relaxed, every noun WordNet also lists as
% a verb opened a verb phrase after every preposition, and the corpus
% run that had taken three minutes was stopped at fifteen.
ing_ahead([W|S], [W|S]) :- ( verb_form(W, _, ing) ; be_form(W, ing) ), !.

% relative(+Agr, -Rels, V0, V): no relative clause, or one, for a noun
% whose agreement is Agr. When the relative word stands for the subject,
% the verb agrees with the noun: "the dogs that chase", "the dog that
% chases". When it stands for an object, the clause is a statement with
% the gap in it: "the cat that the dog chased _". The word may then be
% left out, "the cat the dog chased", but not for a subject.
relative(_, [], V, V) --> [].
relative(Agr, [rel(W, C)], V0, V) -->
    [W], { rel_pronoun(W, _) },
    relative_body(Agr, W, C, V0, V).
% The word is not left out before a singular common noun, which the head
% would have taken as one more noun before it: in "an American television
% sitcom series starring Bill Cosby", a head that stopped at American or
% television read the rest as the subject of a clause, the whole of it,
% for each, and a sentence that took a fifth of a second took forty. A
% subject there would need a determiner of its own, or be a mass noun.
relative(_, [rel(none, S)], V0, V) -->
    no_noun_ahead,
    statement(S, gap, nogap, V0, V).

no_noun_ahead(S, S) :- \+ ( S = [W|_], noun_form(W, _, sg), \+ proper(W) ).
% A relative clause a comma sets off says more about a noun already
% known, "comedy routines in Cosby's act, which in turn were based on his
% family life". It opens with which, who or whom, never that or nothing,
% and is closed as an appositive is, by a comma or the end.
relative(Agr, [rel(W, C)], V0, V) -->
    [','], [W], { nonrestrictive(W) },
    relative_body(Agr, W, C, V0, V),
    apposition_end.
% A preposition may go before the relative word, and the clause then has
% a prepositional phrase missing: "the park in which the dog walks", "the
% man with whom Alice walks", and set off by a comma, "the park, in which
% the dog walks, is big". The word is which or whom, never that or who.
relative(_, [rel(pp(P, W), S)], V0, V) -->
    preposition(P), [W], { pied_piped(W) },
    statement(S, ppgap, nogap, V0, V).
relative(_, [rel(pp(P, W), S)], V0, V) -->
    [','], preposition(P), [W], { pied_piped(W) },
    statement(S, ppgap, nogap, V0, V),
    apposition_end.

pied_piped(which). pied_piped(whom).
% A quantity and of may go before the relative word, which then stands
% for the subject, set off by a comma: "two children, one of which was
% driving", "the dogs, some of whom sleep". The verb agrees as the
% quantity does, or with the noun for some and its like.
relative(Agr, [rel(part(Q, W), VP)], V0, V) -->
    [','], [Q], { partitive(Q, QNum) }, [of], [W], { pied_piped(W) },
    { QNum == inner -> RAgr = Agr ; agr_of(QNum, RAgr) },
    verb_phrase(fin(RAgr), 1, subject, VP, nogap, nogap, V0, V),
    apposition_end.
% A clause with its relative word and be left out is a participle and
% what follows it, passive, "a movie directed by Eldar Ryazanov", or in
% -ing, "a network broadcasting from Dubai". The rule is entered only
% when the next word is such a form, a lookahead the diagnosis does not
% relax, as the gerund after a preposition has, and its verb is never
% read as a wrong form of itself, so an ordinary fault is not diagnosed
% as a participle.
relative(_, [rel(none, VP)], V0, V) -->
    participle_ahead,
    verb_phrase(pass, 6, reduced, VP, nogap, nogap, V0, V).
relative(_, [rel(none, VP)], V0, V) -->
    participle_ahead,
    verb_phrase(ing, 6, reduced, VP, nogap, nogap, V0, V).

participle_ahead([W|S], [W|S]) :- participle_word(W).

% relative_body(+Agr, +Word, -Tree, V0, V): what follows the relative
% word: a verb phrase, the word standing for the subject, or a statement
% with the gap in it.
relative_body(Agr, W, T, V0, V) -->
    { rel_pronoun(W, Case), agree(case(W), Case, subj, V0, V1) },
    emphatic(Agr, E, V1, V2),
    verb_phrase(fin(Agr), 1, subject, VP, nogap, nogap, V2, V),
    { E == none -> T = VP ; T = emph_vp(E, VP) }.
relative_body(_, _, S, V0, V) -->
    statement(S, gap, nogap, V0, V).

nonrestrictive(which). nonrestrictive(who). nonrestrictive(whom).

% rel_fits(+HeadNoun, +Rels, V0, V): which, alone or after a preposition,
% does not stand for a person: "the man who sleeps", "the man that
% sleeps", not "the man which sleeps". A person is a noun person/1 lists,
% the lexicon's own or one whose most frequent sense in WordNet is a
% person. Who after a thing is not checked: WordNet gives no sense of a
% person to "a legend who", and some of one to "the table who", so no
% rule from it is right both ways. Animals take either word.
rel_fits(Head, [rel(W, _)], V0, V) :-
    rel_word(W, which), person(Head), !,
    violation(which_person(Head), V0, V).
rel_fits(_, _, V, V).

rel_word(pp(_, W), W) :- !.
rel_word(W, W).

/* ---------------- verb phrases ---------------- */

% verb_phrase(+Form, +Rank, +Prev, -Tree, G0, G, V0, V): a verb phrase whose
% first word is in Form: fin(Agr) at the start of a sentence, where it
% agrees with the subject, or the base, ing, en or passive form the
% auxiliary before it asks for. Prev is that auxiliary, for the diagnosis.
% Rank is the lowest rank the first word may have: an auxiliary is followed
% only by ones ranked above it, which is English's order.
verb_phrase(Form, Min, Prev, T, G0, G, V0, V) -->
    correlative_word(Pre, Cs),
    pre_adverbs(As),
    verb_head(Form, Min, Prev, VP, G0, G, V0, V1),
    { As == [] -> T1 = VP ; T1 = pre(As, VP) },
    vp_rest(Pre, Cs, Form, Min, Prev, T1, T, V1, V).

% vp_rest(+Pre, +Conjunctions, +Form, +Min, +Prev, +First, -Tree, V0, V):
% the verb phrase First alone, or joined to verb phrases after it in the
% same form, each a list item as joined//7 reads them: "sleeps and eats",
% "barks, eats and sleeps", "was made by X and published by Y", "either
% sleeps or eats". After either, neither or both the list is required.
% The phrases after the first take no gap.
vp_rest(none, _, _, _, _, T, T, V, V) --> [].
vp_rest(Pre, Cs, Form, Min, Prev, T1, T, V0, V) -->
    joined(vp_item(Form, Min, Prev), vp_item(Form, Min, Prev), Cs, Ts, C, V0, V),
    { correlated(Pre, vp_coord(C, [T1|Ts]), T) }.
% Two verb phrases may have a comma before their conjunction, as two
% clauses may: "was sworn in as Governor, but only served four months".
% Noun phrases may not, "Alice, and Bob" being no list.
vp_rest(Pre, Cs, Form, Min, Prev, T1, T, V0, V) -->
    [',', C], { memberchk(C, Cs) },
    vp_item(Form, Min, Prev, T2, V0, V),
    { correlated(Pre, vp_coord(C, [T1, T2]), T) }.

vp_item(Form, Min, Prev, T, V0, V) -->
    verb_phrase(Form, Min, Prev, T, nogap, nogap, V0, V).

% pre_adverbs(-Adverbs): the adverbs that may stand before a verb, "has
% already eaten", "never sleeps": those of time and frequency listed in
% lexicon.pl, and any in -ly, "quickly ran". Others, "yesterday", "well",
% go after it, in modifiers//5.
pre_adverbs([adv(A)|As]) --> [A], { adv(A), before_verb(A) }, pre_adverbs(As).
pre_adverbs([adv(A)|As]) --> [W1, W2], { adverb_pair(W1, W2, A) }, pre_adverbs(As).
pre_adverbs([]) --> [].

% adverb_pair(?First, ?Second, ?Adverb): two words that are one adverb,
% "in turn", read where the adverbs before a verb are, "which in turn
% were based on". Read as a preposition and its noun, turn would need a
% determiner.
adverb_pair(in, turn, 'in turn').

before_verb(A) :- frequency(A), !.
before_verb(A) :- atom_concat(_, ly, A).

verb_head(Form, Min, Prev, vp(Tok, Neg, Items), G0, G, V0, V) -->
    [Tok], { head_word(Tok, W, Neg0), head(W, Kind, Base, F),
             rank(Kind, R), R >= Min,
             form_ok(Form, Prev, Tok, F, V0, V1) },
    negation(Form, Kind, Tok, Neg0, Neg, V1, V2),
    rest(Kind, Base, Tok, Form, Items, G0, G, V2, V).

% head_word(+Token, -Word, -Neg): a contraction is its auxiliary, negated
% if it has n't, as doesn't is does; a cut-off one such as 's is its word.
head_word(Tok, Tok, none).
head_word(Tok, W, contracted) :- neg_contraction(Tok, W).
head_word(Tok, W, none) :- clitic(Tok, W).

% head(+Word, -Kind, -Base, -Form): what a word can head. be is three kinds,
% told apart by what follows: the progressive, the passive and the copula.
head(W, modal, W, fin(_)) :- modal(W).
head(W, do, do, F)        :- do_form(W, F).
head(W, perf, have, F)    :- have_form(W, F).
head(W, Kind, be, F)      :- be_form(W, F), be_kind(Kind).
head(W, lex, Base, F)     :- verb_form(W, Base, F).

be_kind(prog). be_kind(pass). be_kind(cop).

% might have been being chased: modal, perfect, progressive, passive, and
% then the verb. do goes before a verb alone, never be: "does not bark".
rank(modal, 1). rank(do, 1). rank(perf, 2). rank(prog, 3). rank(pass, 4).
rank(cop, 5). rank(lex, 6).

% form_ok(+Form, +Prev, +Token, +F, V0, V): the word is in the form its
% place asks for. At the start that is a finite form, which agrees with the
% subject. A word with a finite form is not blamed for its other forms
% there: "the dog chase" is chase disagreeing, not chase as the base.
form_ok(fin(Agr), _, Tok, F, V0, V) :- !,
    (   F = fin(VAgr)
    ->  agree(subject_verb(Tok), Agr, VAgr, V0, V)
    ;   \+ has_finite(Tok),
        violation(finite(Tok), V0, V)
    ).
form_ok(pass, reduced, _, F, V, V) :- !, F == en.
form_ok(ing, reduced, _, F, V, V) :- !, F == ing.
form_ok(pass, Prev, Tok, F, V0, V) :- !,
    agree(verb_form(Prev, Tok, en), en, F, V0, V).
form_ok(Form, Prev, Tok, F, V0, V) :-
    agree(verb_form(Prev, Tok, Form), Form, F, V0, V).

has_finite(Tok) :- head_word(Tok, W, _), head(W, _, _, fin(_)), !.

% not follows the first auxiliary, or be. A verb alone takes do instead:
% "does not bark", not "barks not".
negation(fin(_), Kind, _, none, not, V, V) --> { Kind \== lex }, [not].
negation(fin(_), lex, Tok, none, not, V0, V) -->
    [not], { violation(do_support(Tok), V0, V) }.
negation(_, _, _, _, none, V, V) --> [].

% rest(+Kind, +Base, +Token, +Form, -Items, G0, G, V0, V): what follows the
% word.
rest(modal, _, Tok, _, [VP], G0, G, V0, V) --> verb_phrase(base, 2, Tok, VP, G0, G, V0, V).
rest(do,    _, Tok, _, [VP], G0, G, V0, V) --> verb_phrase(base, 6, Tok, VP, G0, G, V0, V).
rest(perf,  _, Tok, _, [VP], G0, G, V0, V) --> verb_phrase(en, 3, Tok, VP, G0, G, V0, V).
rest(prog,  _, Tok, _, [VP], G0, G, V0, V) --> verb_phrase(ing, 4, Tok, VP, G0, G, V0, V).
rest(pass,  _, Tok, _, [VP], G0, G, V0, V) --> verb_phrase(pass, 6, Tok, VP, G0, G, V0, V).
rest(cop,   _, _, _, Items, G0, G, V0, V) -->
    pre_adverbs(As),
    predicate(C, G0, G1, V0, V1),
    modifiers(Ms, G1, G, V1, V),
    { append(As, [C|Ms], Items) }.
rest(lex, Base, Tok, Form, Items, G0, G, V0, V) -->
    { verb_frames(Base, Frames), member(Frame0, Frames),
      frame(Form, Frame0, Frame) },
    complements(Frame, Tok, Cs, G0, G1, V0, V1),
    modifiers(Ms, G1, G, V1, V),
    { append(Cs, Ms, Items) }.

% verb_frames(+Base, -Frames): the verb's frames, with those extra_frame/2
% adds; and a noun phrase as the second complement, obj_np, "they
% considered Bob a potential running mate", for a verb that takes a noun
% phrase and an adjective, as WordNet's frame "Something ----s something
% Adjective/Noun" does, unless it takes two objects as well, since "call
% him a taxi" would read twice.
verb_frames(Base, Frames) :-
    verb(Base, Frames0),
    findall(F, extra_frame(Base, F), Es),
    (   memberchk(obj_pred, Frames0), \+ memberchk(ditrans, Frames0)
    ->  Ns = [obj_np]
    ;   Ns = []
    ),
    append([Frames0, Es, Ns], Frames).

% A passive has lost its first object to the subject: "the cat was chased",
% "the dog was given a bone". An object and an -ing verb phrase is read in
% the passive only, "was discovered orbiting the star": "found the dog
% sleeping" reads already, the dog with a participle after it.
frame(Form, F, F) :- Form \== pass, F \== obj_ing.
frame(pass, trans, intrans).
frame(pass, ditrans, trans).
frame(pass, obj_pred, pred).
frame(pass, obj_np, np_pred).
frame(pass, obj_inf, inf).
frame(pass, obj_as, as_pred).
frame(pass, obj_ing, ing).

% complements(+Frame, +Verb, -Items, G0, G, V0, V): what the verb takes, by
% the frame chosen from its entry:
%   intrans    nothing                      the dog sleeps
%   trans      a noun phrase                the dog chases a cat
%   ditrans    two noun phrases             alice gives the dog a bone
%   pred       an adjective                 the soup tastes good
%   obj_pred   a noun phrase and one        they paint the kitchen blue
%   clause     a statement, that or not     i think (that) she is right
%   inf        to and a verb phrase         she wants to learn french
%   obj_inf    a noun phrase, then one      she told him to go
%   ing        an -ing verb phrase          the dog stopped barking
complements(intrans, _, [], G, G, V, V) --> [].
complements(trans, _, [O], G0, G, V0, V) --> noun_phrase(_, obj, O, G0, G, V0, V).
% An adverb particle may come before the object, "picked up the box",
% "put forth the proposal"; see adv_particle/1. After the object it is
% read as an adverb already, "put the proposal forth".
complements(trans, _, [prt(P), O], G0, G, V0, V) -->
    [P], { adv_particle(P) }, noun_phrase(_, obj, O, G0, G, V0, V).
complements(ditrans, _, [O1, O2], G0, G, V0, V) -->
    noun_phrase(_, obj, O1, G0, G1, V0, V1),
    noun_phrase(_, obj, O2, G1, G, V1, V).
complements(pred, _, [A], G, G, V, V) --> adj_group(A).
% An adverb may stand before the adjective, as before be's, "went quietly
% online", "grew slowly dark".
complements(pred, _, [adv(D), A], G, G, V, V) -->
    [D], { adv(D), \+ approximator(D), \+ inner_adverb(D) }, adj_group(A).
complements(obj_pred, _, [O, A], G0, G, V0, V) -->
    noun_phrase(_, obj, O, G0, G, V0, V), adj_group(A).
complements(clause, _, [sbar(C, S)], G0, G, V0, V) -->
    complementizer(C), statement(S, G0, G, V0, V).
complements(inf, _, [inf(VP)], G0, G, V0, V) -->
    [to], verb_phrase(base, 2, to, VP, G0, G, V0, V).
complements(obj_inf, _, [O, inf(VP)], G0, G, V0, V) -->
    noun_phrase(_, obj, O, G0, G1, V0, V1),
    [to], verb_phrase(base, 2, to, VP, G1, G, V1, V).
complements(ing, Tok, [VP], G0, G, V0, V) -->
    verb_phrase(ing, 3, Tok, VP, G0, G, V0, V).
%   obj_np     two noun phrases, the second what the first is
%                                           they considered Bob a candidate
%   np_pred    a noun phrase, in the passive of obj_np
%                                           Bob was considered a candidate
%   obj_as     a noun phrase, as, an adjective
%                                           they described it as grim
%   as_pred    as and an adjective, in the passive of obj_as
%   yet_inf    yet and a to-infinitive      the body has yet to be found
%   obj_bare   a noun phrase, a bare infinitive
%                                           she made the dog sleep
% With a noun phrase after it, as is the preposition, "described him as
% a genius", so obj_as takes an adjective only.
complements(obj_np, _, [O, P], G0, G, V0, V) -->
    noun_phrase(_, obj, O, G0, G1, V0, V1),
    noun_phrase(_, obj, P, G1, G, V1, V).
complements(np_pred, _, [P], G0, G, V0, V) --> noun_phrase(_, obj, P, G0, G, V0, V).
complements(obj_as, _, [O, as(A)], G0, G, V0, V) -->
    noun_phrase(_, obj, O, G0, G, V0, V), [as], adj_group(A).
complements(as_pred, _, [as(A)], G, G, V, V) --> [as], adj_group(A).
% The bare infinitive does not open with a noun phrase of time, "did you
% see the film last night", where last would be the verb.
complements(obj_bare, _, [O, VP], G0, G, V0, V) -->
    noun_phrase(_, obj, O, G0, G1, V0, V1),
    \+ ( [D, N], { adverbial_np(D, N) } ),
    verb_phrase(base, 2, bare, VP, G1, G, V1, V).
complements(yet_inf, _, [adv(yet), inf(VP)], G0, G, V0, V) -->
    [yet, to], verb_phrase(base, 2, to, VP, G0, G, V0, V).

complementizer(that) --> [that].
complementizer(none) --> [].

% What follows be: an adjective, a noun phrase, a bare role noun, or a
% place, with the adverbs that may stand before a verb before it: "is also
% the capital", "is always happy", "was chairman of the board"; or a
% to-infinitive, what is arranged or expected, "the locomotives were to
% enter service", "the dog is to sleep". The last was held from
% 2026-10-02 to 2026-10-03: the one corpus sentence it lets through has
% 156 readings, which took three minutes to find before the chart, see
% chart.pl, and takes under half a second with it.
predicate(AP, G, G, V, V) --> adj_group(AP).
predicate(NP, G0, G, V0, V) --> noun_phrase(_, _, NP, G0, G, V0, V).
predicate(NP, G, G, V0, V) --> role_np(NP, V0, V).
predicate(PP, G0, G, V0, V) --> pp(PP, G0, G, V0, V), { \+ to_verb_form(PP) }.
% The prepositional phrase a relative clause has missing, "the garden in
% which the children were _".
predicate(gap, ppgap, nogap, V, V) --> [].
predicate(inf(VP), G0, G, V0, V) -->
    [to], verb_phrase(base, 2, to, VP, G0, G, V0, V).

% to_verb_form(+PP): to and a bare noun that is also a verb's -s form,
% which after be is the verb of a to-infinitive in the wrong form: "the
% dog is to walks" is not "is [to walks]", a place, but "is to walk".
to_verb_form(pp(to, np(nom(_, n(H), _)))) :- verb_form(H, _, fin(agr(_, y, _))).

% Adverbs and prepositional phrases after the verb and what it takes. The
% gap may be a preposition's object: "the park that the dog walks in _".
modifiers([adv(A)|Ms], G0, G, V0, V) --> [A], { adv(A) }, modifiers(Ms, G0, G, V0, V).
% A particle, a preposition with no noun phrase after it that goes with
% the verb: "sworn in", "ran in", "carried on", "came by". Only the
% prepositions the lexicon lists are read this way; "up", "out", "off",
% "away" are adverbs in WordNet already and are read as those.
modifiers([prt(P)|Ms], G0, G, V0, V) --> [P], { particle(P) }, modifiers(Ms, G0, G, V0, V).
modifiers([PP|Ms], G0, G, V0, V) -->
    pp(PP0, G0, G1, V0, V1), pp_joined(PP0, PP, V1, V2), modifiers(Ms, G1, G, V2, V).
% A comma may set off a prepositional phrase after the verb and what it
% takes, "Elm was a municipality, in the municipality of Glarus Süd". It
% is entered only when a preposition follows the comma, and takes no gap.
modifiers([PP|Ms], G0, G, V0, V) -->
    [','], prep_ahead, pp(PP, nogap, nogap, V0, V1), modifiers(Ms, G0, G, V1, V).
% A score, or scores set off by commas, "defeated Jankovic 7-6, 7-5".
modifiers([score(Ss)|Ms], G0, G, V0, V) -->
    scores(Ss), modifiers(Ms, G0, G, V0, V).
modifiers([npadv(D, N)|Ms], G0, G, V0, V) -->
    [D, N], { adverbial_np(D, N) }, modifiers(Ms, G0, G, V0, V).
modifiers([], G, G, V, V) --> [].
% The prepositional phrase a relative clause has missing, "the park in
% which the dog walks _". It is placed last, as nothing in the words
% shows where among the modifiers it would stand, and a gap free to go
% anywhere among them gave one reading for each place.
modifiers([gap], ppgap, nogap, V, V) --> [].

% A participle phrase a comma sets off, after the verb and what it takes:
% "is a businesswoman, best known as the chairperson", "was a sitcom
% series, first broadcast in 1984 and ran for eight seasons".
% It is the last of them, so that what follows it is its own and not
% the verb's again.
modifiers([S], G, G, V0, V) --> supplement(S, V0, V).
% Last in the sentence, a comma and an adverb, "as of 13:44 UTC,
% yesterday"; or a comma and a phrase with a subject of its own, a
% quantity with of, and what is said of it, "eleven ships, eight of them
% exclusively for military use". Only a quantity with of, since with any
% noun phrase "Alice saw the dog, the cat in the garden" would read.
modifiers([adv(A)], G, G, V, V, [',', A], []) :- adv(A).
% Or a comma and the clock a time is given in, "on 10 November, Japanese
% time", "at six, local time": time with a word before it that says
% whose, and no determiner, so "the dog slept, time" has no reading.
modifiers([clock(N)], G, G, V0, V) -->
    [','], nominal(sg, _, time, N, V0, V), { N = nom([_|_], _, _) },
    end_of_words.
modifiers([absolute(NP, P)], G, G, V0, V) -->
    [','], [Q], { partitive(Q, _) }, [of],
    absolute_np(Q, NP, V0, V1),
    absolute_pred(P, V1, V),
    end_of_words.

absolute_np(Q, part(Q, NP), V0, V) --> partitive_np(NP, _, V0, V).

absolute_pred(pre([adv(A)], PP), V0, V) --> [A], { adv(A) }, pp(PP, nogap, nogap, V0, V).
absolute_pred(PP, V0, V) --> pp(PP, nogap, nogap, V0, V).
absolute_pred(AP, V, V) --> adj_group(AP).

end_of_words([], []).
% A to-infinitive of purpose, last for the same reason: "defeated
% Jankovic to win the Rogers Cup", "spoke to the director to have a
% look". It takes no gap.
modifiers([inf(VP)], G, G, V0, V) -->
    [to], verb_phrase(base, 2, to, VP, nogap, nogap, V0, V).

scores([S|Ss]) --> [S], { score(S) }, more_scores(Ss).
more_scores(Ss) --> [','], scores(Ss).
more_scores([]) --> [].

% pp_joined(+PP, -Tree, V0, V): a prepositional phrase alone, or joined to
% a second by and or or, "known as the chairperson and as a director",
% "in the house or in the garden". The two have the same preposition:
% the second is read only when it follows the conjunction, and the first
% is not read again.
pp_joined(PP, PP, V, V) --> [].
pp_joined(PP1, pp_coord(C, [PP1, PP2]), V0, V) -->
    [C], { ( C == and ; C == or ), PP1 = pp(P, _) },
    same_prep_ahead(P),
    pp(PP2, nogap, nogap, V0, V), { PP2 = pp(P, _) }.

same_prep_ahead(P, S, S) :- phrase(preposition(P), S, _), !.

% supplement(-Tree, V0, V): a comma and a participle phrase that says
% more about what came before, passive or in -ing, with one adverb before
% it or none: "best known as the chairperson", "better known by his
% stage name", "first broadcast in 1984". It is entered only when a
% participle, or an adverb and a participle, follows the comma, a
% lookahead the diagnosis does not relax. After a name it is closed as
% an appositive is; after a verb phrase nothing need close it, since
% what follows is read as the verb phrase's own.
supplement(T, V0, V) --> [','], supplement_body(T, V0, V).

supplement_body(T, V0, V) -->
    supplement_adverb(As),
    participle_ahead,
    supplement_vp(VP, V0, V),
    { As == [] -> T = VP ; T = pre(As, VP) }.

supplement_adverb([adv(A)]) --> [A], { adv(A) }.
supplement_adverb([]) --> [].

supplement_vp(VP, V0, V) --> verb_phrase(pass, 6, reduced, VP, nogap, nogap, V0, V).
supplement_vp(VP, V0, V) --> verb_phrase(ing, 6, reduced, VP, nogap, nogap, V0, V).

% adverbial_np(?Word, ?Noun): a noun phrase that is an adverb of time or
% place, "last night", "every day", "next door". last and next are not
% determiners anywhere else, so they are only read here.
adverbial_np(D, N) :- time_det(D), time_noun(N).
adverbial_np(next, door).

time_det(last). time_det(next). time_det(this). time_det(that).
time_det(every). time_det(each).
