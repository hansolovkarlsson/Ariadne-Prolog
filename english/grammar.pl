/*  english/grammar.pl -- simple declarative English sentences, as a DCG.

    sentence(Tree, V0, V) parses a list of words into a tree. V0 and V are a
    difference list of agreement violations, threaded beside the words:

        phrase(sentence(T, [], []), Words)     is grammatical
        phrase(sentence(T, Vs, []), Words)     parses, and Vs says what
                                               disagrees

    The first is the checker: with the list closed, a violation cannot be
    recorded, so every agreement is enforced, by unification alone. The second
    is the diagnosis: the same rules, allowed to record where features did not
    unify. There is one grammar, not a strict one and a lenient one.

    Recursion is on the right throughout: a noun phrase is followed by its
    prepositional phrases, never built from a smaller noun phrase, since a
    rule such as np --> np, pp would make a DCG loop. See docs/ROADMAP.md.
*/

% agree(+What, ?X, ?Y, ?V0, ?V): X and Y agree, or, when the violation list
% is open, What records that they did not.
agree(_, X, Y, V, V) :- X = Y, !.
agree(What, _, _, [What|V], V).

/* ---------------- sentences ---------------- */

sentence(s(NP, VP), V0, V) -->
    noun_phrase(Agr, subj, NP, V0, V1),
    verb_phrase(Agr, VP, V1, V).

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

% verb_phrase(+SubjectAgr, -Tree, V0, V)
verb_phrase(Agr, vp(v(W), Cs, Mods), V0, V) -->
    [W], { verb_form(W, Base, VAgr), verb(Base, Frames),
           agree(subject_verb(W), Agr, VAgr, V0, V1) },
    { member(Frame, Frames) },
    complements(Frame, Cs, V1, V2),
    modifiers(Mods, V2, V).
verb_phrase(Agr, vp(be(W), [C], Mods), V0, V) -->
    [W], { be_form(W, BAgr),
           agree(subject_verb(W), Agr, BAgr, V0, V1) },
    predicate(C, V1, V2),
    modifiers(Mods, V2, V).

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
