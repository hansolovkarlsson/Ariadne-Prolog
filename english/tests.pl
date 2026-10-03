/*  english/tests.pl -- the grammar's own checks.

    Run with:  make english      (or bin/prolog -q english/tests.pl -g run)

    good/1 sentences must be grammatical; bad/2 sentences must not be, and
    the diagnosis, parsing again with agreement relaxed, must name the kind
    of violation given. readings/2 pins how many structures a sentence has,
    so that a change which adds or loses an ambiguity is seen. splits/2
    pins how check_text/1 cuts running text into sentences.
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

% Stage 2: contractions cut from their word, and possessives.
good('She\'s happy.').
good('It\'s a dog.').
good('I\'m tired.').
good('You\'re kind.').
good('They\'re sleeping.').
good('We\'ve eaten.').
good('I\'ll help you.').
good('She\'d help you.').
good('He\'d eaten the cake.').
good('The dog\'s sleeping.').
good('The dog\'s eaten the cake.').
good('She\'s not happy.').
good('She\x2019\s happy.').
good('What\'s the dog eating?').
good('Who\'s sleeping?').
good('Alice\'s dog barks.').
good('The dog\'s bone is big.').
good('The farmer\'s old dog sleeps.').
good('Alice\'s friend\'s dog barks.').
good('The dogs\' bones are big.').
good('The children\'s toys are red.').
good('The cat chased Alice\'s dog.').

% Stage 3: lexicon entries the corpus found incomplete.
good('The teacher tells a story.').
good('The door opens.').
good('The window closes.').
good('We should arrive early.').
good('The train arrived late.').

% Stage 3: nouns that take no article.
good('Bread is good.').
good('Alice drinks tea.').
good('The children ate rice.').
good('We ate dinner in the garden.').
good('The teacher gave the students some homework.').
good('The boys play football in the park.').
good('The dog wants much food.').
good('A coffee is good.').
good('Alice likes happiness.').
good('Alice wants education.').
bad('Alice wants station.',               bare(station)).
bad('Yesterday the dog bark.',             subject_verb(bark)).
bad('Yesterday dog barked.',               bare(dog)).
bad('In the garden, sleeps.',              no_reading).
bad('About the dog barked.',               no_reading).
bad('Quite the dog barked.',               no_reading).
bad('Some dog barks.',                     det_noun(some, dog)).
bad('It is a picture of bird.',            bare(bird)).
bad('The dog slept on 40 May 1969.',      no_reading).
bad('The dog (a big one) bark.',           subject_verb(bark)).
bad('Alice (and Bob) sing.',               subject_verb(sing)).

% Stage 3: the closed classes WordNet does not have.
good('The dog barks and the cat sleeps.').
good('The dog barks but the cat sleeps.').
good('The dog sleeps because the cat is quiet.').
good('Because the cat is quiet the dog sleeps.').
good('If the dog barks the cat runs.').
good('The cat sleeps until the dog arrives.').
good('Nobody sleeps.').
good('Alice sees nobody.').
good('Everyone is happy.').
good('Six dogs bark.').
good('A hundred birds sang.').
good('Two thousand birds fly.').
good('The dog sleeps at 6.').
good('The party is at six.').
good('The children played football after school.').
good('The dog slept during the party.').

% Stage 3: the constructions the corpus found missing.
good('The dog is very happy.').
good('A very old man walks.').
good('An extremely old man walks.').
good('The cat is too big.').
good('The dog has never eaten the cake.').
good('The dog always sleeps.').
good('Does the dog often bark?').
good('The dog barks every night.').
good('The cat slept this morning.').
good('Alice wants to swim.').
good('Alice wants the dog to swim.').
good('The dog likes swimming.').
good('The dog stopped barking.').
good('I know that the dog sleeps.').
good('I know the dog sleeps.').
good('They paint the house red.').
good('The house was painted red.').
good('She found the box empty.').
good('I have never seen such a big dog.').
good('Close the door.').
good('Please close the door.').
good('Close the door please.').
good('Don\'t bark.').
good('Be quiet.').


% Names: a capitalized word, a run of them, and a name before a noun.
good('Leroy sleeps.').
good('The dog sees Leroy.').
good('Stanley Ralph Ross sleeps.').
good('Alice saw Stanley Ralph Ross.').
good('Leroy\'s dog barks.').
good('The Congress Party is big.').
good('I read the Leroy book.').
good('Apollo 11 sleeps.').
good('The dog sees Apollo 11.').
good('The dog sees Çorlu.').
good('I read the Apollo 11 book.').

% Lists and or: noun phrases, nouns under one determiner, adjectives, and
% the commas between clauses.
good('I saw cats or dogs.').
good('The dog or the cat barks.').
good('The dog or the cats bark.').
good('The dogs or the cat barks.').
good('Alice, Bob and Carol sing.').
good('Alice, Bob, and Carol sing.').
good('I saw a dog, a cat and a mouse.').
good('She is a doctor and teacher.').
good('The cat and dog are hungry.').
good('The dog is big or small.').
good('The dog is big, old and happy.').
good('A big, old dog barks.').
good('A small but happy dog barks.').
good('The dog barks, but the cat sleeps.').
good('If it rains, the dog sleeps.').
good('Close the door, please.').

% A phrase before the subject.
good('Yesterday the dog barked.').
good('Last night the dog barked.').
good('In the garden, the children played.').
good('Every day the dog sleeps in the kitchen.').
good('About six dogs barked.').
good('Really, the dog barked.').

% A kind of, and adverbs after be.
good('It is a kind of bird.').
good('It is some kind of bird.').
good('It is any kind of cake or bread.').
good('The dog is never hungry.').
good('Alice is always a doctor.').

% Dates.
good('The dog barked on May 16, 2015.').
good('The dog slept on 10 May 1969.').
good('The dog slept on 10 May.').

% Brackets: what stands in them is set aside.
good('The dog (a big one) barks.').
good('Alice (born 10 May 1969) sleeps.').
good('The dog barks (loudly).').
good('(The dog barks.)').

% Nouns before nouns.
good('The dog house is big.').
good('I read the picture book.').
good('The school bus stopped at the train station.').
good('An apple tree grows in the garden.').
good('The old stone house is big.').

% The mark at the end: a question ends with ?, a statement or a command with
% . or !; with no mark the text is taken as it is.
good('The dog barks!').
good('Close the door!').
good('The dog barks').
good('Does the dog bark').
good('"Does the dog bark?"').
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
bad('Dog bark.',                           subject_verb(bark)).
bad('Much dog barks.',                     det_noun(much, dog)).
bad('The dog eats much apples.',           det_noun(much, apples)).
bad('Alice drink tea.',                    subject_verb(drink)).
bad('The dog barks but the cats sleeps.',  subject_verb(sleeps)).
bad('Nobody sleep.',                       subject_verb(sleep)).
bad('Six dog bark.',                       det_noun(six, dog)).
bad('One dogs bark.',                      det_noun(one, dogs)).
bad('A hundred dog barks.',                det_noun('a hundred', dog)).
bad('Because the cat is quiet.',           no_reading).
bad('The dog barks because.',              no_reading).
bad('Hundred dogs bark.',                  no_reading).
bad('The dog is very.',                    no_reading).
bad('Alice wants swim.',                   no_reading).
bad('Alice wants to swims.',               verb_form(to, swims, base)).
bad('I know that the dogs barks.',         subject_verb(barks)).
bad('Such a dogs bark.',                   det_noun('such a', dogs)).
bad('Such an dog barks.',                  article('such an', dog)).
bad('The dog always bark.',                subject_verb(bark)).
bad('The dog has never ate the cake.',     verb_form(has, ate, en)).
bad('Closes the door.',                    question_do(closes)).
bad('Don\'t barks.',                       no_reading).
bad('I saw 1 dogs.',                      det_noun('1', dogs)).
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
bad('They\'s sleeping.',                   subject_verb('\'s')).
bad('I\'s happy.',                         subject_verb('\'s')).
bad('She\'re happy.',                      subject_verb('\'re')).
bad('She\'ll eats.',                       verb_form('\'ll', eats, base)).
bad('Alice\'s dogs barks.',                subject_verb(barks)).
bad('An dog\'s bone is big.',              article(an, dog)).
bad('A old man\'s dog barks.',             article(a, old)).
bad('The cat saw dog\'s bone.',            bare(dog)).
bad('The dog sees leroy.',                unknown).
bad('Leroy sleep.',                        subject_verb(sleep)).
good('Dog barks.').
good('Fox was in the garden.').
good('Dog\'s bone is big.').
bad('Dogs sleeps.',                        subject_verb(sleeps)).
bad('The dog sees Leroy Ross the cat.',    no_reading).
bad('Apollo 11 sleep.',                    subject_verb(sleep)).
bad('The dog or the cat bark.',            subject_verb(bark)).
bad('The dogs or the cat bark.',           subject_verb(bark)).
bad('These cat and dogs sleep.',           det_noun(these, cat)).
bad('Alice, Bob sing.',                    subject_verb(sing)).
good('Alice sleeps in London, England.').
good('Alice, Bob sings.').
readings('Alice sleeps in London, England.', 1).
readings('Alice, Bob and Carol sleep.', 2).
good('Alice sleeps in old London.').
good('Old London sleeps.').
good('Alice sleeps in Bernes-sur-Oise.').
good('The dog-cat sleeps.').
readings('Alice sleeps in old London.', 1).
readings('Old London sleeps.', 1).
bad('Alice sleeps in old London sleeps.',  no_reading).
good('The biggest dog sleeps.').
good('The largest dog sleeps.').
good('The happiest dog sleeps.').
good('The older dog sleeps.').
good('The 27th dog sleeps.').
good('The dog is older.').
bad('The biggest dog sleep.',               subject_verb(sleep)).
bad('A 27th dogs sleep.',                   det_noun(a, dogs)).
bad('The forest sleep.',                    subject_verb(sleep)).
good('The dog is tired of barking.').
good('The dog sleeps after eating the cake.').
good('The dog has a bone for being the biggest dog.').
good('The dog sleeps after having eaten the cake.').
bad('The dog sleeps after eat the cake.',   no_reading).
bad('The dog sleeps after eating the cakes sleeps.', no_reading).
good('The dog sleeps and eats.').
good('The dog barks, eats and sleeps.').
good('The cat was chased by the dog and eaten by the fox.').
good('The dog either sleeps or eats.').
good('Either the dog or the cat sleeps.').
good('Neither the dog nor the cats sleep.').
good('Both the dog and the cat sleep.').
good('He was a doctor, teacher and a farmer.').
good('Close the door and visit the garden.').
readings('The dog sleeps and eats.', 1).
readings('He was a doctor, teacher and a farmer.', 1).
bad('The dog sleeps and eat.',              subject_verb(eat)).
bad('Either the dog or the cat sleep.',     subject_verb(sleep)).
bad('Both the dog and the cat sleeps.',     subject_verb(sleeps)).
bad('Either the dog sleeps.',               no_reading).
bad('The dog sleeps either.',               no_reading).
bad('The dog, barks.',                     no_reading).
% An appositive after a name, and a bare role noun after be and beside a
% name.
good('Alice, a doctor, sleeps.').
good('The dog sees Alice, a doctor.').
good('Alice, the old farmer\'s friend, sleeps.').
good('Alice is teacher of the children.').
good('Alice, friend of the king, sleeps.').
good('Alice sees Bob, friend and teacher of the children.').
readings('Alice is teacher of the children.', 1).
readings('I saw Alice, a doctor, and Bob.', 2).
readings('I saw Alice, a doctor and Bob.', 1).
bad('Alice, a doctor sleeps.',             no_reading).
bad('Alice, a doctors, sleeps.',           det_noun(a, doctors)).
bad('Alice, friend of the king, sleep.',   subject_verb(sleep)).
bad('Alice is teacher.',                   bare(teacher)).
bad('Alice is dog of the king.',           bare(dog)).
bad('Alice sees teacher of the king.',     bare(teacher)).
% die, lie and tie in -ing, and a comma before the conjunction between
% two verb phrases.
good('The dog is dying.').
good('The dog slept before dying.').
good('The dog ran in, but slept.').
good('The dog barked, and slept.').
readings('The dog barked, and slept.', 1).
bad('The dog barked, slept.',             no_reading).
bad('Alice, and Bob sleep.',              no_reading).
% A particle after the verb.
good('The dog ran in.').
good('The dog was carried in by Alice.').
good('Alice ran in as the queen.').
readings('The dog ran in.', 1).
readings('The dog sleeps in the garden.', 1).
bad('The dog ran in the.',                no_reading).
bad('The dogs runs in.',                  subject_verb(runs)).
% A name after a noun says which one.
good('The river Thames is long.').
good('I know the farmer Bob.').
good('The dog sees the farmer Bob of London.').
readings('The river Thames is long.', 1).
readings('I know the farmer Bob.', 1).
bad('The farmer Bob are old.',             subject_verb(are)).
bad('I see farmer Bob.',                  bare(farmer)).
% A preposition of three words.
good('The dog sleeps in front of the house.').
good('The cat sleeps on top of the box.').
readings('The dog sleeps in front of the house.', 1).
bad('The dog sleeps in front the house.',  no_reading).
% Of and a name after a name are part of it.
good('Alice of London sleeps.').
good('The dog sees Alice of London.').
readings('Alice of London sleeps.', 1).
readings('The dog sees Alice of London.', 2).
bad('Alice of London sleep.',             subject_verb(sleep)).
bad('Alice of sleeps.',                   no_reading).
% A participle after a noun, and before it.
good('The dogs chased by the cat bark.').
good('The dog chasing the cat barks.').
good('The cake eaten by the fox was big.').
good('I saw the dog chasing the cat.').
readings('The dogs chased by the cat bark.', 1).
bad('The dogs chased by the cat barks.',   subject_verb(barks)).
bad('The dogs chase by the cat bark.',     no_reading).
bad('The dog chasing the cat bark.',       subject_verb(bark)).
% A participle before a noun.
good('The sleeping dog barks.').
good('A painted house is big.').
good('An eaten cake is small.').
good('The barking dogs sleep in the painted house.').
readings('The sleeping dog barks.', 1).
bad('The sleeping dogs barks.',            subject_verb(barks)).
bad('A painted houses are big.',           det_noun(a, houses)).
bad('A eaten cake is small.',              article(a, eaten)).
good('The dog sleeping barks.').
bad('The dog, and the cat sleep.',         no_reading).
% A request without a verb.
good('Two cups of tea, please.').
good('A coffee, please.').
good('Please, two cups of tea.').
good('The dogs please.').
readings('A coffee, please.', 1).
readings('The dogs please.', 1).
bad('A coffees, please.',                  det_noun(a, coffees)).
bad('Two cups of tea, please?',            punctuation('?')).
bad('A coffee.',                           no_reading).
bad('A coffee please.',                    subject_verb(please)).
bad('Please, two cups of tea, please.',    no_reading).
% "Please two cups of tea" is a command, please being a verb.
% A noun that is an adjective too, after a noun modifier.
good('I saw the garden orange tree.').
good('The school garden orange trees are big.').
readings('I saw the garden orange tree.', 1).
readings('The orange tree is big.', 1).
bad('The garden orange trees is big.',     subject_verb(is)).
bad('The garden orange tree are big.',     subject_verb(are)).
% An adjective that is not a noun, after a noun modifier.
good('Alice has a garden happy dog.').
good('The school garden happy dog sleeps.').
readings('Alice has a garden happy dog.', 1).
bad('A garden happy dogs sleeps.',         det_noun(a, dogs)).
% A number in digits before the noun, after a determiner or a possessor.
good('The 2020 party was big.').
good('A 1968 picture is red.').
good('An 1800 picture is red.').
good('An 8 dog party is big.').
good('Alice\'s 2020 party was big.').
good('The dogs slept in the 2017 London party and 2019 London party.').
readings('The 2020 party was big.', 1).
readings('I saw 3 dogs.', 1).
bad('An 2020 picture is red.',              article(an, '2020')).
bad('The 2020 parties was big.',            subject_verb(was)).
bad('2020 party was big.',                  det_noun('2020', party)).
% A preposition of two words.
good('The dog slept because of the cat.').
good('As of the party, the dogs sleep.').
good('The dog sleeps close to the cat.').
readings('The dog slept because of the cat.', 1).
bad('The dog slept because of the cats sleep.', no_reading).
bad('The dog slept because the cat.',       no_reading).
% A name a comma sets after a noun phrase.
good('The doctor, Alice, sleeps.').
good('I saw the doctor, Alice.').
readings('I saw the doctor, Alice and Bob.', 1).
bad('The doctors, Alice, sleeps.',          subject_verb(sleeps)).
bad('The doctor, Alice sleeps.',            no_reading).
% The before a name.
good('The Hague is big.').
readings('The Hague is big.', 1).
% Nouns under one determiner, each with its own phrase.
good('Alice is the friend of Bob and teacher of the children.').
good('The dog of Alice and cat of Bob sleep.').
readings('Alice is the friend of Bob and teacher of the children.', 2).
% A comma before a prepositional phrase after the verb.
good('The dog sleeps, in the garden.').
readings('The dog sleeps, in the garden.', 1).
bad('The dog sleeps, the garden.',          no_reading).
% A relative clause a comma sets off.
good('The dog, which barks, sleeps.').
good('I saw the dogs, which bark.').
readings('The dog, which barks, sleeps.', 1).
bad('The dog, that barks, sleeps.',         no_reading).
bad('The dog, which barks sleeps.',         no_reading).
bad('The dogs, which barks, sleep.',        subject_verb(barks)).
% A participle phrase a comma sets off, after a name or a verb phrase.
good('Alice, known as the queen, sleeps.').
good('Alice, often known as the queen, sleeps.').
good('Alice is a doctor, often known as the friend of Bob.').
good('The dog was seen, chasing the cat.').
readings('Alice, often known as the queen, sleeps.', 1).
bad('Alice, known as the queen sleeps.',    no_reading).
bad('Alice, known as the queen, sleep.',    subject_verb(sleep)).
% Two prepositional phrases joined, with the same preposition.
good('The dog sleeps in the house and in the garden.').
readings('The dog sleeps in the house and in the garden.', 1).
bad('The dog sleeps in the house and on the box.', no_reading).
bad('A apple tree grows.',                  article(a, apple)).
bad('The dog house are big.',              subject_verb(are)).
bad('The dog barks?',                      punctuation('?')).
bad('Close the door?',                     punctuation('?')).
bad('Does the dog bark.',                  punctuation('.')).
bad('What did the dog chase.',             punctuation('.')).
bad('Is the dog happy!',                   punctuation('!')).
bad('"The dog barks?"',                    punctuation('?')).

readings('The old man walks in the park with his dog.', 2).
readings('The dogs chase a cat.', 1).
readings('I read a book.', 1).
readings('The dog has eaten.', 1).
readings('Is the dog sleeping?', 1).
readings('The cat that the dog chased sleeps.', 1).
readings('What did the dog chase?', 1).
readings('The dog in the garden that barks is old.', 2).
readings('Alice\'s friend\'s dog barks.', 1).
readings('The dog barks and the cat sleeps.', 1).
readings('The children played football after school.', 2).
readings('Close the door.', 1).
readings('Bread is good.', 1).
readings('I know the dog sleeps.', 1).
readings('The dog barks every night.', 1).
readings('The Old house is big.', 1).
readings('Alice saw Leroy Dogs.', 1).
% A number after a name may be part of it, so Bob 3 is a name as well as
% Bob and three dogs.
readings('Alice gave Bob 3 dogs.', 2).
% A rough number, and about six as a phrase before the subject.
readings('About six dogs barked.', 2).
readings('The dogs and cats sleep.', 2).
readings('Alice, Bob, and Carol sing.', 1).
readings('The dog is big, old and happy.', 1).
% Orange is an adjective and a noun, and before a noun it is read once.
readings('The orange box is big.', 1).

% splits(Text, Sentences): Text cuts into exactly these sentences.
splits('The dog barks. The cat sleeps.', ['The dog barks.', 'The cat sleeps.']).
splits('Does it bark?  It does!', ['Does it bark?', 'It does!']).
splits('The price was 3.5 pounds.', ['The price was 3.5 pounds.']).
splits('She said "It is ugly." Then she left.',
       ['She said "It is ugly."', 'Then she left.']).
splits('A Heading\n\nThe dog\nbarks.', ['A Heading', 'The dog barks.']).
splits('A line\nthat goes on.', ['A line that goes on.']).
splits('Mr. Smith met Dr. Jones.', ['Mr. Smith met Dr. Jones.']).
splits('It is (lit. The Fat One) big. It is far.',
       ['It is (lit. The Fat One) big.', 'It is far.']).
splits('She was the U.S. Representative.', ['She was the U.S. Representative.']).
splits('John F. Kennedy spoke.', ['John F. Kennedy spoke.']).
splits('It is in Vol. 3 of the set.', ['It is in Vol. 3 of the set.']).
splits('It is in Vol. #8 of the set.', ['It is in Vol. #8 of the set.']).
splits('It is No. 5 on the list.', ['It is No. 5 on the list.']).
splits('I said no. Then she left.', ['I said no.', 'Then she left.']).
splits('The dog barks. 3 cats sleep.', ['The dog barks.', '3 cats sleep.']).
splits('... 42. -- !', []).
splits('', []).

% verdict(+Text, -V): grammatical, unknown (a word outside the lexicon that
% its ending does not place), no_reading, or the first violation of the
% best relaxed reading.
verdict(Text, V) :-
    forget_faults,
    words(Text, Words, Names),
    end_mark(Text, Mark),
    unknown_words(Words, U),
    (   unplaced(U, Names, [_|_])
    ->  V = unknown
    ;   with_placements(U, Names, verdict_of(Words, Mark, V))
    ).

verdict_of(Words, Mark, V) :-
    marked_readings(Words, Mark, Out),
    (   Out = readings(_)
    ->  V = grammatical
    ;   Out = wrong_mark(V0)
    ->  V = V0
    ;   diagnosis(Words, [V0|_])
    ->  V = V0
    ;   V = no_reading
    ).

run :-
    findall(S, good(S), Good),
    findall(S-E, bad(S, E), Bad),
    findall(S-N, readings(S, N), Readings),
    findall(T-Ss, splits(T, Ss), Splits),
    check_good(Good, 0, F1),
    check_bad(Bad, F1, F2),
    check_readings(Readings, F2, F3),
    check_splits(Splits, F3, F),
    length(Good, G), length(Bad, D), length(Readings, R), length(Splits, P),
    Total is G + D + R + P,
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
    words(S, Words, Names),
    with_placements([], Names, all_readings(Words, Ts)),
    length(Ts, M),
    (   M =:= N -> F1 = F0
    ;   format("FAIL  readings: ~w  expected ~d, got ~d~n", [S, N, M]), F1 is F0 + 1
    ),
    check_readings(Ss, F1, F).

check_splits([], F, F).
check_splits([T-Ss|Ts], F0, F) :-
    text_sentences(T, Got),
    (   Got == Ss -> F1 = F0
    ;   format("FAIL  splits: ~q  expected ~q, got ~q~n", [T, Ss, Got]), F1 is F0 + 1
    ),
    check_splits(Ts, F1, F).
