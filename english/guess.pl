/*  english/guess.pl -- placing a word missing from the lexicon.

    A word the lexicon does not list is looked up in WordNet, when
    english/wordnet_check.pl has loaded it, and otherwise guessed from its
    ending. Either way what is found joins the lexicon for one check only,
    through guessed/2, so the word's other forms come from the rules that
    make the listed words' forms, and agree as theirs do.

    In WordNet, a word is found as itself, as an -s, -ed or -ing form of a
    stem WordNet has, or in WordNet's lists of irregular forms: flung is
    fling, oxen is ox, grabbed is grab with its consonant doubled. A
    hyphenated word WordNet has only closed up, north-eastern, is found as
    northeastern. A verb
    brings the frames WordNet gives it. The lexicon's own words are never
    looked up, so a word it lists keeps only the entries it gives, and can,
    will and a do not become WordNet's nouns.

    A comparative or superlative, largest, is its adjective's, large, in
    WordNet or in the lexicon, and is placed as an adjective itself.

    By its ending, quickly is an adverb, nation a noun, careful an
    adjective, organize a verb. An inflected word is first taken back to its
    stem, as blorfed to blorf, and the stem is placed by its own ending, or,
    when it has none, taken as a noun or a verb, the two classes an unknown
    word is likeliest to be. A word with no ending to go on is not guessed.
    That keeps a misspelling, furiouslyy, from being read as some new word.
*/

% placement(+Word, -Source, -Entries): Word missing from the lexicon can be
% placed, from Source, wordnet or ending, as Entries, a list of What-Entry
% pairs for guessed/2. It fails if neither places it.
placement(W, wordnet, Es) :-
    findall(E, wordnet_entry(W, E), Es0), Es0 \== [], !, sort(Es0, Es).
placement(W, ending, Es) :-
    findall(C-S, guess(W, C, S), Es0), Es0 \== [], sort(Es0, Es1),
    maplist(guessed_frames, Es1, Es).

% A verb guessed from its ending may take one object or none.
guessed_frames(verb-S, verb([intrans, trans])-S) :- !.
guessed_frames(E, E).

placeable(W) :- placement(W, _, _), !.

% with_placements(+Words, +Names, :Goal): Goal, with every entry for each
% of Words in the lexicon while it runs, and each of Names a name, and none
% of them after. Goal is run once. with_placements/2 places no names.
with_placements(Words, Goal) :- with_placements(Words, [], Goal).

with_placements(Words, Names, Goal) :-
    forall(( member(W, Words), placement(W, _, Es), member(What-E, Es) ),
           assertz(guessed(What, E))),
    forall(member(N, Names), assertz(guessed(name, N))),
    (   catch(Goal, Ball, (unplace, throw(Ball)))
    ->  unplace
    ;   unplace, fail
    ).

% unplace: the placements are taken out again, and with them what was
% kept per word while they stood; see participle_adj/1 in lexicon.pl.
unplace :-
    retractall(guessed(_, _)),
    retractall(participle_memo(_, _, _)).

% placed_classes(+Word, -Source, -Classes): where Word was placed from, and
% the classes, in order.
placed_classes(W, Source, Cs) :-
    placement(W, Source, Es),
    setof(C, E^S^( member(E-S, Es), class_of(E, C) ), Cs).

class_of(noun, noun).
class_of(verb(_), verb).
class_of(adj, adj).
class_of(adv, adv).

/* ---------------- WordNet ---------------- */

% wordnet_entry(+Word, -Entry): an entry for Word from WordNet.
wordnet_entry(W, noun-W) :- wn_noun(W).
wordnet_entry(W, verb(Fs)-W) :- wn_verb(W, Fs).
wordnet_entry(W, adj-W) :- wn_adj(W).
wordnet_entry(W, adv-W) :- wn_adv(W).
wordnet_entry(W, noun-S) :- inflection(W, S, s), wn_noun(S).
wordnet_entry(W, verb(Fs)-S) :- inflection(W, S, _), wn_verb(S, Fs).
wordnet_entry(W, Class-W) :- closed_up(W, C), wordnet_entry(C, Class-C).
wordnet_entry(W, adj-W) :- degree_inflection(W, B, _), wn_adj(B).
wordnet_entry(W, E) :- wn_irregular(noun, W, S), wn_noun(S),
    member(E, [noun-S, irregular_plural-(S-W)]).
wordnet_entry(W, E) :- wn_irregular(verb, W, B), wn_verb(B, Fs),
    (   doubled(B, W)
    ->  member(E, [verb(Fs)-B, doubles-B])
    ;   member(E, [verb(Fs)-B, irregular_form-(B-W)])
    ).

% closed_up(+Word, -Closed): Word has a hyphen inside it, and Closed is
% Word without its hyphens: north-eastern and northeastern. WordNet writes
% many such words one way only, and a text the other, so a hyphenated
% word it does not have is looked up closed, and takes the entries of the
% closed word that are the word itself and not a form of another.
closed_up(W, C) :-
    atomic_list_concat(Parts, '-', W), Parts = [_, _|_],
    atomic_list_concat(Parts, C).

% doubled(+Base, +Form): Form is Base with its last consonant doubled before
% -ed or -ing, grab and grabbed, which is a rule the lexicon has, and not
% an irregular form.
doubled(B, W) :-
    atom_chars(B, Cs), last(Cs, C),
    ( atomic_list_concat([B, C, ed], W) ; atomic_list_concat([B, C, ing], W) ), !.

/* ---------------- endings ---------------- */

% guess(+Word, -Class, -Stem): Word could be a form of Stem, of Class noun,
% verb, adj or adv. Stem is what the lexicon would list: the singular of a
% noun, the base of a verb.
guess(W, adv, W) :- atom_concat(S, ly, W), atom_length(S, N), N >= 3.
guess(W, C, W) :- \+ atom_concat(_, ly, W), suffix_class(W, C).
guess(W, C, S) :- inflection(W, S, Ending), stem_class(S, C), takes(C, Ending).
guess(W, adj, W) :- degree_inflection(W, B, _), adj(B).

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
    ;   E == ing, atom_concat(Si, y, S0), atom_concat(Si, ie, S)
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
