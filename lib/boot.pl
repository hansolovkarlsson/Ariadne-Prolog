/*  boot.pl -- the bootstrap library.

    This file is consulted at start-up (it is compiled into the executable).
    It defines everything that is easier to express in Prolog than in C:
    control predicates, list handling, bagof/setof, DCG translation and the
    listing predicates.
*/

/* ------------------------------------------------------------------ */
/* Control                                                            */
/* ------------------------------------------------------------------ */

not(Goal) :- \+ Goal.

once(Goal) :- call(Goal), !.

ignore(Goal) :- ( call(Goal) -> true ; true ).

forall(Cond, Action) :- \+ ( Cond, \+ Action ).

apply(Goal, Args) :- Goal =.. L0, append(L0, Args, L), G =.. L, call(G).

assertion(Goal) :-
    (   \+ \+ call(Goal)
    ->  true
    ;   throw(error(assertion_failed(Goal), _))
    ).

/* ------------------------------------------------------------------ */
/* Errors                                                             */
/* ------------------------------------------------------------------ */

must_be(Type, X) :-
    (   '$has_type'(Type, X)
    ->  true
    ;   var(X), Type \== var
    ->  throw(error(instantiation_error, _))
    ;   throw(error(type_error(Type, X), _))
    ).

'$has_type'(integer, X)  :- integer(X).
'$has_type'(atom, X)     :- atom(X).
'$has_type'(atomic, X)   :- atomic(X).
'$has_type'(callable, X) :- callable(X).
'$has_type'(var, X)      :- var(X).
'$has_type'(nonvar, X)   :- nonvar(X).
'$has_type'(number, X)   :- number(X).
'$has_type'(float, X)    :- float(X).
'$has_type'(boolean, X)  :- (X == true ; X == false).
'$has_type'(list, X)     :- is_list(X).
'$has_type'(positive_integer, X) :- integer(X), X > 0.
'$has_type'(nonneg, X)   :- integer(X), X >= 0.

'$type_error'(Type, Culprit) :- throw(error(type_error(Type, Culprit), _)).
'$dom_error'(Dom, Culprit)   :- throw(error(domain_error(Dom, Culprit), _)).
'$inst_error'                :- throw(error(instantiation_error, _)).

/* ------------------------------------------------------------------ */
/* Arithmetic helpers                                                 */
/* ------------------------------------------------------------------ */

/*  between/3 and repeat/0 are builtins written in C.  Both are generators, and
    written in Prolog each would leave a new choice point per solution, which
    makes a failure-driven loop over them grow the heap.  In C they retry a
    single choice point in place instead, so such a loop runs in constant space.
*/

/* ------------------------------------------------------------------ */
/* Lists                                                              */
/* ------------------------------------------------------------------ */

length(List, Len) :-
    '$skip_list'(List, Len0, Tail),
    (   Tail == []
    ->  Len = Len0
    ;   var(Tail)
    ->  (   integer(Len)
        ->  Len >= Len0, Extra is Len - Len0, '$make_list'(Extra, Tail)
        ;   var(Len)
        ->  '$length_gen'(Tail, Len0, Len)
        ;   '$type_error'(integer, Len)
        )
    ;   '$type_error'(list, List)
    ).

'$length_gen'([], N, N).
'$length_gen'([_|T], N0, N) :-
    N1 is N0 + 1,
    '$length_gen'(T, N1, N).

append([], L, L).
append([H|T], L, [H|R]) :- append(T, L, R).

append(ListOfLists, List) :- foldl('$append_', ListOfLists, List, []).
'$append_'(L, S0, S) :- append(L, S, S0).

member(X, [X|_]).
member(X, [_|T]) :- member(X, T).

memberchk(X, [Y|T]) :- ( X = Y -> true ; memberchk(X, T) ).

reverse(List, Reversed) :- '$reverse'(List, [], Reversed).
'$reverse'([], Acc, Acc).
'$reverse'([H|T], Acc, R) :- '$reverse'(T, [H|Acc], R).

nth0(Index, List, Elem) :- '$nth'(Index, List, Elem, 0).
nth1(Index, List, Elem) :- '$nth'(Index, List, Elem, 1).

'$nth'(Index, List, Elem, Base) :-
    (   integer(Index)
    ->  Skip is Index - Base, Skip >= 0, '$nth_det'(Skip, List, Elem)
    ;   var(Index)
    ->  '$nth_gen'(List, Elem, Base, Index)
    ;   '$type_error'(integer, Index)
    ).

