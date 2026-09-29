/*  Loaded with tests/redefine_2.pl by make test, to check what happens when
    two files give clauses to one predicate. redef/1 is defined in both, so
    the second takes it over with a warning; mf/1 is declared multifile in
    both, so it collects the clauses of each, without one. */
:- multifile(mf/1).
redef(a).
mf(a).
