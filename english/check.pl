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
    words(Text, Words, Names),
    end_mark(Text, Mark),
    unknown_words(Words, Unknown),
    with_placements(Unknown, Names, marked_readings(Words, Mark, readings(Trees))),
    member(Tree, Trees).

% check(+Text)
check(Text) :-
    words(Text, Words, Names),
    end_mark(Text, Mark),
    unknown_words(Words, Unknown0),
    sort(Unknown0, Unknown),
    unplaced(Unknown, Names, Unplaced),
    (   Words == []
    ->  format("no words~n")
    ;   Unplaced \== []
    ->  format("not grammatical: not in the lexicon: ~w~n", [Unplaced])
    ;   with_placements(Unknown, Names, verdict(Words, Mark)),
        forall(( member(W, Unknown), placeable(W) ),
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

% verdict(+Words, +Mark): prints whether Words, ending in Mark, are
% grammatical, and how or why not.
verdict(Words, Mark) :-
    marked_readings(Words, Mark, Out),
    (   Out = readings(Trees)
    ->  length(Trees, N),
        (   N =:= 1
        ->  Trees = [T1], brackets(T1, B), format("grammatical: ~w~n", [B])
        ;   format("grammatical, ~d readings:~n", [N]),
            forall(member(T, Trees), (brackets(T, B), format("  ~w~n", [B])))
        )
    ;   Out = wrong_mark(V)
    ->  format("not grammatical: "),
        explain([V])
    ;   diagnosis(Words, Violations)
    ->  format("not grammatical: "),
        explain(Violations)
    ;   format("not grammatical: the words do not make a sentence this grammar knows~n")
    ).

% end_mark(+Text, -Mark): the full stop, question mark or exclamation mark
% that ends Text, past any closing quotes or brackets, or none.
end_mark(Text, Mark) :-
    atom_chars(Text, Cs0),
    reverse(Cs0, Cs),
    last_mark(Cs, Mark).

last_mark([C|Cs], Mark) :- ( layout(C) ; closer(C) ), !, last_mark(Cs, Mark).
last_mark([C|_], C) :- sentence_end(C), !.
last_mark(_, none).

% marked_readings(+Words, +Mark, -Outcome): the readings of Words that its
% end mark allows, readings(Trees); or, when it has readings and the mark
% allows none of them, wrong_mark(punctuation(Mark)); or none. A question
% ends with a question mark, and a statement or a command with a full stop
% or an exclamation mark, so "The dog barks?" and "Does the dog bark." are
% each refused. Text with no mark at the end, a heading or a fragment
% checked on its own, is taken as it is.
marked_readings(Words, Mark, Out) :-
    all_readings(Words, Trees0),
    (   Trees0 == []
    ->  Out = none
    ;   include(fits_mark(Mark), Trees0, Trees), Trees \== []
    ->  Out = readings(Trees)
    ;   Out = wrong_mark(punctuation(Mark))
    ).

fits_mark(none, _).
fits_mark('?', T) :- question_tree(T).
fits_mark('.', T) :- \+ question_tree(T).
fits_mark('!', T) :- \+ question_tree(T).

question_tree(q(_, _, _, _)).
question_tree(wh(_, _)).

% all_readings(+Words, -Trees): every distinct reading. A word can be one form
% twice over, as read is both present and past, and the tree does not say
% which, so the same tree is found twice and counted once. A command is
% read only when nothing else can be, and no statement can be even with a
% word that disagrees; see imperative//3 in grammar.pl.
all_readings(Words, Trees) :-
    findall(T, phrase(sentence(T, [], []), Words), Trees0),
    (   Trees0 == [], \+ faulty_statement(Words)
    ->  findall(T, phrase(imperative(T, [], []), Words), Trees1)
    ;   Trees1 = Trees0
    ),
    sort(Trees1, Trees).

% diagnosis(+Words, -Violations): the reading with the least wrong, if the
% grammar can read Words at all once agreement is relaxed. A verb out of
% its place counts twice, since it is a bigger departure than a wrong
% ending: "which dogs chases the cat" is chases disagreeing with which
% dogs, not chases put before the cat without do. A command is a reading
% here on the terms all_readings/2 gives it.
%
% The fault list is passed with max_faults/1 places, so a reading that
% would record one more fails where it stands, and the places it leaves
% unused are dropped. With the list open, every word WordNet lists as a
% noun could be a bare noun, a fault, and a sentence of 25 words that no
% reading fits took minutes to be refused; a sentence more than three
% faults from English now gets no diagnosis.
max_faults(3).

%
% A sentence is a statement or one of the two questions, and each is parsed
% on its own, so the statements found say whether a command is to be tried,
% and the statement is not searched for twice.
diagnosis(Words, Violations) :-
    findall(G-(C-Vs),
            ( member(G, [declarative, question, wh_question]),
              fault_parse(G, Words, Vs), cost(Vs, C) ),
            Tagged),
    pairs_values(Tagged, Readings0),
    (   memberchk(declarative-_, Tagged)
    ->  Readings = Readings0
    ;   findall(C-Vs, ( fault_parse(imperative, Words, Vs), cost(Vs, C) ), Readings1),
        append(Readings0, Readings1, Readings)
    ),
    Readings \== [],
    msort(Readings, [_-Violations|_]).

% fault_parse(+Goal, +Words, -Violations): Words read as Goal, one of the
% kinds of sentence or a command, with at most max_faults/1 faults.
fault_parse(G, Words, Vs) :-
    max_faults(Max),
    length(Slots, Max),
    fault_phrase(G, Slots, Rest, Words),
    length(Rest, Left),
    Used is Max - Left,
    length(Vs, Used),
    append(Vs, _, Slots).

fault_phrase(declarative, V0, V, Words) :- phrase(declarative(_, V0, V), Words).
fault_phrase(question, V0, V, Words)    :- phrase(question(_, nogap, nogap, V0, V), Words).
fault_phrase(wh_question, V0, V, Words) :- phrase(wh_question(_, V0, V), Words).
fault_phrase(imperative, V0, V, Words)  :- phrase(imperative(_, V0, V), Words).

% faulty_statement(+Words): Words are a statement with at most max_faults/1
% faults.
faulty_statement(Words) :-
    max_faults(Max),
    length(Slots, Max),
    phrase(declarative(_, Slots, _), Words), !.

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
    atomic_list_concat(Ws, ' ', D), append(Before, [A], Ws),
    ( A == a -> B = an ; B = a ),
    append(Before, [B], Ws1), atomic_list_concat(Ws1, ' ', Other),
    format(atom(M), "'~w ~w' should be '~w ~w'", [D, W, Other, W]).
message(case(W), M) :-
    format(atom(M), "the pronoun '~w' is in the wrong case for where it stands", [W]).
message(punctuation('?'), M) :-
    format(atom(M), "a question mark ends a question, and this is not one", []).
message(punctuation(P), M) :-
    P \== '?',
    format(atom(M), "a question ends with a question mark, not '~w'", [P]).
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

% unplaced(+Unknown, +Names, -Unplaced): the unknown words that neither
% WordNet nor an ending places, and that are not a name the sentence gives.
% A name that WordNet places is looked up all the same, so "Church" in "The
% Episcopal Church" is a noun as well as a name.
unplaced(Unknown, Names, Unplaced) :-
    exclude(placeable, Unknown, Unplaced0),
    exclude([W]>>memberchk(W, Names), Unplaced0, Unplaced).

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
known_word(W) :- number_word(W, _), !.
known_word(W) :- big_number(W), !.
known_word(W) :- coordinator(W), !.
known_word(W) :- degree(W), !.
known_word(W) :- subordinator(W), !.
known_word(not).
known_word(',').

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
    words(S, Words, Names),
    end_mark(S, Mark),
    unknown_words(Words, Unknown0),
    sort(Unknown0, Unknown),
    unplaced(Unknown, Names, Unplaced),
    (   Unplaced \== []
    ->  R = unknown(Unplaced)
    ;   with_placements(Unknown, Names, marked_readings(Words, Mark, Out)),
        Out \== none
    ->  (   Out = readings(Trees)
        ->  length(Trees, N), R = yes(N)
        ;   Out = wrong_mark(V), message(V, M), R = no(M)
        )
    ;   with_placements(Unknown, Names, diagnosis(Words, [V|_]))
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
% its own. A piece with no letter in it is left out.
%
% A full stop after an abbreviation is joined to what follows, when the
% text shows it is one: after initials, "N." or "U.S."; after a short word
% before a number, "Vol. 3", "No. 5", "Vol. #8"; or after one of the abbreviations
% listed below, "Mr." or "lit.", which shape alone cannot tell from the
% last word of a sentence. A list alone had to choose for "no." and
% "etc.", and each ends real sentences often enough to join two that
% should stay apart; "no." before a number is now caught by its shape.
text_sentences(Text, Ss) :-
    atom_chars(Text, Cs),
    split_sentences(Cs, Ss0),
    join_abbreviations(Ss0, Ss).

join_abbreviations([S1, S2|Ss], Out) :-
    joins(S1, S2), !,
    atomic_list_concat([S1, ' ', S2], S),
    join_abbreviations([S|Ss], Out).
join_abbreviations([S|Ss], [S|Out]) :- !, join_abbreviations(Ss, Out).
join_abbreviations([], []).

% joins(+Piece, +Next): Piece ends in an abbreviation, and Next goes on
% the same sentence.
joins(S1, S2) :-
    atomic_list_concat(Parts, ' ', S1), last(Parts, W0),
    atom_chars(W0, Cs0), exclude(opener, Cs0, Cs),
    atom_chars(W1, Cs), downcase_atom(W1, W),
    (   abbreviation(W)
    ->  true
    ;   initials(Cs)
    ->  true
    ;   append(Letters, ['.'], Cs), length(Letters, N), N =< 4,
        maplist(letter, Letters),
        atom_chars(S2, Next), starts_number(Next)
    ).

% starts_number(+Chars): a number comes first, "5" or "#8".
starts_number([D|_]) :- digit(D).
starts_number(['#', D|_]) :- digit(D).

opener('('). opener('['). opener('"'). opener('\x201C\').

% initials(+Chars): one letter or more, each with a full stop after it,
% "N." or "U.S.".
initials([L, '.']) :- letter(L).
initials([L, '.'|Cs]) :- letter(L), initials(Cs).

abbreviation('mr.'). abbreviation('mrs.'). abbreviation('ms.').
abbreviation('dr.'). abbreviation('prof.'). abbreviation('st.').
abbreviation('jr.'). abbreviation('sr.'). abbreviation('vs.').
abbreviation('e.g.'). abbreviation('i.e.'). abbreviation('lit.').
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
bracket(joined(C, S1, S2)) -->
    (   { coordinator(C) }
    ->  ['[S'], bracket(S1), [C], bracket(S2), [']']
    ;   ['[S'], bracket(S1), ['[SBAR', C], bracket(S2), [']', ']']
    ).
bracket(sub_first(C, S1, S2)) -->
    ['[S', '[SBAR', C], bracket(S1), [']'], bracket(S2), [']'].
bracket(num(W))            --> ['[NP', W, ']'].
bracket(imp(P1, Neg, VP, P2)) -->
    ['[S'], please_word(P1), imp_neg(Neg), bracket(VP), please_word(P2), [']'].
bracket(pre(As, VP))       --> ['[VP'], items(As), bracket(VP), [']'].
bracket(adjp(Ds, A))       --> ['[AP'], Ds, [A, ']'].
bracket(sbar(that, S))     --> ['[SBAR', that], bracket(S), [']'].
bracket(sbar(none, S))     --> ['[SBAR'], bracket(S), [']'].
bracket(inf(VP))           --> ['[VP', to], bracket(VP), [']'].
bracket(npadv(D, N))       --> ['[NP', D, N, ']'].
bracket(q(W, NP, Neg, Is)) --> ['[SQ', W], bracket(NP), neg(Neg), items(Is), [']'].
bracket(wh(W, C))          --> ['[SBARQ'], bracket(W), bracket(C), [']'].
bracket(wh_pro(W))         --> ['[WHNP', W, ']'].
bracket(wh_np(D, Nom))     --> ['[WHNP', D], nom(Nom), [']'].
bracket(whadv(A))          --> ['[WHADVP', A, ']'].
bracket(rel(none, S))      --> ['[SBAR'], bracket(S), [']'].
bracket(rel(W, C))         --> { W \== none }, ['[SBAR', W], bracket(C), [']'].
bracket(gap)               --> ['_'].
bracket(coord(C, Ts))      --> ['[NP'], joined_out(bracket, C, Ts), [']'].
bracket(adj_coord(C, As))  --> ['[AP'], joined_out(bracket, C, As), [']'].
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
nom(coord(C, Ns))        --> joined_out(nom, C, Ns).

% joined_out(:Show, +Conjunction, +Items): a list as it is written, "A and
% B", "A , B and C"; a comma before the conjunction is not kept.
joined_out(Show, C, [X, Y]) --> !, call(Show, X), [C], call(Show, Y).
joined_out(Show, C, [X|Xs]) --> call(Show, X), [','], joined_out(Show, C, Xs).

adjective_words([]) --> [].
adjective_words([adj(A)|As]) --> [A], adjective_words(As).
adjective_words([adjp(Ds, A)|As]) --> Ds, [A], adjective_words(As).
adjective_words([name(W)|As]) --> [W], adjective_words(As).
adjective_words([sep(S)|As]) --> S, adjective_words(As).
adjective_words([nmod(W)|As]) --> [W], adjective_words(As).

neg(not)  --> [not].
neg(none) --> [].

imp_neg(not)  --> [do, not].
imp_neg(none) --> [].

please_word(please) --> [please].
please_word(none)   --> [].

items([]) --> [].
items([T|Ts]) --> bracket(T), items(Ts).

% The parts are joined with spaces; a closing bracket takes none before it.
tidy(A0, A) :-
    atomic_list_concat(Parts, ' ]', A0),
    atomic_list_concat(Parts, ']', A).

/* ---------------- words ---------------- */

% words(+Text, -Words): Text lowercased and cut into words at anything that
% is not a letter or a digit, so punctuation falls away: 'The dog barks.'
% gives [the, dog, barks]. A comma is kept, as a word of its own, since a
% list is "the dog, the cat and the mouse" and not three noun phrases in a
% row; the grammar reads one only where a rule places it. A number in digits is one word, '3.5' or '1,000'.
% A letter is what char_type/2 calls alpha, so a word with an accented
% letter stays one word. An apostrophe between letters
% belongs to the word, so doesn't is one word; a typographic apostrophe is
% read as the plain one. A contraction such as 's, 're or 'll is then cut
% from its word, as it is a word of its own: she's gives [she, 's]. So is
% the apostrophe after a plural, dogs' giving [dogs, 's], since it marks a
% possessive as 's does.
words(Text, Words) :- words(Text, Words, _).

% words(+Text, -Words, -Names): Words as words/2 gives them, and Names, the
% words that Text writes with a capital where a name can stand, lowercased
% as Words has them. A capitalized word after the first is a name, unless
% it is one of the small closed classes, a determiner, a pronoun, a
% preposition, a conjunction or a form of be, have or do: "the Congress
% Party", but not "The" in "The Episcopal Church". The first word is
% capitalized whatever it is, so it is a name only with more to go on: the
% word after it is a name too, "Michael Bruce Curry", or a number, "Class
% 93"; the lexicon lists it
% as one, or WordNet writes it with a capital, "Springfield"; or nothing
% knows the word at all, "Konnevesi". So "Dog barks" is still a noun with
% no determiner, and "Woods was born" is too, since WordNet has woods only
% in lowercase. A name keeps the other readings its word has: "Indian" is
% a name and an adjective, and the grammar decides. A capital past ASCII,
% "Île" or "Çorlu", is seen as one where the interpreter's case table has
% it: Latin-1, Latin Extended-A, Greek and basic Cyrillic.
words(Text, Words, Names) :-
    atom_chars(Text, Chars0),
    maplist(plain_apostrophe, Chars0, Chars),
    split_letters(Chars, Cased),
    maplist(downcase_atom, Cased, Words),
    names(Cased, Words, Names0),
    sort(Names0, Names).

names([], [], []).
names([C|Cs], [W|Ws], Names) :-
    maplist(later_name, Cs, Ws, Ns0),
    exclude(==(none), Ns0, Ns),
    (   capital(C), \+ closed_class(W),
        (   Ws = [W2|_], ( memberchk(W2, Ns) ; digits(W2) )
        ;   proper(W)
        ;   wn_name(W)
        ;   \+ known_word(W), \+ placement(W, wordnet, _)
        )
    ->  Names = [W|Ns]
    ;   Names = Ns
    ).

later_name(C, W, W)    :- capital(C), \+ closed_class(W), !.
later_name(_, _, none).

capital(C) :- atom_chars(C, [F|_]), char_type(F, upper(_)).

closed_class(W) :- det(W, _, _), !.
closed_class(W) :- pronoun(W, _, _), !.
closed_class(W) :- prep(W), !.
closed_class(W) :- coordinator(W), !.
closed_class(W) :- subordinator(W), !.
closed_class(W) :- be_form(W, _), !.
closed_class(W) :- have_form(W, _), !.
closed_class(W) :- do_form(W, _), !.
closed_class(W) :- rel_pronoun(W, _), !.
closed_class(W) :- wh_pronoun(W, _), !.
closed_class(W) :- wh_det(W), !.
closed_class(W) :- wh_adverb(W), !.
closed_class(W) :- clitic(W, _), !.
closed_class(W) :- neg_contraction(W, _), !.

plain_apostrophe('\x2019\', '\'') :- !.
plain_apostrophe(C, C).

split_letters([], []).
split_letters([','|Cs], [','|Ws]) :- !, split_letters(Cs, Ws).
split_letters([C|Cs], Words) :-
    digit(C), !,
    take_number([C|Cs], Ds, Rest),
    atom_chars(W, Ds),
    Words = [W|Ws],
    split_letters(Rest, Ws).
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

% take_number(+Chars, -Number, -Rest): a run of digits, with a point or
% comma inside it kept when a digit follows, 3.5 or 1,000; a full stop
% after it ends the sentence and is not part of it.
take_number([C|Cs], [C|Ds], Rest) :- digit(C), !, take_number(Cs, Ds, Rest).
take_number([P, D|Cs], [P, D|Ds], Rest) :-
    ( P == '.' ; P == ',' ), digit(D), !, take_number(Cs, Ds, Rest).
take_number(Rest, [], Rest).
