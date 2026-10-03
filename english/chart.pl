/*  english/chart.pl -- the grammar, run with a chart.

    grammar.pl is a DCG, and run by phrase/2 a DCG remembers nothing: a
    phrase is parsed again every time the search backtracks past it, the
    same words with the same arguments, so a sentence whose trailing
    phrases each attach in several places costs the product of the
    attachments. This file loads grammar.pl and puts a table in front of
    the nonterminals that are parsed again most: the first call of one,
    at a place in the sentence and with given arguments, finds every
    answer and keeps them; every later call that is the same call, a
    variant of it, at the same place, takes the answers from the table.
    The table is a chart, filled top down: what was found between which
    words, with its agreement, gap and violations.

    The rules are grammar.pl's, unchanged and in their order, so the
    answers are the same and come in the same order. A nonterminal in
    the table is renamed, '$raw'(Name), and Name becomes a call through
    the table; the rules that call it are not touched. The grammar has
    no rule that calls itself at the place it started, being written on
    the right, so every answer to a call is known before the call is
    asked again.

    check.pl loads this file in place of grammar.pl, and clears the
    table before each sentence with new_chart/0, since a place is known
    by the number of words left to read.
*/

:- consult(grammar).

:- dynamic('$chart'/2).
:- dynamic('$charted'/1).

% charted(Name, Arity): a nonterminal of grammar.pl that goes through the
% chart, with its arity as a predicate, two more than as a nonterminal.
charted(noun_phrase, 9).
charted(simple_np, 7).
charted(det_np, 6).
charted(nominal, 8).
charted(pp, 7).
charted(pps, 5).
charted(relative, 6).
charted(verb_phrase, 10).
charted(modifiers, 7).
charted(statement, 7).

% new_chart: forget every call and answer, before a sentence is parsed.
new_chart :-
    retractall('$chart'(_, _)),
    retractall('$charted'(_)).

% chart_call(+Raw, +Name, ?Goal, ?S0, ?S): Goal is a call of Name with
% the words S0 left to read and S left after it; Raw is the same call to
% the rules themselves. The key is an atom, for the first-argument
% index: the name, the number of words left, and the call with its
% variables numbered, which stands for every call that is a variant of
% it. Each answer is a clause of its own, so that a lookup copies an
% answer only when the search reaches it, and '$charted'/1 records that
% the answers to a key are all there. They are found with findall/3 and
% asserted after, since the interpreter has no logical update view: a
% lookup walking '$chart' sees what is asserted while it walks.
chart_call(Raw, Name, Goal, S0, S) :-
    length(S0, Left),
    copy_term(Goal, Variant), numbervars(Variant, 0, _),
    term_to_atom(Name-Left-Variant, Key),
    (   '$charted'(Key)
    ->  true
    ;   findall(Goal-S, Raw, Answers),
        forall(member(A, Answers), assertz('$chart'(Key, A))),
        assertz('$charted'(Key))
    ),
    '$chart'(Key, Goal-S).

% chart_grammar: each charted nonterminal's clauses renamed, and the
% name made a call through the chart. The renamed clauses are asserted,
% so a second consult of grammar.pl, which replaces the clauses it
% loaded, would leave them doubled: they are cleared first.
chart_grammar :-
    forall(charted(Name, Arity), chart_nonterminal(Name, Arity)).

chart_nonterminal(Name, Arity) :-
    functor(Head, Name, Arity),
    findall(Head-Body, clause(Head, Body), Clauses),
    atom_concat('$raw_', Name, RawName),
    abolish(Name/Arity),
    functor(Old, RawName, Arity),
    retractall(Old),
    forall(member(H-B, Clauses),
           ( H =.. [_|Args], RawHead =.. [RawName|Args],
             assertz((RawHead :- B)) )),
    functor(Call, Name, Arity),
    Call =.. [_|CallArgs],
    append(GoalArgs, [S0, S], CallArgs),
    Goal =.. [Name|GoalArgs],
    Raw =.. [RawName|CallArgs],
    assertz((Call :- chart_call(Raw, Name, Goal, S0, S))).

:- chart_grammar.
