/*  english/corpus.pl -- the checker over english/corpus.txt and
    english/corpus2.txt.

    Run with:  make english-wordnet   (or bin/prolog -q
               english/wordnet_check.pl english/corpus.pl -g corpus)

    corpus.txt is fifty ordinary sentences, every one of them English, of
    the kind a beginner's reader holds. The grammar was then built to pass
    them, so they now guard what it has and measure nothing. It passes all
    but "Two cups of tea, please", which has no verb, and which passed only
    while commas were thrown away.

    corpus2.txt is fifty sentences the grammar was not built against: the
    first two sentences of 25 articles drawn at random from Simple English
    Wikipedia, verbatim, by a rule fixed before the text was seen. The
    README gives the rule and the articles; corpus2-sources.tsv lists each
    with the revision it was taken from.

    Each sentence is checked and its verdict printed, then a count of each
    kind, which must be the recorded one. The sentences it rejects are the
    record of what the grammar lacks, which the README sets out.
*/

% recorded(File, Grammatical, Not, Unknown): the counts the README records.
% corpus fails on any others, so a change to the grammar, the lexicon or
% wordnet_entry/2 that moves a sentence is seen, whichever way it moves it,
% and the record is brought up to date with it.
recorded('english/corpus.txt', 49, 1, 0).
recorded('english/corpus2.txt', 26, 23, 1).

corpus :-
    corpus('english/corpus.txt'),
    corpus('english/corpus2.txt').

corpus(File) :-
    open(File, read, In),
    read_lines(In, Lines),
    close(In),
    format("~n~w~n", [File]),
    foldl(one, Lines, t(0, 0, 0), t(G, N, U)),
    length(Lines, All),
    format("~n~d sentences: ~d grammatical, ~d not, ~d with a word neither the lexicon nor WordNet has~n",
           [All, G, N, U]),
    (   recorded(File, G, N, U)
    ->  true
    ;   recorded(File, G0, N0, U0),
        format(user_error, "corpus: ~w recorded ~d grammatical, ~d not, ~d unknown; update recorded/4 and the README if the change is meant~n",
               [File, G0, N0, U0]),
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

one(S, T0, T) :-
    sentence_result(S, R),
    result_line(R, S),
    count_result(R, T0, T).
