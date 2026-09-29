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
sentence(T, V0, V) -->
    statement(S, nogap, nogap, V0, V1),
    clauses_after(S, T, V1, V).
sentence(T, V0, V) --> question(T, nogap, nogap, V0, V).
sentence(T, V0, V) --> wh_question(T, V0, V).
sentence(sub_first(C, S1, T), V0, V) -->
    [C], { subordinator(C) },
    statement(S1, nogap, nogap, V0, V1),
    statement(S2, nogap, nogap, V1, V2),
    clauses_after(S2, T, V2, V).

% clauses_after(+First, -Tree, V0, V): the statement First alone, or joined
% to the statements after it, each by a conjunction: "I like coffee but my
% brother prefers tea", "he opened the window because the room was hot".
% A clause may also open with its subordinator, "because the room was hot
% he opened the window", which is the last rule for sentence//3. The chain
% is read left to right and nests on the right, so no rule calls itself on
% the left.
clauses_after(S, S, V, V) --> [].
clauses_after(S1, joined(C, S1, T), V0, V) -->
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

% noun_phrase(-Agr, +Case, -Tree, G0, G, V0, V). Two noun phrases joined by
% and are plural: "the dog and the cat chase". A noun phrase can be the gap
% itself, taking no words, when one is waiting to be placed. A gap is never
% a subject, so it stands only where nothing agrees with it and any
% relative or question word may stand: whom in a subject's place is caught
% by the rules for a missing subject.
noun_phrase(_, _, gap, gap, nogap, V, V) --> [].
noun_phrase(agr(n, n, n), Case, and(T1, T2), G, G, V0, V) -->
    simple_np(_, Case, T1, V0, V1), [and],
    noun_phrase(_, Case, T2, nogap, nogap, V1, V).
noun_phrase(Agr, Case, T, G, G, V0, V) -->
    simple_np(Agr, Case, T, V0, V).

simple_np(Agr, Case, pro(W), V0, V) -->
    [W], { pronoun(W, Agr, PCase),
           agree(case(W), PCase, Case, V0, V) }.
simple_np(Agr, _, name(W), V, V) -->
    [W], { proper(W), agr_of(sg, Agr) }.
simple_np(Agr, _, num(W), V, V) -->
    [W], { number_word(W, Num), agr_of(Num, Agr) }.
simple_np(Agr, _, np(det(D), N), V0, V) -->
    determiner(D, DNum, DSound),
    nominal(Num, First, Head, N, V0, V1),
    { det_agrees(D, Head, DNum, Num, V1, V2),
      sound(First, Sound),
      agree(article(D, First), DSound, Sound, V2, V),
      agr_of(Num, Agr) }.
simple_np(Agr, _, np(N), V0, V) -->
    nominal(Num, _, Head, N, V0, V1),
    { bare_ok(Head, Num, V1, V),
      agr_of(Num, Agr) }.
simple_np(Agr, _, np(poss(P), N), V0, V) -->
    possessive_ahead,
    possessor(P, V0, V1),
    nominal(Num, _, _, N, V1, V),
    { agr_of(Num, Agr) }.

% determiner(-Det, -Number, -Sound): a determiner, or a number that takes
% one before it, "a hundred", "two thousand", which counts as one word.
determiner(D, DNum, DSound) --> [D], { det(D, DNum, DSound) }.
determiner(D, pl, _) -->
    [A, B], { ( A == a ; number_word(A, _) ), big_number(B),
              atomic_list_concat([A, B], ' ', D) }.

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

possessor_base(name(W), V, V) --> [W], { proper(W) }.
possessor_base(np(det(D), N), V0, V) -->
    [D], { det(D, DNum, DSound) },
    core_nominal(Num, First, Head, N),
    { det_agrees(D, Head, DNum, Num, V0, V1),
      sound(First, Sound),
      agree(article(D, First), DSound, Sound, V1, V) }.
possessor_base(np(N), V0, V) -->
    core_nominal(Num, _, Head, N),
    { bare_ok(Head, Num, V0, V) }.

% bare_ok(+Head, +Number, V0, V): a noun with no determiner is plural, "dogs
% bark", or a mass noun, "water boils"; a singular count noun needs one.
bare_ok(Head, sg, V, V) :- mass(Head), !.
bare_ok(Head, Num, V0, V) :- agree(bare(Head), Num, pl, V0, V).

