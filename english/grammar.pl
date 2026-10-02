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

% statement(-Tree, G0, G, V0, V). The subject is never the gap.
statement(s(NP, VP), G0, G, V0, V) -->
    noun_phrase(Agr, subj, NP, nogap, nogap, V0, V1),
    verb_phrase(fin(Agr), 1, subject, VP, G0, G, V1, V).

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
noun_phrase(Agr, Case, T, G, G, V0, V) -->
    correlative_word(Pre, Cs),
    np_first(Case, T1, V0, V1),
    joined(np_item(Case), np_last(Case), Cs, Items, C, V1, V),
    { last(Items, Last-_), coord_agr(C, Last, Agr), pairs_values(Items, Ts),
      correlated(Pre, coord(C, [T1|Ts]), T) }.

np_item(Case, A-T, V0, V) --> simple_np(A, Case, T, V0, V).
np_last(Case, A-T, V0, V) --> noun_phrase(A, Case, T, nogap, nogap, V0, V).

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
simple_np(Agr, _, name(N), V, V) -->
    name(N), { agr_of(sg, Agr) }.
simple_np(Agr, _, appos(name(N), NP), V0, V) -->
    name(N), [','], apposition(NP, V0, V), apposition_end,
    { agr_of(sg, Agr) }.
simple_np(Agr, _, np(nom(As, n(N), [])), V, V) -->
    plain_adjectives(As), name(N), { agr_of(sg, Agr) }.
simple_np(Agr, _, date(D), V, V) -->
    date(D), { agr_of(sg, Agr) }.
simple_np(Agr, _, num(W), V, V) -->
    [W], { number_word(W, Num), agr_of(Num, Agr) }.
simple_np(Agr, _, T, V0, V) --> det_np(Agr, T, V0, V).
simple_np(Agr, _, np(N), V0, V) -->
    nominal(Num, _, Head, N, V0, V1),
    { \+ names_only(N), \+ leads_number(N),
      bare_ok(Head, Num, V1, V),
      agr_of(Num, Agr) }.

% det_np(-Agr, -Tree, V0, V): a noun phrase with a determiner or a
% possessor before its noun, which is what may stand beside a name as an
% appositive.
det_np(Agr, np(det(D), N), V0, V) -->
    determiner(D, DNum, DSound),
    nominal(Num, First, Head, N, V0, V1),
    { det_agrees(D, Head, DNum, Num, V1, V2),
      sound(First, Sound),
      agree(article(D, First), DSound, Sound, V2, V),
      agr_of(Num, Agr) }.
det_np(Agr, np(det(D), coord(C, [N1|Ns])), V0, V) -->
    determiner(D, DNum, DSound),
    core_nominal(Num1, First, Head1, N1),
    joined(nom_item, nom_last, [and, or], Items, C, V0, V1),
    { pairs_keys_values(Items, NumHeads, Ns),
      det_agrees_each([Num1-Head1|NumHeads], D, DNum, V1, V2),
      sound(First, Sound),
      agree(article(D, First), DSound, Sound, V2, V),
      pairs_keys([Num1-Head1|NumHeads], Nums),
      coord_num(C, DNum, Nums, Num),
      agr_of(Num, Agr) }.
det_np(Agr, np(poss(P), N), V0, V) -->
    possessive_ahead,
    possessor(P, V0, V1),
    nominal(Num, _, _, N, V1, V),
    { agr_of(Num, Agr) }.

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

apposition_end --> [','].
apposition_end([], []).

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
% again here.
date(D) --> [M, Day, ',', Y], { month(M), day(Day), year(Y),
                                 atomic_list_concat([M, Day, Y], ' ', D) }.
date(D) --> [Day, M], { day(Day), month(M) }, date_year(Ys),
            { atomic_list_concat([Day, M|Ys], ' ', D) }.

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
name_rest([D|Ws]) --> [D], { digits(D) }, name_rest(Ws).
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
% "about six". Each two-word one counts as one word.
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

% approximator(Word): a word that goes before a number to say it is not
% exact, "about 2,850 people", "nearly six years", "over a thousand" not
% among them, as the number must be one word.
approximator(about). approximator(around). approximator(nearly).
approximator(almost). approximator(approximately). approximator(roughly).
approximator(over). approximator(under).

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
    core_nominal(Num, First, Head, N),
    { det_agrees(D, Head, DNum, Num, V0, V1),
      sound(First, Sound),
      agree(article(D, First), DSound, Sound, V1, V) }.
possessor_base(np(N), V0, V) -->
    core_nominal(Num, _, Head, N),
    { \+ leads_number(N), bare_ok(Head, Num, V0, V) }.

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

% nominal(-Number, -FirstWord, -HeadNoun, -Tree, V0, V): adjectives, the
% noun, the prepositional phrases after it, and a relative clause.
nominal(Num, First, Head, nom(As, n(Head), Posts), V0, V) -->
    core_nominal(Num, First, Head, nom(As, n(Head), [])),
    nominal_rest(Num, Head, Posts, V0, V).

% nominal_rest(+Number, +HeadNoun, -Posts, V0, V): what follows the noun.
nominal_rest(Num, Head, Posts, V0, V) -->
    kind_of(Head, KPs, V0, V01),
    pps(PPs0, V01, V1),
    { append(KPs, PPs0, PPs) },
    { agr_of(Num, Agr) },
    relative(Agr, Rels, V1, V),
    { append(PPs, Rels, Posts) }.

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
modifiers(Ms) -->
    leading_number(Ds), adjectives(As), noun_modifiers(Ns),
    { append([Ds, As, Ns], Ms) }.

