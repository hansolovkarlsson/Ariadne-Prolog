/*  Loaded by make test to check that a program's own definition of a
    library predicate replaces the library's, rather than being added to
    its clauses: member(X, [a,b]) must give only x. */
member(x, _).