'$nth_det'(0, [X|_], X) :- !.
'$nth_det'(N, [_|T], X) :- N > 0, N1 is N - 1, '$nth_det'(N1, T, X).

'$nth_gen'([X|_], X, N, N).
'$nth_gen'([_|T], X, N0, N) :- N1 is N0 + 1, '$nth_gen'(T, X, N1, N).

last([X], X) :- !.
last([_|T], X) :- last(T, X).

list_to_set(List, Set) :-
    '$number_list'(List, 1, Numbered),
    sort(1, @=<, Numbered, ByValue),
    '$unique_by_value'(ByValue, Unique),
    sort(2, @=<, Unique, ByPos),
    '$strip_numbers'(ByPos, Set).

'$number_list'([], _, []).
'$number_list'([H|T], N, ['$pair'(H, N)|R]) :- N1 is N + 1, '$number_list'(T, N1, R).
'$unique_by_value'([], []).
'$unique_by_value'(['$pair'(V, N)|T], ['$pair'(V, N)|R]) :-
    '$drop_same'(V, T, Rest),
    '$unique_by_value'(Rest, R).
'$drop_same'(V, ['$pair'(V1, _)|T], Rest) :- V == V1, !, '$drop_same'(V, T, Rest).
'$drop_same'(_, T, T).
'$strip_numbers'([], []).
'$strip_numbers'(['$pair'(V, _)|T], [V|R]) :- '$strip_numbers'(T, R).

select(X, [X|T], T).
select(X, [H|T], [H|R]) :- select(X, T, R).

selectchk(X, L, R) :- select(X, L, R), !.

select(X, [X|T], Y, [Y|T]).
select(X, [H|T], Y, [H|R]) :- select(X, T, Y, R).

subtract([], _, []).
subtract([H|T], L, R) :-
    (   memberchk(H, L)
    ->  R = R1
    ;   R = [H|R1]
    ),
    subtract(T, L, R1).

intersection([], _, []).
intersection([H|T], L, R) :-
    (   memberchk(H, L)
    ->  R = [H|R1]
    ;   R = R1
    ),
    intersection(T, L, R1).

union([], L, L).
union([H|T], L, R) :-
    (   memberchk(H, L)
    ->  R = R1
    ;   R = [H|R1]
    ),
    union(T, L, R1).

delete([], _, []).
delete([H|T], X, R) :-
    (   H \= X
    ->  R = [H|R1]
    ;   R = R1
    ),
    delete(T, X, R1).

exclude(_, [], []).
exclude(P, [H|T], R) :-
    (   call(P, H)
    ->  R = R1
    ;   R = [H|R1]
    ),
    exclude(P, T, R1).

include(_, [], []).
include(P, [H|T], R) :-
    (   call(P, H)
    ->  R = [H|R1]
    ;   R = R1
    ),
    include(P, T, R1).

partition(_, [], [], []).
partition(P, [H|T], Inc, Exc) :-
    (   call(P, H)
    ->  Inc = [H|I1], Exc = E1
    ;   Inc = I1, Exc = [H|E1]
    ),
    partition(P, T, I1, E1).

maplist(_, []).
maplist(G, [A|As]) :- call(G, A), maplist(G, As).

maplist(_, [], []).
maplist(G, [A|As], [B|Bs]) :- call(G, A, B), maplist(G, As, Bs).

maplist(_, [], [], []).
maplist(G, [A|As], [B|Bs], [C|Cs]) :- call(G, A, B, C), maplist(G, As, Bs, Cs).

maplist(_, [], [], [], []).
maplist(G, [A|As], [B|Bs], [C|Cs], [D|Ds]) :-
    call(G, A, B, C, D), maplist(G, As, Bs, Cs, Ds).

foldl(G, List, V0, V) :- '$foldl'(List, G, V0, V).
'$foldl'([], _, V, V).
'$foldl'([X|Xs], G, V0, V) :- call(G, X, V0, V1), '$foldl'(Xs, G, V1, V).

foldl(G, L1, L2, V0, V) :- '$foldl2'(L1, L2, G, V0, V).
'$foldl2'([], [], _, V, V).
'$foldl2'([X|Xs], [Y|Ys], G, V0, V) :- call(G, X, Y, V0, V1), '$foldl2'(Xs, Ys, G, V1, V).

