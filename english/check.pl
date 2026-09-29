/*  english/check.pl -- says whether a sentence is grammatical, and why not.

    It loads its other files from beside itself, so it runs from anywhere:

        bin/prolog -q english/check.pl -g "check('The dogs chase a cat.')"
        bin/prolog -q english/check.pl -g "check('The dogs chases a cat.')"

    check/1 takes the sentence as an atom. When the sentence is grammatical
    it prints every reading as a labelled bracketing, [S [NP the dogs] ...],
    so an ambiguous sentence shows each of its structures; otherwise it
    parses again with agreement relaxed, and names what disagreed if that
    finds a reading. grammatical/2 is the check without the printing, for
    programs, and brackets/2 turns a tree into its bracketing.
*/

:- consult(lexicon).
:- consult(grammar).

% grammatical(+Text, -Tree): Text is an atom; Tree is a reading of it.
grammatical(Text, Tree) :-
    words(Text, Words),
    phrase(sentence(Tree, [], []), Words).

% check(+Text)
check(Text) :-
    words(Text, Words),
    (   Words == []
    ->  format("no words~n")
    ;   unknown_words(Words, Unknown), Unknown \== []
    ->  format("not grammatical: not in the lexicon: ~w~n", [Unknown])
    ;   all_readings(Words, Trees), Trees \== []
    ->  length(Trees, N),
        (   N =:= 1
        ->  Trees = [T1], brackets(T1, B), format("grammatical: ~w~n", [B])
        ;   format("grammatical, ~d readings:~n", [N]),
            forall(member(T, Trees), (brackets(T, B), format("  ~w~n", [B])))
        )
    ;   diagnosis(Words, Violations)
    ->  format("not grammatical: "),
        explain(Violations)
    ;   format("not grammatical: the words do not make a sentence this grammar knows~n")
    ).

% all_readings(+Words, -Trees): every distinct reading. A word can be one form
% twice over, as read is both present and past, and the tree does not say
% which, so the same tree is found twice and counted once.
all_readings(Words, Trees) :-
    findall(T, phrase(sentence(T, [], []), Words), Trees0),
    sort(Trees0, Trees).

% diagnosis(+Words, -Violations): the reading with the least wrong, if the
% grammar can read Words at all once agreement is relaxed. A verb out of
% its place counts twice, since it is a bigger departure than a wrong
% ending: "which dogs chases the cat" is chases disagreeing with which
% dogs, not chases put before the cat without do.
diagnosis(Words, Violations) :-
    findall(N-Vs, ( phrase(sentence(_, Vs, []), Words), cost(Vs, N) ), Readings),
    Readings \== [],
    msort(Readings, [_-Violations|_]).

cost([], 0).
cost([V|Vs], N) :- cost(Vs, N0), weight(V, W), N is N0 + W.

weight(question_do(_), 2) :- !.
weight(do_support(_), 2) :- !.
weight(_, 1).

explain([]).
explain([V|Vs]) :- message(V, M), format("~w~n", [M]), explain_rest(Vs).

explain_rest([]).
explain_rest([V|Vs]) :- message(V, M), format("  and ~w~n", [M]), explain_rest(Vs).

message(subject_verb(W), M) :-
    format(atom(M), "the verb '~w' does not agree with its subject", [W]).
message(det_noun(D, N), M) :-
    format(atom(M), "'~w' does not agree in number with '~w'", [D, N]).
message(article(D, W), M) :-
    ( D == a -> Other = an ; Other = a ),
    format(atom(M), "'~w ~w' should be '~w ~w'", [D, W, Other, W]).
message(case(W), M) :-
    format(atom(M), "the pronoun '~w' is in the wrong case for where it stands", [W]).
message(bare(N), M) :-
    format(atom(M), "the singular noun '~w' needs a determiner, such as 'the' or 'a'", [N]).
message(verb_form(Prev, W, Form), M) :-
    (   lemma(W, Base), form_of(Base, Form, Right)
    ->  format(atom(M), "after '~w' the verb should be '~w', not '~w'", [Prev, Right, W])
    ;   format(atom(M), "'~w' cannot follow '~w'", [W, Prev])
    ).
message(finite(W), M) :-
    format(atom(M), "'~w' cannot be the first verb after its subject; it needs one such as 'is' or 'has' before it", [W]).
message(do_support(W), M) :-
    do_for(W, Do, Base),
    format(atom(M), "'~w not' should be '~w not ~w'", [W, Do, Base]).
message(question_do(W), M) :-
    do_for(W, Do, Base),
    format(atom(M), "a question with '~w' puts '~w' before the subject and '~w' after it", [W, Do, Base]).

% lemma(+Word, -Base): the verb a form belongs to.
lemma(W, Base) :- neg_contraction(W, Aux), !, lemma(Aux, Base).
lemma(W, W)    :- modal(W), !.
lemma(W, do)   :- do_form(W, _), !.
lemma(W, be)   :- be_form(W, _), !.
lemma(W, Base) :- verb_form(W, Base, _), !.

% form_of(+Base, +Form, -Word): Base in Form, the first such word.
form_of(be, Form, W)   :- be_form(W, Form), !.
form_of(Base, Form, W) :- verb_form(W, Base, Form), !.

