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

% Stage 2: auxiliaries, negation, yes/no questions, passives.
good('The dog does not bark.').
good('The dog doesn\'t bark.').
good('The dog doesn\x2019\t bark.').
good('The dogs do not bark.').
good('The dog did not bark yesterday.').
good('The dog does bark.').
good('The dog can swim.').
good('The dog cannot swim.').
good('The dog can\'t swim.').
good('The birds will not sing.').
good('The birds won\'t sing.').
good('You must help me.').
good('The dog is sleeping.').
good('The dogs are chasing the cat.').
good('I am reading a book.').
good('The children were running in the park.').
good('The dog has eaten the cake.').
good('The dogs have eaten.').
good('The dog had stopped.').
good('The dog has been sleeping.').
good('The dog will be happy.').
good('The dog has been happy.').
good('The cake was eaten.').
good('The cat was chased by the dog.').
good('The dog was given a bone.').
good('The cake has been eaten by the children.').
good('The house is being built.').
good('The dog might have been chased.').
good('The letter should have been written yesterday.').
good('The dog is not happy.').
good('The dog isn\'t happy.').
good('I am not tired.').
good('The dog has not eaten.').
good('Alice has a dog.').
good('Alice does not have a dog.').
good('Does the dog bark?').
good('Does Alice have a dog?').
good('Is the dog happy?').
good('Is the dog sleeping?').
good('Can the birds fly?').
good('Has the dog eaten?').
good('Doesn\'t the dog bark?').
good('Does the dog not bark?').
good('Is the dog not happy?').
good('Were the children in the garden?').
good('Was the cat chased by the dog?').
good('Will you help me?').
good('Did Alice give the dog a bone?').

% Stage 2: relative clauses and wh-questions.
good('The dog that chased the cat barks.').
good('The dogs that chase the cat bark.').
good('The cat that the dog chased sleeps.').
good('The cat the dog chased sleeps.').
good('The man who sleeps is old.').
good('The man whom Alice saw sleeps.').
good('Alice likes the book which Bob wrote.').
good('The park that the dog walks in is big.').
good('The cake that was eaten by the children was big.').
good('I know the man who gave the dog a bone.').
good('The dog that the cat that the mouse saw chased barks.').
good('The dog in the garden that barks is old.').
good('Who chased the cat?').
good('What did the dog chase?').
good('Which dog chased the cat?').
good('Which dogs chase the cat?').
good('Who does Alice like?').
good('Whom did Alice see?').
good('What is the dog eating?').
good('Who is happy?').
good('What was eaten?').
good('Who was the cake eaten by?').
good('Where does the dog sleep?').
good('Why is the dog happy?').
good('When did the children arrive?').
good('Who did Alice give a bone?').
good('Which book did the teacher read to the children?').

% Stage 2: words missing from the lexicon, placed by their endings.
good('The dog blorfed the cat.').
good('The zorbles are happy.').
good('The organization sleeps.').
good('The organizations sleep.').
good('Alice is wonderful.').
good('The dog barked cheerfully.').
good('The children were glimbing the tree.').
good('The farmer modernized the village.').
good('The happiness of the children is strange.').
good('The farmers are careless.').

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

% Stage 2.
bad('The dog can barks.',                  verb_form(can, barks, base)).
bad('The dog does not barks.',             verb_form(does, barks, base)).
bad('The dog doesn\'t barks.',             verb_form('doesn\'t', barks, base)).
bad('The dogs does not bark.',             subject_verb(does)).
bad('The dog do not bark.',                subject_verb(do)).
bad('The dogs has eaten.',                 subject_verb(has)).
bad('The dog has ate the cake.',           verb_form(has, ate, en)).
bad('The dog is sleep.',                   verb_form(is, sleep, ing)).
bad('The dog is chased the cat.',          verb_form(is, chased, ing)).
bad('The cat was chase by the dog.',       verb_form(was, chase, en)).
bad('The dog will sleeping.',              verb_form(will, sleeping, base)).
bad('The dogs was chased.',                subject_verb(was)).
bad('The dog sleeping.',                   finite(sleeping)).
bad('The dog barks not.',                  do_support(barks)).
bad('The dog barked not.',                 do_support(barked)).
bad('Barks the dog?',                      question_do(barks)).
bad('Does the dog barks?',                 verb_form(does, barks, base)).
bad('Is the dogs happy?',                  subject_verb(is)).
bad('Does the dogs bark?',                 subject_verb(does)).
bad('The dog was slept.',                  verb_form(was, slept, ing)).
bad('The dog is being sleeping.',          no_reading).
bad('The dog does not be happy.',          no_reading).
bad('The dog can can swim.',               no_reading).
bad('The dog is having eaten.',            no_reading).
bad('Does not the dog bark?',              no_reading).
bad('The dogs that chases the cat bark.',  subject_verb(chases)).
bad('The dog that chase the cat barks.',   subject_verb(chase)).
bad('The man whom sleeps is old.',         case(whom)).
bad('Which dogs chases the cat?',          subject_verb(chases)).
bad('Whom chased the cat?',                case(whom)).
bad('What does the dog chases?',           verb_form(does, chases, base)).
bad('The cat that the dog chased the mouse sleeps.', no_reading).
bad('What did the dog chase the cat?',     no_reading).
bad('Who the dog chased?',                 no_reading).
bad('The dog that barks.',                 no_reading).
bad('The dog chased the cat barks.',       no_reading).
bad('The zorbles is happy.',               subject_verb(is)).
bad('A zorbles sleep.',                    det_noun(a, zorbles)).
bad('The organization sleep.',             subject_verb(sleep)).
bad('The dog xqzt the cat.',               unknown).
bad('A zorble is happy.',                  unknown).

readings('The old man walks in the park with his dog.', 2).
readings('The dogs chase a cat.', 1).
readings('I read a book.', 1).
readings('The dog has eaten.', 1).
readings('Is the dog sleeping?', 1).
readings('The cat that the dog chased sleeps.', 1).
readings('What did the dog chase?', 1).
readings('The dog in the garden that barks is old.', 2).

% verdict(+Text, -V): grammatical, unknown (a word outside the lexicon that
% its ending does not place), no_reading, or the first violation of the
% best relaxed reading.
verdict(Text, V) :-
    words(Text, Words),
    unknown_words(Words, U),
    (   member(W, U), \+ guessable(W)
    ->  V = unknown
    ;   with_guesses(U, verdict_of(Words, V))
    ).

verdict_of(Words, V) :-
    (   phrase(sentence(_, [], []), Words)
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
    all_readings(Words, Ts),
    length(Ts, M),
    (   M =:= N -> F1 = F0
    ;   format("FAIL  readings: ~w  expected ~d, got ~d~n", [S, N, M]), F1 is F0 + 1
    ),
    check_readings(Ss, F1, F).
