/*  english/tests.pl -- the grammar's own checks.

    Run with:  make english      (or bin/prolog -q english/tests.pl -g run)

    good/1 sentences must be grammatical; bad/2 sentences must not be, and
    the diagnosis, parsing again with agreement relaxed, must name the kind
    of violation given. readings/2 pins how many structures a sentence has,
    so that a change which adds or loses an ambiguity is seen.
*/

:- consult(check).

good('The dog sleeps.').
good('Dogs bark.').
good('The dogs chase a cat.').
good('A cat chases the dogs.').
good('An apple is red.').
good('An old man walks.').
good('A young elephant eats.').
good('An hour is long.').
good('A university is big.').
good('A unicorn sings.').
good('An honest farmer walks.').
good('I am happy.').
good('You are tired.').
good('She is a doctor.').
good('We were in the garden.').
good('I was hungry.').
good('They were hungry.').
good('He sees her.').
good('She sees him.').
good('You see me.').
good('It bites them.').
good('Alice gives the dog a bone.').
good('Bob sent Carol a letter.').
good('The children were in the garden.').
good('The mice ate the cake yesterday.').
good('The dog and the cat chase the mouse.').
good('Alice and Bob gave the tired children three red apples.').
good('The old man walks in the park with his dog.').
good('Colorless green ideas sleep furiously.').
good('My friend reads a story to the children.').
good('Every student knows the answer.').
good('These flowers are beautiful.').
good('That box is empty.').
good('The fox carries the babies across the river.').
good('The foxes cry.').
good('The bird flies.').
good('The birds fly quickly.').
good('The sheep sleep.').
good('The sheep sleeps.').
good('Two geese swam in the river.').
good('The teacher watches the students carefully.').
good('Oscar is in London.').
good('It is me.').

bad('The dogs chases a cat.',              subject_verb(chases)).
bad('The dog chase a cat.',                subject_verb(chase)).
bad('I is happy.',                         subject_verb(is)).
bad('You is tired.',                       subject_verb(is)).
bad('They was hungry.',                    subject_verb(was)).
bad('He were late.',                       subject_verb(were)).
bad('I are tired.',                        subject_verb(are)).
bad('The dog and the cat chases the mouse.', subject_verb(chases)).
bad('Alice and Bob sings.',                subject_verb(sings)).
bad('A dogs bark.',                        det_noun(a, dogs)).
bad('These dog barks.',                    det_noun(these, dog)).
bad('This dogs bark.',                     det_noun(this, dogs)).
bad('A apple is red.',                     article(a, apple)).
bad('An dog barks.',                       article(an, dog)).
bad('An big apple is red.',                article(an, big)).
bad('A old man walks.',                    article(a, old)).
bad('An university is big.',               article(an, university)).
bad('A hour is long.',                     article(a, hour)).
bad('Him sleeps.',                         case(him)).
bad('She sees he.',                        case(he)).
bad('Me am happy.',                        case(me)).
bad('The dog bites they.',                 case(they)).
bad('Dog barks.',                          bare(dog)).
bad('The cat chases mouse.',               bare(mouse)).
bad('The dog quickly.',                    no_reading).
bad('Chases the dog.',                     no_reading).
bad('The dog the cat.',                    no_reading).
bad('Colorless green ideas sleep furiouslyy.', unknown).

readings('The old man walks in the park with his dog.', 2).
readings('The dogs chase a cat.', 1).

% verdict(+Text, -V): grammatical, unknown (a word outside the lexicon),
% no_reading, or the first violation of the best relaxed reading.
verdict(Text, V) :-
    words(Text, Words),
    (   unknown_words(Words, U), U \== []
    ->  V = unknown
    ;   phrase(sentence(_, [], []), Words)
    ->  V = grammatical
    ;   diagnosis(Words, [V0|_])
    ->  V = V0
    ;   V = no_reading
    ).

run :-
    findall(S, good(S), Good),
    findall(S-E, bad(S, E), Bad),
    findall(S-N, readings(S, N), Readings),
    check_good(Good, 0, F1),
    check_bad(Bad, F1, F2),
    check_readings(Readings, F2, F),
    length(Good, G), length(Bad, D), length(Readings, R),
    Total is G + D + R,
    Passed is Total - F,
    format("~d grammar checks, ~d passed, ~d failed~n", [Total, Passed, F]),
    (   F =:= 0 -> halt ; halt(1) ).

check_good([], F, F).
check_good([S|Ss], F0, F) :-
    verdict(S, V),
    (   V == grammatical -> F1 = F0
    ;   format("FAIL  good: ~w  (~q)~n", [S, V]), F1 is F0 + 1
    ),
    check_good(Ss, F1, F).

check_bad([], F, F).
check_bad([S-E|Ss], F0, F) :-
    verdict(S, V),
    (   V == E -> F1 = F0
    ;   format("FAIL  bad: ~w  expected ~q, got ~q~n", [S, E, V]), F1 is F0 + 1
    ),
    check_bad(Ss, F1, F).

check_readings([], F, F).
check_readings([S-N|Ss], F0, F) :-
    words(S, Words),
    findall(T, phrase(sentence(T, [], []), Words), Ts),
    length(Ts, M),
    (   M =:= N -> F1 = F0
    ;   format("FAIL  readings: ~w  expected ~d, got ~d~n", [S, N, M]), F1 is F0 + 1
    ),
    check_readings(Ss, F1, F).
