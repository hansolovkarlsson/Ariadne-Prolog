/*  english/check.pl -- says whether a sentence is grammatical, and why not.

    Run from the top of the repository, as the tutorial programs are:

        ./prolog -q english/check.pl -g "check('The dogs chase a cat.')"
        ./prolog -q english/check.pl -g "check('The dogs chases a cat.')"

    check/1 takes the sentence as an atom. When the sentence is grammatical
    it prints every reading as a labelled bracketing, [S [NP the dogs] ...],
    so an ambiguous sentence shows each of its structures; otherwise it
    parses again with agreement relaxed, and names what disagreed if that
    finds a reading. grammatical/2 is the check without the printing, for
    programs, and brackets/2 turns a tree into its bracketing.
*/

:- consult('english/lexicon').
:- consult('english/grammar').

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
    ;   findall(T, phrase(sentence(T, [], []), Words), Trees), Trees \== []
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

% diagnosis(+Words, -Violations): the reading with the fewest violations, if
% the grammar can read Words at all once agreement is relaxed.
diagnosis(Words, Violations) :-
    findall(N-Vs, ( phrase(sentence(_, Vs, []), Words), length(Vs, N) ), Readings),
    Readings \== [],
    msort(Readings, [_-Violations|_]).

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

unknown_words(Words, Unknown) :- exclude(known_word, Words, Unknown).

known_word(W) :- noun_form(W, _, _), !.
known_word(W) :- verb_form(W, _, _), !.
known_word(W) :- be_form(W, _), !.
known_word(W) :- proper(W), !.
known_word(W) :- pronoun(W, _, _), !.
known_word(W) :- det(W, _, _), !.
known_word(W) :- adj(W), !.
known_word(W) :- prep(W), !.
known_word(W) :- adv(W), !.
known_word(and).

/* ---------------- brackets ---------------- */

% brackets(+Tree, -Atom): the tree as a labelled bracketing, the notation
% linguists write a parse in: [S [NP the dogs] [VP chase [NP a cat]]].
brackets(Tree, Atom) :-
    phrase(bracket(Tree), Parts),
    atomic_list_concat(Parts, ' ', Atom0),
    tidy(Atom0, Atom).

bracket(s(NP, VP))         --> ['[S'], bracket(NP), bracket(VP), [']'].
bracket(and(A, B))         --> ['[NP'], bracket(A), [and], bracket(B), [']'].
bracket(pro(W))            --> ['[NP', W, ']'].
bracket(name(W))           --> ['[NP', W, ']'].
bracket(np(det(D), Nom))   --> ['[NP', D], nom(Nom), [']'].
bracket(np(Nom))           --> ['[NP'], nom(Nom), [']'].
bracket(pp(P, NP))         --> ['[PP', P], bracket(NP), [']'].
bracket(vp(V, Cs, Ms))     --> ['[VP'], verb_word(V), items(Cs), items(Ms), [']'].
bracket(adj(A))            --> ['[AP', A, ']'].
bracket(adv(A))            --> ['[AdvP', A, ']'].

nom(nom(As, n(H), PPs)) --> adjective_words(As), [H], items(PPs).

adjective_words([]) --> [].
adjective_words([adj(A)|As]) --> [A], adjective_words(As).

verb_word(v(W))  --> [W].
verb_word(be(W)) --> [W].

items([]) --> [].
items([T|Ts]) --> bracket(T), items(Ts).

% The parts are joined with spaces; a closing bracket takes none before it.
tidy(A0, A) :-
    atomic_list_concat(Parts, ' ]', A0),
    atomic_list_concat(Parts, ']', A).

/* ---------------- words ---------------- */

% words(+Text, -Words): Text lowercased and cut into words at anything that
% is not a letter, so punctuation falls away: 'The dog barks.' gives
% [the, dog, barks].
words(Text, Words) :-
    downcase_atom(Text, Lower),
    atom_chars(Lower, Chars),
    split_letters(Chars, Words).

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
take_letters(Rest, [], Rest).

letter(C) :- char_code(C, X), X >= 0'a, X =< 0'z.
