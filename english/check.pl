/*  english/check.pl -- says whether a sentence is grammatical, and why not.

    It loads its other files from beside itself, so it runs from anywhere:

        bin/prolog -q english/check.pl -g "check('The dogs chase a cat.')"
        bin/prolog -q english/check.pl -g "check('The dogs chases a cat.')"

    check/1 takes the sentence as an atom. When the sentence is grammatical
    it prints every reading as a labelled bracketing, [S [NP the dogs] ...],
    so an ambiguous sentence shows each of its structures; otherwise it
    parses again with agreement relaxed, and names what disagreed if that
    finds a reading. A word missing from the lexicon is looked up in
    WordNet, when wordnet_check.pl has loaded it, or else placed by its
    ending, and the verdict says which; a word neither places is reported.
    grammatical/2 is the check without the printing, for programs, and
    brackets/2 turns a tree into its bracketing.

    check_text/1 and check_file/1 take running text instead, cut it into
    sentences, and give a line for each:

        bin/prolog -q english/wordnet_check.pl -g "check_file('essay.txt'), halt"
        pbpaste | bin/prolog -q english/wordnet_check.pl -g "check_file(user_input), halt"
*/

:- consult(lexicon).
:- consult(grammar).
:- consult(guess).

% grammatical(+Text, -Tree): Text is an atom; Tree is a reading of it.
grammatical(Text, Tree) :-
    words(Text, Words),
    unknown_words(Words, Unknown),
    with_placements(Unknown, all_readings(Words, Trees)),
    member(Tree, Trees).

% check(+Text)
check(Text) :-
    words(Text, Words),
    unknown_words(Words, Unknown0),
    sort(Unknown0, Unknown),
    exclude(placeable, Unknown, Unplaced),
    (   Words == []
    ->  format("no words~n")
    ;   Unplaced \== []
    ->  format("not grammatical: not in the lexicon: ~w~n", [Unplaced])
    ;   with_placements(Unknown, verdict(Words)),
        forall(member(W, Unknown),
               ( placed_classes(W, Source, Cs), maplist(class_name, Cs, Ns),
                 atomic_list_concat(Ns, ' or ', C),
                 placed_note(Source, W, C) ))
    ).

placed_note(wordnet, W, C) :-
    format("  (not in the lexicon: '~w' found in WordNet as ~w)~n", [W, C]).
placed_note(ending, W, C) :-
    format("  (not in the lexicon: '~w' taken to be ~w, from its ending)~n", [W, C]).

class_name(noun, 'a noun').
class_name(verb, 'a verb').
class_name(adj,  'an adjective').
class_name(adv,  'an adverb').

