/*  english/corpus.pl -- the checker over english/corpus.txt.

    Run with:  make english-wordnet   (or bin/prolog -q
               english/wordnet_check.pl english/corpus.pl -g corpus)

    corpus.txt is fifty ordinary sentences, every one of them English, of
    the kind a beginner's reader holds. Each is checked and its verdict
    printed, then a count of each kind. The sentences it rejects are the
    record of what the grammar lacks, which the README sets out: stage 3 of
    the grammar in docs/ROADMAP.md.
*/

corpus :-
    open('english/corpus.txt', read, In),
    read_lines(In, Lines),
    close(In),
    foldl(one, Lines, t(0, 0, 0), t(G, N, U)),
    length(Lines, All),
    format("~n~d sentences: ~d grammatical, ~d not, ~d with a word neither the lexicon nor WordNet has~n",
           [All, G, N, U]).

% read_lines(+Stream, -Lines): the non-empty lines, as atoms. Read a
% character at a time, as the interpreter has no read_line_to_string/2.
read_lines(In, Lines) :-
    get_char(In, C),
    (   C == end_of_file
    ->  Lines = []
    ;   line_chars(In, C, Cs, More),
        (   Cs == [] -> Lines = Ls ; atom_chars(A, Cs), Lines = [A|Ls] ),
        (   More == yes -> read_lines(In, Ls) ; Ls = [] )
    ).

line_chars(_, end_of_file, [], no) :- !.
line_chars(_, '\n', [], yes) :- !.
line_chars(In, C, [C|Cs], More) :- get_char(In, C1), line_chars(In, C1, Cs, More).

one(S, t(G0, N0, U0), t(G, N, U)) :-
    words(S, Words),
    unknown_words(Words, Unknown),
    (   member(W, Unknown), \+ placeable(W)
    ->  G = G0, N = N0, U is U0 + 1,
        exclude(placeable, Unknown, Un),
        format("unknown   ~w  ~w~n", [S, Un])
    ;   with_placements(Unknown, all_readings(Words, Trees)), Trees \== []
    ->  G is G0 + 1, N = N0, U = U0,
        length(Trees, R), format("yes (~d)   ~w~n", [R, S])
    ;   G = G0, N is N0 + 1, U = U0,
        (   with_placements(Unknown, diagnosis(Words, [V|_]))
        ->  message(V, M), format("no        ~w  (~w)~n", [S, M])
        ;   format("no        ~w  (no reading)~n", [S])
        )
    ).