/*  Lambdas, as SWI-Prolog's library(yall) has them.

    Params>>Body     called with arguments A1..An, binds the parameters to the
                     first arguments and calls Body with any that are left:
                     call([X,Y]>>foo(X,Y), 1, 2) calls foo(1, 2).
    Free/Lambda      Free is a term whose variables are shared with the
                     context; Free/[X]>>Body parses as (Free/[X])>>Body.
    \X^Body          a parameter written in front of the body; \X^Y^Body
                     takes two.

    The lambda is copied before each call, so its variables are local to
    that call unless they appear in Free: after maplist([X]>>(Y = X), L), Y
    is still unbound, as in yall. A variable already bound when the lambda
    is called is its value, and copying does not change it. Cut in Body is
    local to the lambda. A lambda given more parameters than arguments
    leaves the rest unbound.
*/
'>>'(Ps, B) :- '$lambda_copy'(Ps>>B, L), '$lambda'(L, []).
'>>'(Ps, B, A1) :- '$lambda_copy'(Ps>>B, L), '$lambda'(L, [A1]).
'>>'(Ps, B, A1, A2) :- '$lambda_copy'(Ps>>B, L), '$lambda'(L, [A1,A2]).
'>>'(Ps, B, A1, A2, A3) :- '$lambda_copy'(Ps>>B, L), '$lambda'(L, [A1,A2,A3]).
'>>'(Ps, B, A1, A2, A3, A4) :-
    '$lambda_copy'(Ps>>B, L), '$lambda'(L, [A1,A2,A3,A4]).
'>>'(Ps, B, A1, A2, A3, A4, A5) :-
    '$lambda_copy'(Ps>>B, L), '$lambda'(L, [A1,A2,A3,A4,A5]).
'>>'(Ps, B, A1, A2, A3, A4, A5, A6) :-
    '$lambda_copy'(Ps>>B, L), '$lambda'(L, [A1,A2,A3,A4,A5,A6]).
'>>'(Ps, B, A1, A2, A3, A4, A5, A6, A7) :-
    '$lambda_copy'(Ps>>B, L), '$lambda'(L, [A1,A2,A3,A4,A5,A6,A7]).

'/'(F, B) :- '$lambda_copy'(F/B, _/L), '$lambda'(L, []).
'/'(F, B, A1) :- '$lambda_copy'(F/B, _/L), '$lambda'(L, [A1]).
'/'(F, B, A1, A2) :- '$lambda_copy'(F/B, _/L), '$lambda'(L, [A1,A2]).
'/'(F, B, A1, A2, A3) :- '$lambda_copy'(F/B, _/L), '$lambda'(L, [A1,A2,A3]).
'/'(F, B, A1, A2, A3, A4) :-
    '$lambda_copy'(F/B, _/L), '$lambda'(L, [A1,A2,A3,A4]).
'/'(F, B, A1, A2, A3, A4, A5) :-
    '$lambda_copy'(F/B, _/L), '$lambda'(L, [A1,A2,A3,A4,A5]).
'/'(F, B, A1, A2, A3, A4, A5, A6) :-
    '$lambda_copy'(F/B, _/L), '$lambda'(L, [A1,A2,A3,A4,A5,A6]).
'/'(F, B, A1, A2, A3, A4, A5, A6, A7) :-
    '$lambda_copy'(F/B, _/L), '$lambda'(L, [A1,A2,A3,A4,A5,A6,A7]).

'\\'(B) :- '$lambda_copy'(\B, L), '$lambda'(L, []).
'\\'(B, A1) :- '$lambda_copy'(\B, L), '$lambda'(L, [A1]).
'\\'(B, A1, A2) :- '$lambda_copy'(\B, L), '$lambda'(L, [A1,A2]).
'\\'(B, A1, A2, A3) :- '$lambda_copy'(\B, L), '$lambda'(L, [A1,A2,A3]).
'\\'(B, A1, A2, A3, A4) :-
    '$lambda_copy'(\B, L), '$lambda'(L, [A1,A2,A3,A4]).
'\\'(B, A1, A2, A3, A4, A5) :-
    '$lambda_copy'(\B, L), '$lambda'(L, [A1,A2,A3,A4,A5]).
'\\'(B, A1, A2, A3, A4, A5, A6) :-
    '$lambda_copy'(\B, L), '$lambda'(L, [A1,A2,A3,A4,A5,A6]).
