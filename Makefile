# Ariadne Prolog -- a Prolog interpreter written in C.

CC      ?= cc
CFLAGS  ?= -std=c99 -O2 -Wall -Wextra
LDLIBS   = -lm
PREFIX  ?= /usr/local

SRCS = src/term.c src/parser.c src/write.c src/arith.c src/db.c \
       src/machine.c src/stream.c src/builtins.c src/consult.c \
       src/main.c
OBJS = $(SRCS:src/%.c=build/%.o) build/boot_pl.o
BIN  = bin/prolog

all: $(BIN)

$(BIN): $(OBJS)
	@mkdir -p bin
	$(CC) $(CFLAGS) -o $@ $(OBJS) $(LDLIBS)

# The bootstrap library is written in Prolog and compiled into the binary.
# Its C is generated into build/, so it finds prolog.h through -Isrc.
build/boot_pl.c: lib/boot.pl tools/pl2c.awk
	@mkdir -p build
	awk -f tools/pl2c.awk lib/boot.pl > $@

build/boot_pl.o: build/boot_pl.c
	$(CC) $(CFLAGS) -Isrc -c build/boot_pl.c -o $@

$(OBJS): src/prolog.h

build/%.o: src/%.c
	@mkdir -p build
	$(CC) $(CFLAGS) -c $< -o $@

# The regression suite; the command line's exit status, since a -g goal that
# fails or raises ends the run with 1 and the goals after it do not run; and
# two error messages, which only show on standard error.
test: $(BIN)
	$(BIN) -q tests/test.pl -g run_tests
	$(BIN) -q -g true
	! $(BIN) -q -g fail 2>/dev/null
	! $(BIN) -q -g "atom_length(_, _)" 2>/dev/null
	test -z "`$(BIN) -q -g fail -g 'write(ran)' 2>/dev/null`"
	$(BIN) -q -g "format('~w ~w', [a])" 2>&1 | grep -q 'format/2: not enough arguments'
	$(BIN) -q -g "consult(tests/load_self)" 2>&1 | grep -q 'Not enough resources: load_depth'

# Every test again, bare, with the collector running inside each one. The
# collector only runs when no choice point is live, and run_tests holds
# several around every test, so run_tests_bare runs each as Goal, ! with
# nothing around it. It stops at the first failure; then the verbose run names
# the test, as the last line before the failure. GC_ENV lets the collector in
# at every fourth inference, whatever the size of the heap.
GC_ENV = PROLOG_GC_THRESHOLD=1 PROLOG_GC_INTERVAL=4
BARE = $(GC_ENV) $(BIN) -q tests/test.pl -g run_tests_bare || \
	{ $(GC_ENV) $(BIN) -q tests/test.pl -g "run_tests_bare(verbose)" 2>&1 | tail -3; exit 1; }
test-gc: $(BIN)
	$(BARE)

# Terms nested a million deep through every walk, the reader and the writer,
# run at the top level so that the collector copies them; it fails unless a
# collection happened. The collector's ordinary threshold is enough: forced,
# it would copy million-deep terms thousands of times to no further purpose.
test-deep: $(BIN)
	$(BIN) -q tests/deep.pl -g "run, halt"

# The suite under the address and undefined behaviour sanitizers.
# -fno-sanitize-recover makes undefined behaviour abort rather than print and
# carry on, so a finding fails the run instead of scrolling past.
test-asan:
	$(MAKE) clean
	$(MAKE) CFLAGS="-std=c99 -O1 -g -fsanitize=address,undefined \
	                -fno-sanitize-recover=undefined -fno-omit-frame-pointer"
	$(BIN) -q tests/test.pl -g run_tests
	$(BARE)
	$(BIN) -q tests/deep.pl -g "run, halt"
	$(MAKE) clean

check: test test-gc test-deep

# The tutorial programs are what the published tutorial pages quote from, so
# loading each one and running a query out of its page keeps the two in step.
tutorials: $(BIN)
	$(BIN) -q tutorial/level1.pl -g "ancestor(esther,D), format('~w~n',[D])"
	$(BIN) -q tutorial/level2.pl -g "eldest_child(esther,C), format('~w~n',[C])"
	$(BIN) -q tutorial/level3.pl -g "parse_order(\"3 hammer, 2 rope\", L), order_total(L,T), format('~w~n',[T])"
	$(BIN) -q tutorial/level3.pl -g "fillable(C), format('~w~n',[C])"
	$(BIN) -q tutorial/level4.pl -g "load_orders('tutorial/orders.txt'), report, halt"
	$(BIN) -q tutorial/restock.pl

# The English grammar checker in english/: its own checks, then one sentence
# of each kind through check/1, as the README shows them.
english: $(BIN)
	$(BIN) -q english/tests.pl -g run
	$(BIN) -q english/check.pl -g "check('The dogs chase a cat.'), halt"
	$(BIN) -q english/check.pl -g "check('The dogs chases a cat.'), halt"

examples: $(BIN)
	$(BIN) -q examples/hanoi.pl -g "hanoi(3)"
	$(BIN) -q examples/queens.pl -g "queens(8,Qs), print_board(Qs)"
	$(BIN) -q examples/zebra.pl -g "zebra(_,W,Z), format('water: ~w, zebra: ~w~n',[W,Z])"
	$(BIN) -q examples/calc.pl -g "calc(\"2 + 3 * (4 - 1)\", X), format('~w~n',[X])"
	$(BIN) -q examples/family.pl -g "descendants(esther,D), format('~w~n',[D])"

# The documentation is generated; tools/docpage.py holds the shared shell.
doc: web/index.html web/tutorial-1.html web/tutorial-2.html \
     web/tutorial-3.html web/tutorial-4.html \
     web/reference.html web/internals.html \
     web/journal.html web/postmortem.html

web/index.html: tools/gen_index.py tools/docpage.py
	python3 tools/gen_index.py

web/tutorial-1.html: tools/gen_tutorial1.py tools/docpage.py tutorial/level1.pl
	python3 tools/gen_tutorial1.py

web/tutorial-2.html: tools/gen_tutorial2.py tools/docpage.py tutorial/level2.pl
	python3 tools/gen_tutorial2.py

web/tutorial-3.html: tools/gen_tutorial3.py tools/docpage.py tutorial/level3.pl
	python3 tools/gen_tutorial3.py

web/tutorial-4.html: tools/gen_tutorial4.py tools/docpage.py tutorial/level4.pl
	python3 tools/gen_tutorial4.py

web/reference.html: tools/gen_reference.py tools/docpage.py
	python3 tools/gen_reference.py

web/internals.html: tools/gen_internals.py tools/docpage.py
	python3 tools/gen_internals.py

# These two are rendered from the Markdown at the top of the tree, which stays
# the source of truth; tools/mdpage.py is the renderer.
web/journal.html: tools/gen_journal.py tools/mdpage.py tools/docpage.py docs/JOURNAL.md
	python3 tools/gen_journal.py

web/postmortem.html: tools/gen_postmortem.py tools/mdpage.py tools/docpage.py docs/POSTMORTEM.md
	python3 tools/gen_postmortem.py

install: $(BIN)
	install -d $(DESTDIR)$(PREFIX)/bin
	install -m 755 $(BIN) $(DESTDIR)$(PREFIX)/bin/prolog

clean:
	rm -rf bin build

.PHONY: all test test-gc test-deep test-asan check examples tutorials english doc install clean
