/*  english/wordnet_check.pl -- the grammar checker with WordNet's words.

    Loads check.pl and english/wordnet.pl, which `make wordnet` generates
    from WordNet 3.1, so that a word missing from the lexicon is looked up
    there before it is guessed from its ending:

        bin/prolog -q english/wordnet_check.pl -g "check('The ship sailed.')"

    Without wordnet.pl the checker is the one check.pl is, and says so.
*/

:- consult(check).
:- catch(consult(wordnet), _,
         format(user_error, "wordnet.pl is missing: run make wordnet~n", [])).