% leading_number(-Trees): a number in digits first among the modifiers,
% "the 2020 census", "the 2017 World Aquatics Championships", "a 1968
% Soviet comedy movie". It follows a determiner or a possessor: with
% nothing before it the digits are the determiner, "3 dogs", and the
% noun phrases that take no determiner leave it out, see
% leads_number/1.
leading_number([num(D)]) --> [D], { digits(D) }.
leading_number([]) --> [].

% leads_number(+Nominal): a number in digits opens it.
leads_number(nom([num(_)|_], _, _)).

noun_modifiers([nmod(W)|Ns]) -->
    [W], { noun_form(W, _, sg), \+ proper(W), \+ adj(W) }, more_noun_modifiers(Ns).
noun_modifiers([]) --> [].

more_noun_modifiers([nmod(W)|Ns]) -->
    [W], { noun_form(W, _, sg), \+ proper(W), \+ time_det(W) }, more_noun_modifiers(Ns).
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

pps([PP|PPs], V0, V) --> pp(PP, nogap, nogap, V0, V1), pps(PPs, V1, V).
pps([], V, V) --> [].

pp(pp(P, NP), G0, G, V0, V) -->
    preposition(P), noun_phrase(_, obj, NP, G0, G, V0, V).
pp(pp(P, VP), G0, G, V0, V) -->
    preposition(P), ing_ahead, verb_phrase(ing, 2, P, VP, G0, G, V0, V).

% preposition(-Prep): one word, or two that make one, "as of the census",
% "out of the box", "because of the rain", which prep_pair/2 lists; the
% two count as one word, as the two-word determiners do.
preposition(P) --> [P], { prep(P) }.
preposition(P) --> [A, B], { prep_pair(A, B), atomic_list_concat([A, B], ' ', P) }.

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
relative(Agr, [rel(W, VP)], V0, V) -->
    [W], { rel_pronoun(W, Case),
           agree(case(W), Case, subj, V0, V1) },
    verb_phrase(fin(Agr), 1, subject, VP, nogap, nogap, V1, V).
relative(_, [rel(W, S)], V0, V) -->
    [W], { rel_pronoun(W, _) },
    statement(S, gap, nogap, V0, V).
relative(_, [rel(none, S)], V0, V) -->
    statement(S, gap, nogap, V0, V).
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

vp_item(Form, Min, Prev, T, V0, V) -->
    verb_phrase(Form, Min, Prev, T, nogap, nogap, V0, V).

% pre_adverbs(-Adverbs): the adverbs that may stand before a verb, "has
% already eaten", "never sleeps": those of time and frequency listed in
% lexicon.pl, and any in -ly, "quickly ran". Others, "yesterday", "well",
% go after it, in modifiers//5.
pre_adverbs([adv(A)|As]) --> [A], { adv(A), before_verb(A) }, pre_adverbs(As).
pre_adverbs([]) --> [].

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
    { verb(Base, Frames), member(Frame0, Frames), frame(Form, Frame0, Frame) },
    complements(Frame, Tok, Cs, G0, G1, V0, V1),
    modifiers(Ms, G1, G, V1, V),
    { append(Cs, Ms, Items) }.

% A passive has lost its first object to the subject: "the cat was chased",
% "the dog was given a bone".
frame(Form, F, F) :- Form \== pass.
frame(pass, trans, intrans).
frame(pass, ditrans, trans).
frame(pass, obj_pred, pred).
frame(pass, obj_inf, inf).

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
complements(ditrans, _, [O1, O2], G0, G, V0, V) -->
    noun_phrase(_, obj, O1, G0, G1, V0, V1),
    noun_phrase(_, obj, O2, G1, G, V1, V).
complements(pred, _, [A], G, G, V, V) --> adj_group(A).
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

complementizer(that) --> [that].
complementizer(none) --> [].

% What follows be: an adjective, a noun phrase, a bare role noun, or a
% place, with the adverbs that may stand before a verb before it: "is also
% the capital", "is always happy", "was chairman of the board".
predicate(AP, G, G, V, V) --> adj_group(AP).
predicate(NP, G0, G, V0, V) --> noun_phrase(_, _, NP, G0, G, V0, V).
predicate(NP, G, G, V0, V) --> role_np(NP, V0, V).
predicate(PP, G0, G, V0, V) --> pp(PP, G0, G, V0, V).

% Adverbs and prepositional phrases after the verb and what it takes. The
% gap may be a preposition's object: "the park that the dog walks in _".
modifiers([adv(A)|Ms], G0, G, V0, V) --> [A], { adv(A) }, modifiers(Ms, G0, G, V0, V).
modifiers([PP|Ms], G0, G, V0, V) --> pp(PP, G0, G1, V0, V1), modifiers(Ms, G1, G, V1, V).
modifiers([npadv(D, N)|Ms], G0, G, V0, V) -->
    [D, N], { adverbial_np(D, N) }, modifiers(Ms, G0, G, V0, V).
modifiers([], G, G, V, V) --> [].

% adverbial_np(?Word, ?Noun): a noun phrase that is an adverb of time or
% place, "last night", "every day", "next door". last and next are not
% determiners anywhere else, so they are only read here.
adverbial_np(D, N) :- time_det(D), time_noun(N).
adverbial_np(next, door).

time_det(last). time_det(next). time_det(this). time_det(that).
time_det(every). time_det(each).
