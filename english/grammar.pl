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

    Recursion is on the right throughout: a noun phrase is followed by its
    prepositional phrases, never built from a smaller noun phrase, since a
    rule such as np --> np, pp would make a DCG loop. See docs/ROADMAP.md.
*/

% agree(+What, ?X, ?Y, ?V0, ?V): X and Y agree, or, when the violation list
% is open, What records that they did not.
agree(_, X, Y, V, V) :- X = Y, !.
agree(What, _, _, [What|V], V).

% violation(+What, ?V0, ?V): What is recorded, which only the diagnosis can
% do; for the strict grammar this is a rule that fails.
violation(What, [What|V], V).

/* ---------------- sentences ---------------- */

% A statement, and a yes/no question: the first verb before the subject,
% then what that verb takes, as in the statement. "Does the dog bark",
% "is the dog happy", "has the dog not eaten".
sentence(s(NP, VP), V0, V) -->
    noun_phrase(Agr, subj, NP, V0, V1),
    verb_phrase(fin(Agr), 1, subject, VP, V1, V).
sentence(q(Tok, NP, Neg, Items), V0, V) -->
    [Tok], { head_word(Tok, W, Neg0), head(W, Kind, Base, F),
             inverts(Kind, Tok, V0, V1) },
    noun_phrase(Agr, subj, NP, V1, V2),
    { form_ok(fin(Agr), subject, Tok, F, V2, V3) },
    after_subject(Neg0, Neg),
    rest(Kind, Base, Tok, fin(Agr), Items, V3, V).

% Only an auxiliary, or be, goes before the subject; a verb needs do:
% "does the dog bark", not "barks the dog".
inverts(Kind, _, V, V) :- Kind \== lex.
inverts(lex, Tok, V0, V) :- violation(question_do(Tok), V0, V).

% In a question, not comes after the subject unless it is joined to the
% verb: "does the dog not bark", "doesn't the dog bark".
after_subject(none, not) --> [not].
after_subject(_, none) --> [].

/* ---------------- noun phrases ---------------- */

% noun_phrase(-Agr, +Case, -Tree, V0, V). Two noun phrases joined by and
% are plural: "the dog and the cat chase".
noun_phrase(agr(n, n, n), Case, and(T1, T2), V0, V) -->
    simple_np(_, Case, T1, V0, V1), [and], noun_phrase(_, Case, T2, V1, V).
noun_phrase(Agr, Case, T, V0, V) -->
    simple_np(Agr, Case, T, V0, V).

simple_np(Agr, Case, pro(W), V0, V) -->
    [W], { pronoun(W, Agr, PCase),
           agree(case(W), PCase, Case, V0, V) }.
simple_np(Agr, _, name(W), V, V) -->
    [W], { proper(W), agr_of(sg, Agr) }.
simple_np(Agr, _, np(det(D), N), V0, V) -->
    [D], { det(D, DNum, DSound) },
    nominal(Num, First, Head, N, V0, V1),
    { agree(det_noun(D, Head), DNum, Num, V1, V2),
      sound(First, Sound),
      agree(article(D, First), DSound, Sound, V2, V),
      agr_of(Num, Agr) }.
simple_np(Agr, _, np(N), V0, V) -->
    nominal(Num, _, Head, N, V0, V1),
    { agree(bare(Head), Num, pl, V1, V),
      agr_of(Num, Agr) }.

% nominal(-Number, -FirstWord, -HeadNoun, -Tree, V0, V): adjectives, the
% noun, and the prepositional phrases after it.
nominal(Num, First, Head, nom(As, n(Head), PPs), V0, V) -->
    adjectives(As),
    [Head], { noun_form(Head, _, Num) },
    { As = [adj(First)|_] -> true ; First = Head },
    pps(PPs, V0, V).

adjectives([adj(A)|As]) --> [A], { adj(A) }, adjectives(As).
adjectives([]) --> [].

pps([PP|PPs], V0, V) --> pp(PP, V0, V1), pps(PPs, V1, V).
pps([], V, V) --> [].

pp(pp(P, NP), V0, V) --> [P], { prep(P) }, noun_phrase(_, obj, NP, V0, V).

/* ---------------- verb phrases ---------------- */

% verb_phrase(+Form, +Rank, +Prev, -Tree, V0, V): a verb phrase whose first
% word is in Form: fin(Agr) at the start of a sentence, where it agrees
% with the subject, or the base, ing, en or passive form the auxiliary
% before it asks for. Prev is that auxiliary, for the diagnosis. Rank is
% the lowest rank the first word may have: an auxiliary is followed only by
% ones ranked above it, which is English's order.
verb_phrase(Form, Min, Prev, vp(Tok, Neg, Items), V0, V) -->
    [Tok], { head_word(Tok, W, Neg0), head(W, Kind, Base, F),
             rank(Kind, R), R >= Min,
             form_ok(Form, Prev, Tok, F, V0, V1) },
    negation(Form, Kind, Tok, Neg0, Neg, V1, V2),
    rest(Kind, Base, Tok, Form, Items, V2, V).

% head_word(+Token, -Word, -Neg): a contraction is its auxiliary, negated.
head_word(Tok, Tok, none).
head_word(Tok, W, contracted) :- neg_contraction(Tok, W).

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

% rest(+Kind, +Base, +Token, +Form, -Items, V0, V): what follows the word.
rest(modal, _, Tok, _, [VP], V0, V) --> verb_phrase(base, 2, Tok, VP, V0, V).
rest(do,    _, Tok, _, [VP], V0, V) --> verb_phrase(base, 6, Tok, VP, V0, V).
rest(perf,  _, Tok, _, [VP], V0, V) --> verb_phrase(en, 3, Tok, VP, V0, V).
rest(prog,  _, Tok, _, [VP], V0, V) --> verb_phrase(ing, 4, Tok, VP, V0, V).
rest(pass,  _, Tok, _, [VP], V0, V) --> verb_phrase(pass, 6, Tok, VP, V0, V).
rest(cop,   _, _, _, [C|Ms], V0, V) -->
    predicate(C, V0, V1),
    modifiers(Ms, V1, V).
rest(lex, Base, _, Form, Items, V0, V) -->
    { verb(Base, Frames), member(Frame0, Frames), frame(Form, Frame0, Frame) },
    complements(Frame, Cs, V0, V1),
    modifiers(Ms, V1, V),
    { append(Cs, Ms, Items) }.

% A passive has lost its first object to the subject: "the cat was chased",
% "the dog was given a bone".
frame(Form, F, F) :- Form \== pass.
frame(pass, trans, intrans).
frame(pass, ditrans, trans).

complements(intrans, [], V, V) --> [].
complements(trans, [O], V0, V) --> noun_phrase(_, obj, O, V0, V).
complements(ditrans, [O1, O2], V0, V) -->
    noun_phrase(_, obj, O1, V0, V1), noun_phrase(_, obj, O2, V1, V).

% What follows be: an adjective, a noun phrase, or a place.
predicate(adj(A), V, V) --> [A], { adj(A) }.
predicate(NP, V0, V) --> noun_phrase(_, _, NP, V0, V).
predicate(PP, V0, V) --> pp(PP, V0, V).

% Adverbs and prepositional phrases after the verb and what it takes.
modifiers([adv(A)|Ms], V0, V) --> [A], { adv(A) }, modifiers(Ms, V0, V).
modifiers([PP|Ms], V0, V) --> pp(PP, V0, V1), modifiers(Ms, V1, V).
modifiers([], V, V) --> [].