'\\'(B, A1, A2, A3, A4, A5, A6, A7) :-
    '$lambda_copy'(\B, L), '$lambda'(L, [A1,A2,A3,A4,A5,A6,A7]).

% '$lambda_copy'(+Lambda, -Copy): Lambda renamed apart, except for the
% variables of its Free, if it has one, which stay shared.
'$lambda_copy'(Lambda, Copy) :-
    (   '$lambda_free'(Lambda, Free)
    ->  copy_term(Free-Lambda, Free2-Copy), Free2 = Free
    ;   copy_term(Lambda, Copy)
    ).

'$lambda_free'(Free/_, Free).
'$lambda_free'((Free/_)>>_, Free).

% '$lambda'(+Lambda, +Args): applies a lambda that has been copied already,
% so that a Free/ around a \X^ or a >> does not copy it a second time.
'$lambda'(Lambda, Args) :-
    (   var(Lambda) -> throw(error(instantiation_error, _)) ; true ),
    '$lambda1'(Lambda, Args).

'$lambda1'(Ps0>>Body, Args) :- !,
    (   nonvar(Ps0), Ps0 = _/Ps -> true ; Ps = Ps0 ),
    (   var(Ps) -> throw(error(instantiation_error, _))
    ;   is_list(Ps) -> true
    ;   throw(error(type_error(list, Ps), _))
    ),
    '$lambda_bind'(Ps, Args, Rest),
    '$lambda_call'(Body, Rest).
'$lambda1'(\X1^Body, Args) :- !,
    '$lambda_hat'(X1^Body, Args).
'$lambda1'(_/Lambda, Args) :- !,
    '$lambda'(Lambda, Args).
'$lambda1'(Goal, Args) :-
    '$lambda_call'(Goal, Args).

'$lambda_bind'([], Rest, Rest) :- !.
'$lambda_bind'([_|_], [], []) :- !.
'$lambda_bind'([P|Ps], [A|As], Rest) :- P = A, '$lambda_bind'(Ps, As, Rest).

% \X^Y^Body: each ^ in front of the body takes one argument, while there
% are arguments left.
'$lambda_hat'(X^Body, [A|As]) :- !, X = A, '$lambda_hat'(Body, As).
'$lambda_hat'(_^Body, []) :- !, call(Body).
'$lambda_hat'(Body, Args) :- '$lambda_call'(Body, Args).

'$lambda_call'(Goal, []) :- !, call(Goal).
'$lambda_call'(Goal, Args) :- apply(Goal, Args).

sum_list(List, Sum) :- '$sum_list'(List, 0, Sum).
'$sum_list'([], S, S).
'$sum_list'([H|T], S0, S) :- S1 is S0 + H, '$sum_list'(T, S1, S).
sumlist(L, S) :- sum_list(L, S).

max_list([H|T], Max) :- '$max_list'(T, H, Max).
'$max_list'([], M, M).
'$max_list'([H|T], M0, M) :- M1 is max(H, M0), '$max_list'(T, M1, M).

min_list([H|T], Min) :- '$min_list'(T, H, Min).
'$min_list'([], M, M).
'$min_list'([H|T], M0, M) :- M1 is min(H, M0), '$min_list'(T, M1, M).

max_member(Max, [H|T]) :- '$max_member'(T, H, Max).
'$max_member'([], M, M).
'$max_member'([H|T], M0, M) :- ( H @> M0 -> '$max_member'(T, H, M) ; '$max_member'(T, M0, M) ).

min_member(Min, [H|T]) :- '$min_member'(T, H, Min).
'$min_member'([], M, M).
'$min_member'([H|T], M0, M) :- ( H @< M0 -> '$min_member'(T, H, M) ; '$min_member'(T, M0, M) ).

numlist(Low, High, List) :-
    must_be(integer, Low),
    must_be(integer, High),
    Low =< High,
    '$numlist'(Low, High, List).
'$numlist'(High, High, [High]) :- !.
'$numlist'(Low, High, [Low|T]) :- Next is Low + 1, '$numlist'(Next, High, T).

permutation([], []).
permutation(List, [H|T]) :- select(H, List, Rest), permutation(Rest, T).

flatten(List, Flat) :- '$flatten'(List, [], Flat0), Flat = Flat0.
'$flatten'(Var, T, [Var|T]) :- var(Var), !.
'$flatten'([], T, T) :- !.
'$flatten'([H|Rest], T, Flat) :- !, '$flatten'(Rest, T, T1), '$flatten'(H, T1, Flat).
'$flatten'(Atom, T, [Atom|T]).

