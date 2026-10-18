/*  english/corpus.pl -- the checker over english/corpus.txt,
    english/corpus2.txt and english/corpus3.txt.

    Run with:  make english-wordnet   (or bin/prolog -q
               english/wordnet_check.pl english/corpus.pl -g corpus)

    corpus.txt is fifty ordinary sentences, every one of them English, of
    the kind a beginner's reader holds. The grammar was then built to pass
    them, so they now guard what it has and measure nothing. "Two cups of
    tea, please" has no verb, passed while commas were thrown away, was
    refused once they were read, and passes again as a request.

    corpus2.txt is fifty sentences the grammar was not built against: the
    first two sentences of 25 articles drawn at random from Simple English
    Wikipedia, verbatim, by a rule fixed before the text was seen. The
    README gives the rule and the articles; corpus2-sources.tsv lists each
    with the revision it was taken from.

    corpus3.txt is fifty more, from a different register: the first two
    sentences of 25 articles drawn at random from English Wikinews, by the
    same kind of rule, which the README gives; corpus3-sources.tsv lists
    the articles and revisions.

    Each sentence is checked and its verdict printed, then a count of each
    kind, which must be the recorded one. The sentences it rejects are the
    record of what the grammar lacks, which the README sets out. A
    sentence with a fault in the source is held, see held/2, and counts
    as not grammatical whatever the checker says of it.
*/

% recorded(File, Grammatical, Not, Unknown): the counts the README records.
% corpus fails on any others, so a change to the grammar, the lexicon or
% wordnet_entry/2 that moves a sentence is seen, whichever way it moves it,
% and the record is brought up to date with it.
recorded('english/corpus.txt', 50, 0, 0).
recorded('english/corpus2.txt', 49, 0, 1).
recorded('english/corpus3.txt', 43, 7, 0).

corpus :-
    corpus('english/corpus.txt'),
    corpus('english/corpus2.txt'),
    corpus('english/corpus3.txt').

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
    (   held(Start, Why), sub_atom(S, 0, _, _, Start)
    ->  held_line(R, S, Why),
        count_result(no(held), T0, T)
    ;   result_line(R, S),
        count_result(R, T0, T)
    ).

% held(Start, Why): a sentence with a fault in the source, named by how it
% starts, which is not worked on and counts as not grammatical whatever
% the checker says. The checker's verdict is printed beside it, so a rule
% that moves it is still seen. The Ban Ki-moon sentence passed on
% 2026-10-18 with every reading wrong: with no comma after "the South
% Korean minister", "Ban Ki-moon" was read as an appositive to "talks".
held('"I am sorry about the arrest.We',
     'two sentences run together inside a quotation, "the arrest.We"').
held('The planet, named TrES-4, after',
     'no comma to close the participle phrase before "is"').
held('Yesterday, in front of the USS Wisconsin',
     'no comma to close the appositive before "selected"').
held('During talks between the respective Foreign Ministers',
     'no comma to close the appositive after "the South Korean minister"').

held_line(yes(N), S, Why) :- format("held      ~w  (~w; the checker: yes (~d))~n", [S, Why, N]).
held_line(no(M), S, Why)  :- format("held      ~w  (~w; the checker: no, ~w)~n", [S, Why, M]).
held_line(unknown(Ws), S, Why) :- format("held      ~w  (~w; the checker: unknown ~w)~n", [S, Why, Ws]).