% verdict(+Words): prints whether Words are grammatical, and how or why not.
verdict(Words) :-
    (   all_readings(Words, Trees), Trees \== []
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
    shown(W, S),
    format(atom(M), "the verb ~w does not agree with its subject", [S]).
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
    shown(Prev, P),
    (   lemma(W, Base), form_of(Base, Form, Right)
    ->  format(atom(M), "after ~w the verb should be '~w', not '~w'", [P, Right, W])
    ;   format(atom(M), "'~w' cannot follow ~w", [W, P])
    ).

% shown(+Word, -Shown): a word quoted for a message; a contraction with the
% words it stands for, since 's alone does not say whether it is is or has.
shown(W, S) :-
    clitic(W, _), !,
    findall(A, clitic(W, A), As), atomic_list_concat(As, ' or ', Alt),
    format(atom(S), "~w (~w)", [W, Alt]).
shown(W, S) :- format(atom(S), "'~w'", [W]).
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
lemma(W, Base) :- clitic(W, Aux), !, lemma(Aux, Base).
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
known_word(W) :- clitic(W, _), !.
known_word(W) :- rel_pronoun(W, _), !.
known_word(W) :- wh_pronoun(W, _), !.
known_word(W) :- wh_det(W), !.
known_word(W) :- wh_adverb(W), !.
known_word(and).
known_word(not).

/* ---------------- running text ---------------- */

% check_text(+Text): Text is any amount of prose. It is cut into sentences,
% each is checked, and one line is printed for each, then the counts:
%
%     yes (1)   The dog barks.
%     no        The dog bark.  (the verb 'bark' does not agree with its subject)
%     unknown   The dog zorbles.  [zorbles]
%
% check_file(+File) does the same for a file, or for standard input when
% File is user_input, so text can be piped in.
check_text(Text) :-
    text_sentences(Text, Ss),
    foldl(check_sentence, Ss, t(0, 0, 0), t(G, N, U)),
    length(Ss, All),
    format("~n~d sentences: ~d grammatical, ~d not, ~d with a word the checker does not know~n",
           [All, G, N, U]).

check_file(File) :-
    read_text(File, Text),
    check_text(Text).

check_sentence(S, t(G0, N0, U0), t(G, N, U)) :-
    sentence_result(S, R),
    result_line(R, S),
    count_result(R, t(G0, N0, U0), t(G, N, U)).

% sentence_result(+Sentence, -Result): yes(Readings), no(Why), or
% unknown(Words) when a word is in neither the lexicon nor WordNet and its
% ending does not place it.
sentence_result(S, R) :-
    words(S, Words),
    unknown_words(Words, Unknown0),
    sort(Unknown0, Unknown),
    exclude(placeable, Unknown, Unplaced),
    (   Unplaced \== []
    ->  R = unknown(Unplaced)
    ;   with_placements(Unknown, all_readings(Words, Trees)), Trees \== []
    ->  length(Trees, N), R = yes(N)
    ;   with_placements(Unknown, diagnosis(Words, [V|_]))
    ->  message(V, M), R = no(M)
    ;   R = no('no reading')
    ).

result_line(yes(N), S)      :- format("yes (~d)   ~w~n", [N, S]).
result_line(no(M), S)       :- format("no        ~w  (~w)~n", [S, M]).
result_line(unknown(Ws), S) :- format("unknown   ~w  ~w~n", [S, Ws]).

count_result(yes(_),     t(G0, N, U), t(G, N, U)) :- G is G0 + 1.
count_result(no(_),      t(G, N0, U), t(G, N, U)) :- N is N0 + 1.
count_result(unknown(_), t(G, N, U0), t(G, N, U)) :- U is U0 + 1.

% read_text(+File, -Text): the whole of a file, or of standard input, as
% one atom, its lines joined by newlines so that a blank line survives.
read_text(user_input, Text) :- !, text_lines(user_input, Text).
read_text(File, Text) :-
    open(File, read, In),
    text_lines(In, Text),
    close(In).

text_lines(In, Text) :-
    stream_lines(In, Lines),
    atomic_list_concat(Lines, '\n', Text).

stream_lines(In, Lines) :-
    read_line_to_string(In, L),
    (   L == end_of_file
    ->  Lines = []
    ;   Lines = [L|Ls], stream_lines(In, Ls)
    ).

% text_sentences(+Text, -Sentences): Text cut into sentences, each an atom
% with its spaces and line breaks run together. A sentence ends at a full
% stop, question mark or exclamation mark followed by a space or the end,
% with any closing quotes or brackets after it, so 3.5 does not end one;
% and at a blank line, so that a heading with no full stop is a sentence of
% its own. A piece with no letter in it is left out. A piece that ends in
% one of the common abbreviations below, Mr. or e.g., is joined to the next;
% any other abbreviation ends a sentence.
text_sentences(Text, Ss) :-
    atom_chars(Text, Cs),
    split_sentences(Cs, Ss0),
    join_abbreviations(Ss0, Ss).

join_abbreviations([S1, S2|Ss], Out) :-
    ends_in_abbreviation(S1), !,
    atomic_list_concat([S1, ' ', S2], S),
    join_abbreviations([S|Ss], Out).
join_abbreviations([S|Ss], [S|Out]) :- !, join_abbreviations(Ss, Out).
join_abbreviations([], []).

ends_in_abbreviation(S) :-
    atomic_list_concat(Parts, ' ', S), last(Parts, W0),
    downcase_atom(W0, W), abbreviation(W).

abbreviation('mr.'). abbreviation('mrs.'). abbreviation('ms.').
abbreviation('dr.'). abbreviation('prof.'). abbreviation('st.').
abbreviation('jr.'). abbreviation('sr.'). abbreviation('vs.').
abbreviation('e.g.'). abbreviation('i.e.').
abbreviation('cf.').

split_sentences([], []) :- !.
split_sentences(Cs, Ss) :-
    sentence_chars(Cs, S, Rest),
    (   tidy_sentence(S, A)
    ->  Ss = [A|Ss1]
    ;   Ss = Ss1
    ),
    split_sentences(Rest, Ss1).

sentence_chars([], [], []).
sentence_chars([C|Cs0], [C|Cl], Rest) :-
    sentence_end(C), closers(Cs0, Cl, Rest), ends_here(Rest), !.
sentence_chars(['\n'|Cs0], [], Rest) :- blank_line(Cs0, Rest), !.
sentence_chars([C|Cs], [C|S], Rest) :- sentence_chars(Cs, S, Rest).

sentence_end('.'). sentence_end('?'). sentence_end('!').

closers([C|Cs], [C|Cl], R) :- closer(C), !, closers(Cs, Cl, R).
closers(R, [], R).

closer(')'). closer(']'). closer('"'). closer('\''). closer('\x201D\').
closer('\x2019\').

ends_here([]).
ends_here([C|_]) :- layout(C).

blank_line([C|Cs], R) :- layout(C), C \== '\n', !, blank_line(Cs, R).
blank_line(['\n'|R], R).

layout(' '). layout('\t'). layout('\n'). layout('\r').

% tidy_sentence(+Chars, -Atom): Chars with each run of layout made one
% space and none at either end; fails if there is no letter in it.
tidy_sentence(Cs, A) :-
    member(C, Cs), letter(C), !,
    squeeze(Cs, Sq),
    atom_chars(A, Sq).

squeeze(Cs, Out) :-
    skip_layout(Cs, Cs1),
    squeeze_words(Cs1, Out).

squeeze_words([], []).
squeeze_words([C|Cs], Out) :-
    (   layout(C)
    ->  skip_layout(Cs, Cs1),
        (   Cs1 == [] -> Out = [] ; Out = [' '|Out1], squeeze_words(Cs1, Out1) )
    ;   Out = [C|Out1], squeeze_words(Cs, Out1)
    ).

skip_layout([C|Cs], R) :- layout(C), !, skip_layout(Cs, R).
skip_layout(R, R).

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
bracket(np(poss(P), Nom))  --> ['[NP'], bracket(P), ['\'s'], nom(Nom), [']'].
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
% read as the plain one. A contraction such as 's, 're or 'll is then cut
% from its word, as it is a word of its own: she's gives [she, 's]. So is
% the apostrophe after a plural, dogs' giving [dogs, 's], since it marks a
% possessive as 's does.
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
    ->  take_letters([C|Cs], Letters, Rest0),
        atom_chars(W0, Letters),
        clitic_split(W0, Ws0),
        (   Rest0 = ['\''|Rest], last(Letters, s), \+ ( Rest = [N|_], letter(N) )
        ->  append(Ws0, ['\'s'], Ws1)
        ;   Rest = Rest0, Ws1 = Ws0
        ),
        append(Ws1, Ws, Words),
        split_letters(Rest, Ws)
    ;   split_letters(Cs, Words)
    ).

% clitic_split(+Word, -Words): she's as [she, 's]; a word with no clitic,
% or a negative contraction such as doesn't, as itself.
clitic_split(W, [Stem, Clitic]) :-
    clitic(Clitic, _), atom_concat(Stem, Clitic, W), Stem \== '', !.
clitic_split(W, [W]).

take_letters([C|Cs], [C|Ls], Rest) :- letter(C), !, take_letters(Cs, Ls, Rest).
take_letters(['\'', C|Cs], ['\'', C|Ls], Rest) :-
    letter(C), !, take_letters(Cs, Ls, Rest).
take_letters(Rest, [], Rest).

letter(C) :- char_type(C, alpha).
