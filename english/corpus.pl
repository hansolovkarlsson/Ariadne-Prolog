/*  english/corpus.pl -- the checker over english/corpus.txt.

    Run with:  make english-wordnet   (or bin/prolog -q
               english/wordnet_check.pl english/corpus.pl -g corpus)

    corpus.txt is fifty ordinary sentences, every one of them English, of
    the kind a beginner's reader holds. Each is checked and its verdict
    printed, then a count of each kind, which must be the recorded one. The
    sentences it rejects are the record of what the grammar lacks, which the
    README sets out: stage 3 of the grammar in docs/ROADMAP.md.
*/

% recorded(Grammatical, Not, Unknown): the counts the README records. corpus
% fails on any others, so a change to the grammar, the lexicon or
% wordnet_entry/2 that moves a sentence is seen, whichever way it moves it,
% and the record is brought up to date with it.
recorded(31, 18, 1).

corpus :-
    open('english/corpus.txt', read, In),
    read_lines(In, Lines),
    close(In),
    foldl(one, Lines, t(0, 0, 0), t(G, N, U)),
    length(Lines, All),
    format("~n~d sentences: ~d grammatical, ~d not, ~d with a word neither the lexicon nor WordNet has~n",
           [All, G, N, U]),
    (   recorded(G, N, U)
    ->  true
    ;   recorded(G0, N0, U0),
        format(user_error, "corpus: recorded ~d grammatical, ~d not, ~d unknown; update recorded/3 and the README if the change is meant~n",
               [G0, N0, U0]),
        fail
    ).

% read_lines(+Stream, -Lines): the non-empty lines, as atoms.
read_lines(In, Lines) :-
    read_line_to_string(In, L),
    (   L == end_of_file
    ->  Lines = []
    ;   L == ''
    ->  read_lines(In, Lines)
    ;   Lines = [L|Ls], read_lines(In, Ls)
    ).

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
