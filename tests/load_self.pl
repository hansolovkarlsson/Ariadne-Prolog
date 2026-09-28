/*  Loads itself, so the loader must stop it; see the Makefile test target. */
:- consult(load_self).