pairs_keys_values([], [], []).
pairs_keys_values([K-V|T], [K|Ks], [V|Vs]) :- pairs_keys_values(T, Ks, Vs).
pairs_keys([], []).
pairs_keys([K-_|T], [K|Ks]) :- pairs_keys(T, Ks).
pairs_values([], []).
pairs_values([_-V|T], [V|Vs]) :- pairs_values(T, Vs).

predsort(P, List, Sorted) :-
    length(List, N),
    '$predsort'(P, N, List, _, Sorted0),
    Sorted = Sorted0.

'$predsort'(P, 2, [X1,X2|L], L, R) :- !,
    call(P, Delta, X1, X2),
    '$sort2'(Delta, X1, X2, R).
'$predsort'(_, 1, [X|L], L, [X]) :- !.
'$predsort'(_, 0, L, L, []) :- !.
'$predsort'(P, N, L1, L3, R) :-
    N1 is N // 2,
    plus(N1, N2, N),
    '$predsort'(P, N1, L1, L2, R1),
    '$predsort'(P, N2, L2, L3, R2),
    '$predmerge'(P, R1, R2, R).

'$sort2'(<, X1, X2, [X1,X2]).
'$sort2'(=, X1, _, [X1]).
'$sort2'(>, X1, X2, [X2,X1]).

'$predmerge'(_, [], R, R) :- !.
'$predmerge'(_, R, [], R) :- !.
'$predmerge'(P, [H1|T1], [H2|T2], Result) :-
    call(P, Delta, H1, H2),
    '$predmerge'(Delta, P, H1, H2, T1, T2, Result).

'$predmerge'(<, P, H1, H2, T1, T2, [H1|R]) :- '$predmerge'(P, T1, [H2|T2], R).
'$predmerge'(=, P, H1, _, T1, T2, [H1|R]) :- '$predmerge'(P, T1, T2, R).
'$predmerge'(>, P, H1, H2, T1, T2, [H2|R]) :- '$predmerge'(P, [H1|T1], T2, R).

/* ------------------------------------------------------------------ */
/* Atoms                                                              */
/* ------------------------------------------------------------------ */

atom_concat(A, B, C) :-
    (   nonvar(A), nonvar(B)
    ->  '$atom_concat'(A, B, C)
    ;   var(C)
    ->  '$inst_error'
    ;   atom_length(C, N),
        between(0, N, LenA),
        '$sub_atom'(C, 0, LenA, A),
        LenB is N - LenA,
        '$sub_atom'(C, LenA, LenB, B)
    ).

sub_atom(Atom, Before, Len, After, Sub) :-
    atom_length(Atom, N),
    (   nonvar(Sub)
    ->  atom_length(Sub, Len),
        Max is N - Len,
        Max >= 0,
        between(0, Max, Before),
        After is N - Before - Len,
        '$sub_atom'(Atom, Before, Len, Sub)
    ;   between(0, N, Before),
        Rem is N - Before,
        (   nonvar(Len)
        ->  Len =< Rem, After is Rem - Len
        ;   nonvar(After)
        ->  After =< Rem, Len is Rem - After
        ;   between(0, Rem, Len), After is Rem - Len
        ),
        '$sub_atom'(Atom, Before, Len, Sub)
    ).

sub_string(S, B, L, A, Sub) :- sub_atom(S, B, L, A, Sub).

atomic_list_concat(List, Atom) :- atomic_list_concat(List, '', Atom).

atomic_list_concat(List, Sep, Atom) :-
    (   is_list(List), '$all_nonvar'(List)
    ->  '$join'(List, Sep, Atom)
    ;   nonvar(Atom), Sep \== ''
    ->  '$split_atom'(Atom, Sep, List)
    ;   '$inst_error'
    ).

'$all_nonvar'([]).
'$all_nonvar'([H|T]) :- nonvar(H), '$all_nonvar'(T).