% do_for(+Word, -Do, -Base): the do that a verb form needs, and its base:
% barks gives does and bark, barked gives did and bark.
do_for(W, Do, Base) :-
    verb_form(W, Base, fin(Agr)),
    (   W == Base       -> Do = do
    ;   Agr = agr(_, y, _), \+ past(Base, W) -> Do = does
    ;   Do = did
    ), !.

unknown_words(Words, Unknown) :- exclude(known_word, Words, Unknown).

known_word(W) :- noun_form(W, _, _), !.
known_word(W) :- verb_form(W, _, _), !.
known_word(W) :- be_form(W, _), !.
known_word(W) :- have_form(W, _), !.
known_word(W) :- do_form(W, _), !.
known_word(W) :- modal(W), !.
known_word(W) :- neg_contraction(W, _), !.
known_word(W) :- proper(W), !.
known_word(W) :- pronoun(W, _, _), !.
known_word(W) :- det(W, _, _), !.
known_word(W) :- adj(W), !.
known_word(W) :- prep(W), !.
known_word(W) :- adv(W), !.
known_word(W) :- rel_pronoun(W, _), !.
known_word(W) :- wh_pronoun(W, _), !.
known_word(W) :- wh_det(W), !.
known_word(W) :- wh_adverb(W), !.
known_word(and).
known_word(not).

/* ---------------- brackets ---------------- */

% brackets(+Tree, -Atom): the tree as a labelled bracketing, the notation
% linguists write a parse in: [S [NP the dogs] [VP chase [NP a cat]]].
brackets(Tree, Atom) :-
    phrase(bracket(Tree), Parts),
    atomic_list_concat(Parts, ' ', Atom0),
    tidy(Atom0, Atom).

bracket(s(NP, VP))         --> ['[S'], bracket(NP), bracket(VP), [']'].
bracket(q(W, NP, Neg, Is)) --> ['[SQ', W], bracket(NP), neg(Neg), items(Is), [']'].
bracket(wh(W, C))          --> ['[SBARQ'], bracket(W), bracket(C), [']'].
bracket(wh_pro(W))         --> ['[WHNP', W, ']'].
bracket(wh_np(D, Nom))     --> ['[WHNP', D], nom(Nom), [']'].
bracket(whadv(A))          --> ['[WHADVP', A, ']'].
bracket(rel(none, S))      --> ['[SBAR'], bracket(S), [']'].
bracket(rel(W, C))         --> { W \== none }, ['[SBAR', W], bracket(C), [']'].
bracket(gap)               --> ['_'].
bracket(and(A, B))         --> ['[NP'], bracket(A), [and], bracket(B), [']'].
bracket(pro(W))            --> ['[NP', W, ']'].
bracket(name(W))           --> ['[NP', W, ']'].
bracket(np(det(D), Nom))   --> ['[NP', D], nom(Nom), [']'].
bracket(np(Nom))           --> ['[NP'], nom(Nom), [']'].
bracket(pp(P, NP))         --> ['[PP', P], bracket(NP), [']'].
bracket(vp(W, Neg, Is))    --> ['[VP', W], neg(Neg), items(Is), [']'].
bracket(adj(A))            --> ['[AP', A, ']'].
bracket(adv(A))            --> ['[AdvP', A, ']'].

nom(nom(As, n(H), PPs)) --> adjective_words(As), [H], items(PPs).

adjective_words([]) --> [].
adjective_words([adj(A)|As]) --> [A], adjective_words(As).

neg(not)  --> [not].
neg(none) --> [].

items([]) --> [].
items([T|Ts]) --> bracket(T), items(Ts).

% The parts are joined with spaces; a closing bracket takes none before it.
tidy(A0, A) :-
    atomic_list_concat(Parts, ' ]', A0),
    atomic_list_concat(Parts, ']', A).

/* ---------------- words ---------------- */

% words(+Text, -Words): Text lowercased and cut into words at anything that
% is not a letter, so punctuation falls away: 'The dog barks.' gives
% [the, dog, barks]. A letter is what char_type/2 calls alpha, so a word
% with an accented letter stays one word. An apostrophe between letters
% belongs to the word, so doesn't is one word; a typographic apostrophe is
% read as the plain one.
words(Text, Words) :-
    downcase_atom(Text, Lower),
    atom_chars(Lower, Chars0),
    maplist(plain_apostrophe, Chars0, Chars),
    split_letters(Chars, Words).

plain_apostrophe('\x2019\', '\'') :- !.
plain_apostrophe(C, C).

split_letters([], []).
split_letters([C|Cs], Words) :-
    (   letter(C)
    ->  take_letters([C|Cs], Letters, Rest),
        atom_chars(W, Letters),
        Words = [W|Ws],
        split_letters(Rest, Ws)
    ;   split_letters(Cs, Words)
    ).

take_letters([C|Cs], [C|Ls], Rest) :- letter(C), !, take_letters(Cs, Ls, Rest).
take_letters(['\'', C|Cs], ['\'', C|Ls], Rest) :-
    letter(C), !, take_letters(Cs, Ls, Rest).
take_letters(Rest, [], Rest).

letter(C) :- char_type(C, alpha).
