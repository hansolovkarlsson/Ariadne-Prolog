/*  english/guess.pl -- a guess at a word missing from the lexicon.

    A word the lexicon does not list can often still be placed by its
    ending: quickly is an adverb, nation a noun, careful an adjective,
    organize a verb. An inflected word is first taken back to its stem, as
    blorfed to blorf, and the stem is placed by its own ending, or, when it
    has none, taken as a noun or a verb, the two classes an unknown word is
    likeliest to be. A guessed stem joins the lexicon for one check only,
    through guessed/2, so its other forms come from the rules that make the
    listed words' forms, and agree as theirs do.

    A word with no ending to go on is not guessed. That keeps a misspelling,
    furiouslyy, from being read as some new word.
*/

% guess(+Word, -Class, -Stem): Word could be a form of Stem, of Class noun,
% verb, adj or adv. Stem is what the lexicon would list: the singular of a
% noun, the base of a verb.
guess(W, adv, W) :- atom_concat(S, ly, W), atom_length(S, N), N >= 3.
guess(W, C, W) :- \+ atom_concat(_, ly, W), suffix_class(W, C).
guess(W, C, S) :- inflection(W, S, Ending), stem_class(S, C), takes(C, Ending).

% inflection(+Word, -Stem, -Ending): Word is Stem with an -s, -ed or -ing
% ending, by the lexicon's own rules. The candidates are made by undoing
% the ending every way it could have been made, and kept only when the rule
% gives Word back from them. A word in -ss, -us or -is is not a plural.
inflection(W, S, s) :-
    \+ atom_concat(_, ss, W), \+ atom_concat(_, us, W), \+ atom_concat(_, is, W),
    candidate(W, s, S), s_form(S, W).
inflection(W, S, ed)  :- candidate(W, ed, S), past(S, W).
inflection(W, S, ing) :- candidate(W, ing, S), ing(S, W).

% candidate(+Word, +Ending, -Stem): Word with Ending taken off, and put back
% as the spelling rules may have changed it: an e dropped, a y turned to i.
candidate(W, E, S) :-
    atom_concat(S0, E, W), atom_length(S0, N), N >= 2,
    (   S = S0
    ;   atom_concat(S0, e, S)
    ;   atom_concat(Si, i, S0), atom_concat(Si, y, S)
    ).
candidate(W, s, S) :- atom_concat(S, es, W), atom_length(S, N), N >= 2.
candidate(W, s, S) :-
    atom_concat(Si, ies, W), atom_length(Si, N), N >= 1, atom_concat(Si, y, S).

% stem_class(+Stem, -Class): by the stem's ending, or noun or verb.
stem_class(S, C) :- suffix_class(S, C0), !, C = C0.
stem_class(_, noun).
stem_class(_, verb).

% takes(+Class, +Ending): which endings a class can carry.
takes(noun, s).
takes(verb, _).

% suffix_class(+Word, -Class): an ending that marks a class.
suffix_class(W, C) :- suffix(Suffix, C), atom_concat(S, Suffix, W),
    atom_length(S, N), N >= 2, !.

suffix(tion, noun). suffix(sion, noun). suffix(ment, noun). suffix(ness, noun).
suffix(ity, noun).  suffix(ism, noun).  suffix(ist, noun).  suffix(ship, noun).
suffix(hood, noun). suffix(ance, noun). suffix(ence, noun). suffix(er, noun).
suffix(or, noun).
suffix(ful, adj).   suffix(ous, adj).   suffix(ive, adj).   suffix(able, adj).
suffix(ible, adj).  suffix(less, adj).  suffix(ish, adj).   suffix(ical, adj).
suffix(ic, adj).    suffix(al, adj).
suffix(ize, verb).  suffix(ise, verb).  suffix(ify, verb).  suffix(ate, verb).

% with_guesses(+Words, :Goal): Goal, with every guess for each of Words in
% the lexicon while it runs, and none after. Goal is run once.
with_guesses(Words, Goal) :-
    forall(( member(W, Words), guess(W, C, S) ), assertz(guessed(C, S))),
    (   catch(Goal, E, (retractall(guessed(_, _)), throw(E)))
    ->  retractall(guessed(_, _))
    ;   retractall(guessed(_, _)), fail
    ).

% guessable(+Word): some guess can be made for Word.
guessable(W) :- guess(W, _, _), !.

% guessed_classes(+Word, -Classes): the classes guessed for Word, in order.
guessed_classes(W, Cs) :- setof(C, S^guess(W, C, S), Cs).