/*  char_type(?Char, ?Type) and code_type(?Code, ?Type), as SWI-Prolog and
    the Edinburgh systems before it have them. ASCII is classified exactly.
    A character past ASCII counts as a letter, since in text read as UTF-8
    most of them in words are, and has no case to change. With the character
    unbound they enumerate the ASCII characters; with the type unbound, the
    types. code_type/2 takes a character too, and gives codes where char_type/2
    gives characters: code_type(0'A, to_lower(L)) is L = 0'a.
*/
char_type(C, Type) :-
    (   var(C) -> between(0, 127, X), char_code(C, X)
    ;   atom(C), atom_length(C, 1) -> char_code(C, X)
    ;   throw(error(type_error(character, C), _))
    ),
    '$ctype'(X, T),
    '$ctype_chars'(T, Type).

code_type(C, Type) :-
    (   var(C) -> between(0, 127, C), X = C
    ;   integer(C) -> X = C
    ;   atom(C), atom_length(C, 1) -> char_code(C, X)
    ;   throw(error(type_error(character, C), _))
    ),
    '$ctype'(X, Type).

% The types whose argument is a character code, given as characters.
'$ctype_chars'(upper(L), upper(C))       :- !, char_code(C, L).
'$ctype_chars'(lower(U), lower(C))       :- !, char_code(C, U).
'$ctype_chars'(to_lower(L), to_lower(C)) :- !, char_code(C, L).
'$ctype_chars'(to_upper(U), to_upper(C)) :- !, char_code(C, U).
'$ctype_chars'(T, T).

