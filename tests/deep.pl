/*  tests/deep.pl -- terms nested a million deep, in every walk.

    Run with:  make test-deep  (or bin/prolog -q tests/deep.pl -g run)

    Each walk over a term, and the reader and the writer, once used the C
    stack for every level of nesting outside the last argument, so a term
    such as 1+1+...+1 killed the interpreter with SIGSEGV at about 100,000
    levels, and the reader gave out at 5000. These checks build such terms
    and put each walk through them.

    This is not part of tests/test.pl because the collector only runs when
    no choice point is live, and run_tests always holds one: nothing in
    that suite is ever collected. Here run/0 is deterministic, the deep
    terms are built at the top level, and the last check fails unless the
    collector ran while they were live.
*/

depth(1000000).

% left(N, A, T): T is A+1+1+...+1, nested N deep in its first argument.
left(0, T, T) :- !.
left(N, A, T) :- N1 is N - 1, left(N1, A+1, T).

% right(N, T): T is (a, (a, ... a)), nested N deep in its last argument.
right(0, a) :- !.
right(N, (a, T)) :- N1 is N - 1, right(N1, T).

% nest(N, Open, Close, Inner, Text): Open repeated N times, Inner, Close N times.
nest(N, Open, Close, Inner, Text) :-
    length(Os, N), maplist(=(Open), Os),
    length(Cs, N), maplist(=(Close), Cs),
    append(Os, [Inner|Cs], Parts),
    atomic_list_concat(Parts, Text).

:- dynamic(held/1).

check(Name, Goal) :-
    (   catch(Goal, E, (format("FAIL  ~w: raised ~q~n", [Name, E]), halt(1)))
    ->  nb_getval(deep_passed, P0), P is P0 + 1, nb_setval(deep_passed, P)
    ;   format("FAIL  ~w~n", [Name]), halt(1)
    ).

run :-
    nb_setval(deep_passed, 0),
    depth(N),
    statistics(garbage_collection, [C0|_]),
    left(N, 1, T), left(N, 1, T2), left(N, 2, T3),
    left(N, V, TV),
    check(copy_term,      (copy_term(T, C), C == T)),
    check(unify,          T = T2),
    check(equal,          T == T2),
    check(compare,        (compare(O, T, T3), O == (<))),
    check(msort,          (msort([T3, T, T2], [S1, S2, S3]), S1 == T, S2 == T, S3 == T3)),
    check(findall,        (findall(T, true, [F]), F == T)),
    check(assert,         (assertz(held(T)), held(H), H == T, retract(held(_)))),
    check(throw,          (catch(throw(T), B, true), B == T)),
    check(write,          (with_output_to(atom(A), write(T)), atom_length(A, L), L > N)),
    check(is,             (X is T, X =:= N + 1)),
    check(ground,         (ground(T), \+ ground(TV))),
    check(term_variables, (term_variables(TV, Vs), Vs == [V])),
    check(occurs_check,   \+ unify_with_occurs_check(V, TV)),
    check(variant,        (copy_term(TV, CV), TV =@= CV)),
    check(numbervars,     (copy_term(TV, NV), numbervars(NV, 0, E), E == 1)),
    check(read_back,      (with_output_to(atom(A2), writeq(T)), atom_to_term(A2, R, _), R == T)),
    check(read_right,     (right(N, RT), with_output_to(atom(A3), writeq(RT)),
                           atom_to_term(A3, RR, _), RR == RT)),
    check(read_compound,  (nest(N, 'f(', ')', x, A4), atom_to_term(A4, R4, _),
                           functor(R4, f, 1))),
    check(read_brackets,  (nest(N, '(', ')', x, A5), atom_to_term(A5, R5, _), R5 == x)),
    check(read_lists,     (nest(N, '[', ']', '', A6), atom_to_term(A6, R6, _),
                           R6 = [_])),
    check(read_prefix,    (nest(N, '- ', '', x, A7), atom_to_term(A7, R7, _),
                           R7 = -(_))),
    statistics(garbage_collection, [C1|_]),
    check(collected,      C1 > C0),
    nb_getval(deep_passed, P),
    Collected is C1 - C0,
    format("~d deep checks passed, depth ~d, ~d collections~n", [P, N, Collected]).
