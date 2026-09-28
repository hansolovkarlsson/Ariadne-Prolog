/*  Loaded by tests/test.pl as consult(load_beside), a bare name that exists
    only here, so the suite can see that a file loads its neighbours from
    beside itself rather than from the directory the interpreter was started
    in. It loads one more the same way, so the nesting is checked too. */
:- consult(load_beside_2).
loaded_beside.