'$ctype'(X, alnum)       :- ( '$ctype_letter'(X) -> true ; '$ctype_digit'(X) ).
'$ctype'(X, alpha)       :- '$ctype_letter'(X).
'$ctype'(X, csym)        :- ( '$ctype_letter'(X) -> true ; '$ctype_digit'(X) -> true ; X =:= 0'_ ).
'$ctype'(X, csymf)       :- ( '$ctype_letter'(X) -> true ; X =:= 0'_ ).
'$ctype'(X, ascii)       :- X < 128.
'$ctype'(X, white)       :- ( X =:= 0'  -> true ; X =:= 9 ).
'$ctype'(X, space)       :- ( X =:= 0'  -> true ; X >= 9, X =< 13 ).
'$ctype'(X, end_of_line) :- ( X =:= 10 -> true ; X =:= 13 ).
'$ctype'(X, cntrl)       :- ( X < 32 -> true ; X =:= 127 ).
'$ctype'(X, digit(W))    :- '$ctype_digit'(X), W is X - 0'0.
'$ctype'(X, upper)       :- X >= 0'A, X =< 0'Z.
'$ctype'(X, upper(L))    :- X >= 0'A, X =< 0'Z, L is X + 32.
'$ctype'(X, lower)       :- X >= 0'a, X =< 0'z.
'$ctype'(X, lower(U))    :- X >= 0'a, X =< 0'z, U is X - 32.
'$ctype'(X, punct)       :- X >= 33, X =< 126, \+ '$ctype_letter'(X), \+ '$ctype_digit'(X).
'$ctype'(X, graph)       :- ( X >= 33, X =< 126 -> true ; X > 127 ).
'$ctype'(X, print)       :- ( X >= 32, X =< 126 -> true ; X > 127 ).
'$ctype'(X, period)      :- ( X =:= 0'. -> true ; X =:= 0'! -> true ; X =:= 0'? ).
'$ctype'(X, quote)       :- ( X =:= 0'' -> true ; X =:= 0'" -> true ; X =:= 0'` ).
'$ctype'(X, paren)       :- ( X =:= 0'( -> true ; X =:= 0') ).
'$ctype'(X, to_lower(L)) :- ( X >= 0'A, X =< 0'Z -> L is X + 32 ; L = X ).
'$ctype'(X, to_upper(U)) :- ( X >= 0'a, X =< 0'z -> U is X - 32 ; U = X ).

'$ctype_letter'(X) :- ( X >= 0'a, X =< 0'z -> true ; X >= 0'A, X =< 0'Z -> true ; X > 127 ).
'$ctype_digit'(X)  :- X >= 0'0, X =< 0'9.

concat_atom(L, A) :- atomic_list_concat(L, A).
concat_atom(L, S, A) :- atomic_list_concat(L, S, A).

term_string(T, S) :- term_to_atom(T, S).

/* ------------------------------------------------------------------ */
/* Solution collecting                                                */
/* ------------------------------------------------------------------ */

aggregate_all(count, Goal, Count) :- !,
    findall(x, Goal, L),
    length(L, Count).
aggregate_all(count(T), Goal, Count) :- !,
    findall(T, Goal, L),
    length(L, Count).
aggregate_all(sum(Expr), Goal, Sum) :- !,
    findall(Expr, Goal, L),
    sum_list(L, Sum).
aggregate_all(max(Expr), Goal, Max) :- !,
    findall(Expr, Goal, L),
    L \== [],
    max_list(L, Max).
aggregate_all(min(Expr), Goal, Min) :- !,
    findall(Expr, Goal, L),
    L \== [],
    min_list(L, Min).
aggregate_all(bag(T), Goal, Bag) :- !,
    findall(T, Goal, Bag).
aggregate_all(set(T), Goal, Set) :- !,
    findall(T, Goal, L),
    sort(L, Set).

findnsols(N, Template, Goal, List) :- '$findnsols'(N, Template, Goal, List).

bagof(Template, Goal, Bag) :-
    '$free_variables'(Goal, Template, Goal1, Witness),
    (   Witness == []
    ->  findall(Template, Goal1, Bag),
        Bag \== []
    ;   findall(Witness-Template, Goal1, Pairs),
        Pairs \== [],
        keysort(Pairs, Sorted),
        '$group_pairs'(Sorted, Groups),
        member(Witness-Bag, Groups)
    ).

setof(Template, Goal, Set) :-
    bagof(Template, Goal, Bag),
    sort(Bag, Set).

'$group_pairs'([], []).
'$group_pairs'([K-V|T], [K-[V|Vs]|Groups]) :-
    '$same_key'(K, T, Vs, Rest),
    '$group_pairs'(Rest, Groups).

'$same_key'(K, [K1-V|T], [V|Vs], Rest) :- K == K1, !, '$same_key'(K, T, Vs, Rest).
'$same_key'(_, Rest, [], Rest).

'$free_variables'(Goal, Template, Goal1, Witness) :-
    '$strip_carets'(Goal, Carets, Goal1),
    term_variables(Goal1, GoalVars),
    term_variables(Template-Carets, Bound),
    '$exclude_vars'(GoalVars, Bound, Witness).

'$strip_carets'(Goal, Carets, Goal1) :-
    (   nonvar(Goal), Goal = (C ^ G)
    ->  '$strip_carets'(G, Cs, Goal1),
        Carets = C-Cs
    ;   Carets = [],
        Goal1 = Goal
    ).

'$exclude_vars'([], _, []).
'$exclude_vars'([V|Vs], Bound, Out) :-
    (   '$var_memberchk'(V, Bound)
    ->  Out = Out1
    ;   Out = [V|Out1]
    ),
    '$exclude_vars'(Vs, Bound, Out1).

'$var_memberchk'(V, [X|Xs]) :- ( V == X -> true ; '$var_memberchk'(V, Xs) ).

^(_, Goal) :- call(Goal).

/* ------------------------------------------------------------------ */
/* Definite clause grammars                                           */
/* ------------------------------------------------------------------ */

phrase(RuleSet, List) :- phrase(RuleSet, List, []).

phrase(RuleSet, List, Rest) :-
    (   var(RuleSet)
    ->  '$inst_error'
    ;   true
    ),
    '$dcg_body'(RuleSet, S0, S, Goal),
    S0 = List,
    S = Rest,
    call(Goal).

'$dcg_translate'((Head --> Body), Clause) :-
    (   Head = (H, PushBack)
    ->  '$dcg_extend'(H, S0, S, NewHead),
        '$dcg_body'(Body, S0, S1, Goal),
        '$dcg_terminals'(PushBack, S, S1),
        Clause = (NewHead :- Goal)
    ;   '$dcg_extend'(Head, S0, S, NewHead),
        '$dcg_body'(Body, S0, S, Goal),
        Clause = (NewHead :- Goal)
    ).

'$dcg_extend'(Head, S0, S, NewHead) :-
    (   var(Head)
    ->  '$inst_error'
    ;   Head =.. List,
        append(List, [S0, S], List1),
        NewHead =.. List1
    ).

'$dcg_body'(Var, S0, S, phrase(Var, S0, S)) :- var(Var), !.
'$dcg_body'((A, B), S0, S, (GA, GB)) :- !,
    '$dcg_body'(A, S0, S1, GA),
    '$dcg_body'(B, S1, S, GB).
'$dcg_body'((A ; B), S0, S, (GA ; GB)) :- !,
    '$dcg_body'(A, S0, S, GA),
    '$dcg_body'(B, S0, S, GB).
'$dcg_body'((A -> B), S0, S, (GA -> GB)) :- !,
    '$dcg_body'(A, S0, S1, GA),
    '$dcg_body'(B, S1, S, GB).
'$dcg_body'(\+ A, S0, S, (\+ GA, S = S0)) :- !,
    '$dcg_body'(A, S0, _, GA).
'$dcg_body'(!, S0, S, (!, S = S0)) :- !.
'$dcg_body'({Goal}, S0, S, (Goal, S = S0)) :- !.
'$dcg_body'([], S0, S, (S = S0)) :- !.
'$dcg_body'(List, S0, S, '$dcg_terminals'(List, S0, S)) :-
    (   List = [_|_] ; List == [] ), !.
'$dcg_body'(call(G), S0, S, call(G, S0, S)) :- !.
'$dcg_body'(Callable, S0, S, Goal) :- '$dcg_extend'(Callable, S0, S, Goal).

'$dcg_terminals'([], S, S).
'$dcg_terminals'([H|T], [H|S0], S) :- '$dcg_terminals'(T, S0, S).

/* ------------------------------------------------------------------ */
/* Flags, operators, initialisation                                   */
/* ------------------------------------------------------------------ */

current_op(Priority, Type, Name) :-
    '$op_list'(Ops),
    member(op(Priority, Type, Name), Ops).

current_prolog_flag(Flag, Value) :-
    (   var(Flag)
    ->  member(Flag, [bounded, max_integer, min_integer, double_quotes,
                      unknown, dialect, version, max_arity])
    ;   true
    ),
    '$flag'(Flag, Value).

:- dynamic('$init_goal'/1).

initialization(Goal) :- assertz('$init_goal'(Goal)).

'$run_init_goals' :-
    (   retract('$init_goal'(Goal)),
        (   catch(Goal, E, ('$print_error'(E), fail))
        ->  true
        ;   format(user_error, "Warning: initialization goal failed: ~q~n", [Goal])
        ),
        fail
    ;   true
    ).

current_predicate(Name/Arity) :-
    '$predicates'(List),
    member(Name/Arity, List).

predicate_property(Head, defined) :- '$defined'(Head).

/* ------------------------------------------------------------------ */
/* Listing                                                            */
/* ------------------------------------------------------------------ */

portray_clause(Clause) :-
    \+ \+ ( copy_term(Clause, C),
            numbervars(C, 0, _),
            '$portray_clause'(C) ).

'$portray_clause'((Head :- Body)) :- !,
    writeq(Head),
    write(' :-'),
    nl,
    '$portray_body'(Body, 4),
    write('.'),
    nl.
'$portray_clause'(Fact) :-
    writeq(Fact),
    write('.'),
    nl.

'$portray_body'((A, B), Indent) :- !,
    '$portray_body'(A, Indent),
    write(','),
    nl,
    '$portray_body'(B, Indent).
'$portray_body'(Goal, Indent) :-
    tab(Indent),
    writeq(Goal).

listing :-
    '$predicates'(List),
    forall(member(PI, List), listing(PI)).

listing(Name/Arity) :- !,
    '$listing'(Name/Arity).
listing(Name) :-
    '$predicates'(List),
    forall((member(Name/Arity, List)), '$listing'(Name/Arity)).

'$listing'(PI) :-
    (   '$clauses'(PI, Clauses)
    ->  forall(member(Head-Body, Clauses), '$listing_clause'(Head, Body)),
        nl
    ;   true
    ).

'$listing_clause'(Head, true) :- !, portray_clause(Head).
'$listing_clause'(Head, Body) :- portray_clause((Head :- Body)).

/* ------------------------------------------------------------------ */
/* Messages                                                           */
/* ------------------------------------------------------------------ */

print_message(_Kind, Message) :- '$print_error'(Message).

tab(Stream, N) :- forall(between(1, N, _), write(Stream, ' ')).

help :-
    format("Ariadne Prolog -- a small ISO-style Prolog interpreter.~n~n"),
    format("  ?- Goal.            solve Goal; type ; for more solutions~n"),
    format("  ?- [file].          load file.pl~n"),
    format("  ?- consult(file).   the same~n"),
    format("  ?- listing(Name).   show the clauses of a predicate~n"),
    format("  ?- halt.            leave the interpreter~n~n"),
    format("Type  current_predicate(N/A).  to enumerate defined predicates.~n").