% det_agrees(+Det, +Head, ?DetNumber, +Number, V0, V): the determiner and
% the noun agree in number. A singular mass noun also takes some and much,
% "some homework", "much bread"; much takes nothing else.
det_agrees(D, Head, DNum, sg, V, V) :-
    mass(Head), ( DNum == mass ; D == some ), !.
det_agrees(D, Head, DNum, Num, V0, V) :-
    agree(det_noun(D, Head), DNum, Num, V0, V).

% core_nominal(-Number, -FirstWord, -HeadNoun, -Tree): adjectives and a noun.
core_nominal(Num, First, Head, nom(As, n(Head), [])) -->
    adjectives(As),
    [Head], { noun_form(Head, _, Num) },
    { As = [adj(First)|_] -> true ; First = Head }.

% nominal(-Number, -FirstWord, -HeadNoun, -Tree, V0, V): adjectives, the
% noun, the prepositional phrases after it, and a relative clause.
nominal(Num, First, Head, nom(As, n(Head), Posts), V0, V) -->
    adjectives(As),
    [Head], { noun_form(Head, _, Num) },
    { As = [adj(First)|_] -> true ; First = Head },
    pps(PPs, V0, V1),
    { agr_of(Num, Agr) },
    relative(Agr, Rels, V1, V),
    { append(PPs, Rels, Posts) }.

adjectives([adj(A)|As]) --> [A], { adj(A) }, adjectives(As).
adjectives([]) --> [].

pps([PP|PPs], V0, V) --> pp(PP, nogap, nogap, V0, V1), pps(PPs, V1, V).
pps([], V, V) --> [].

pp(pp(P, NP), G0, G, V0, V) -->
    [P], { prep(P) }, noun_phrase(_, obj, NP, G0, G, V0, V).

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

/* ---------------- verb phrases ---------------- */

% verb_phrase(+Form, +Rank, +Prev, -Tree, G0, G, V0, V): a verb phrase whose
% first word is in Form: fin(Agr) at the start of a sentence, where it
% agrees with the subject, or the base, ing, en or passive form the
% auxiliary before it asks for. Prev is that auxiliary, for the diagnosis.
% Rank is the lowest rank the first word may have: an auxiliary is followed
% only by ones ranked above it, which is English's order.
verb_phrase(Form, Min, Prev, vp(Tok, Neg, Items), G0, G, V0, V) -->
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
rest(cop,   _, _, _, [C|Ms], G0, G, V0, V) -->
    predicate(C, G0, G1, V0, V1),
    modifiers(Ms, G1, G, V1, V).
rest(lex, Base, _, Form, Items, G0, G, V0, V) -->
    { verb(Base, Frames), member(Frame0, Frames), frame(Form, Frame0, Frame) },
    complements(Frame, Cs, G0, G1, V0, V1),
    modifiers(Ms, G1, G, V1, V),
    { append(Cs, Ms, Items) }.

% A passive has lost its first object to the subject: "the cat was chased",
% "the dog was given a bone".
frame(Form, F, F) :- Form \== pass.
frame(pass, trans, intrans).
frame(pass, ditrans, trans).

complements(intrans, [], G, G, V, V) --> [].
complements(trans, [O], G0, G, V0, V) --> noun_phrase(_, obj, O, G0, G, V0, V).
complements(ditrans, [O1, O2], G0, G, V0, V) -->
    noun_phrase(_, obj, O1, G0, G1, V0, V1),
    noun_phrase(_, obj, O2, G1, G, V1, V).

% What follows be: an adjective, a noun phrase, or a place.
predicate(adj(A), G, G, V, V) --> [A], { adj(A) }.
predicate(NP, G0, G, V0, V) --> noun_phrase(_, _, NP, G0, G, V0, V).
predicate(PP, G0, G, V0, V) --> pp(PP, G0, G, V0, V).

% Adverbs and prepositional phrases after the verb and what it takes. The
% gap may be a preposition's object: "the park that the dog walks in _".
modifiers([adv(A)|Ms], G0, G, V0, V) --> [A], { adv(A) }, modifiers(Ms, G0, G, V0, V).
modifiers([PP|Ms], G0, G, V0, V) --> pp(PP, G0, G1, V0, V1), modifiers(Ms, G1, G, V1, V).
modifiers([], G, G, V, V) --> [].
