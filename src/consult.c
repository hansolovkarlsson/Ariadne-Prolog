/* consult.c -- loading programs and reporting uncaught errors. */
#include "prolog.h"

static int a_dcg_translate;

static void init_local(void)
{
    if (!a_dcg_translate) a_dcg_translate = intern("$dcg_translate");
}

/* ------------------------------------------------------------------ */
/* Error messages                                                     */
/* ------------------------------------------------------------------ */

static void wr(FILE *f, Term *t)
{
    write_to_stream(f, t, WR_QUOTED | WR_NUMBERVARS);
}

void print_error_term(FILE *f, Term *ball)
{
    Term *formal;

    ball = deref(ball);
    if (!(ball->tag == TAG_STR && FN(ball) == a_error && AR(ball) == 2)) {
        fprintf(f, "Unhandled exception: ");
        wr(f, ball);
        fprintf(f, "\n");
        return;
    }
    formal = deref(ARG(ball, 0));
    {
        /* The machine puts the predicate that raised the error in the
           context, as context(Name/Arity, _); the reader puts the place of
           an error that is not a syntax error there, as file(Name, Line). */
        Term *ctx = deref(ARG(ball, 1));
        if (ctx->tag == TAG_STR && AR(ctx) == 2 && !strcmp(atom_name(FN(ctx)), "context")) {
            /* context(Name/Arity, _): the predicate the program called. */
            Term *pi = deref(ARG(ctx, 0));
            if (pi->tag == TAG_STR && FN(pi) == a_slash && AR(pi) == 2) {
                Term *nm = deref(ARG(pi, 0)), *ar = deref(ARG(pi, 1));
                if (nm->tag == TAG_ATOM && ar->tag == TAG_INT)
                    fprintf(f, "%s/%lld: ", atom_name(AT(nm)), IV(ar));
            }
        }
        if (ctx->tag == TAG_STR && AR(ctx) == 2 && !strcmp(atom_name(FN(ctx)), "file")) {
            Term *name = deref(ARG(ctx, 0));
            if (name->tag == TAG_ATOM) fprintf(f, "%s:", atom_name(AT(name)));
            else { wr(f, name); fprintf(f, ":"); }
            wr(f, ARG(ctx, 1));
            fprintf(f, ": ");
        }
    }
    if (formal->tag == TAG_ATOM &&
        !strcmp(atom_name(AT(formal)), "instantiation_error")) {
        fprintf(f, "Arguments are not sufficiently instantiated\n");
        return;
    }
    if (formal->tag == TAG_STR) {
        const char *k = atom_name(FN(formal));
        if (!strcmp(k, "type_error") && AR(formal) == 2) {
            fprintf(f, "Type error: `");
            wr(f, ARG(formal, 0));
            fprintf(f, "' expected, found `");
            wr(f, ARG(formal, 1));
            fprintf(f, "'\n");
            return;
        }
        if (!strcmp(k, "domain_error") && AR(formal) == 2) {
            fprintf(f, "Domain error: `");
            wr(f, ARG(formal, 0));
            fprintf(f, "' expected, found `");
            wr(f, ARG(formal, 1));
            fprintf(f, "'\n");
            return;
        }
        if (!strcmp(k, "existence_error") && AR(formal) == 2) {
            fprintf(f, "Unknown ");
            wr(f, ARG(formal, 0));
            fprintf(f, ": ");
            wr(f, ARG(formal, 1));
            fprintf(f, "\n");
            return;
        }
        if (!strcmp(k, "evaluation_error") && AR(formal) == 1) {
            fprintf(f, "Arithmetic: evaluation error: `");
            wr(f, ARG(formal, 0));
            fprintf(f, "'\n");
            return;
        }
        if (!strcmp(k, "permission_error") && AR(formal) == 3) {
            fprintf(f, "No permission to ");
            wr(f, ARG(formal, 0));
            fprintf(f, " ");
            wr(f, ARG(formal, 1));
            fprintf(f, " `");
            wr(f, ARG(formal, 2));
            fprintf(f, "'\n");
            return;
        }
        if (!strcmp(k, "representation_error") && AR(formal) == 1) {
            fprintf(f, "Cannot represent due to `");
            wr(f, ARG(formal, 0));
            fprintf(f, "'\n");
            return;
        }
        if (!strcmp(k, "format") && AR(formal) == 1) {
            /* format/2,3 give the problem as text, as SWI-Prolog does. */
            Term *m = deref(ARG(formal, 0));
            if (m->tag == TAG_ATOM) fprintf(f, "%s\n", atom_name(AT(m)));
            else { wr(f, m); fprintf(f, "\n"); }
            return;
        }
        if (!strcmp(k, "resource_error") && AR(formal) == 1) {
            fprintf(f, "Not enough resources: ");
            wr(f, ARG(formal, 0));
            fprintf(f, "\n");
            return;
        }
        if (!strcmp(k, "syntax_error") && AR(formal) == 1) {
            Term *m = deref(ARG(formal, 0));
            if (m->tag == TAG_ATOM) fprintf(f, "Syntax error: %s\n", atom_name(AT(m)));
            else { fprintf(f, "Syntax error: "); wr(f, m); fprintf(f, "\n"); }
            return;
        }
    }
    fprintf(f, "Unhandled exception: ");
    wr(f, ball);
    fprintf(f, "\n");
}

static void print_current_error(void)
{
    Term **vars;
    Term *ball;
    int i;

    if (!m_ball) { fprintf(stderr, "Unknown error\n"); return; }
    vars = (Term **)heap_alloc((m_ball_nvars + 1) * sizeof(Term *));
    for (i = 0; i < m_ball_nvars; i++) vars[i] = NULL;
    ball = heap_instantiate(m_ball, vars, m_ball_nvars);
    fprintf(stderr, "ERROR: ");
    print_error_term(stderr, ball);
}

/* ------------------------------------------------------------------ */
/* Loading clauses                                                    */
/* ------------------------------------------------------------------ */

int run_directive(Term *goal)
{
    int rc = solve_once(goal);
    if (rc == PL_ERROR) {
        print_current_error();
        return PL_OK;
    }
    if (rc == PL_FAIL) {
        fprintf(stderr, "Warning: Goal (directive) failed: ");
        write_to_stream(stderr, goal, WR_QUOTED);
        fprintf(stderr, "\n");
        return PL_OK;
    }
    return rc;
}

/* The file being loaded now, as an interned name, and a number that is
   new for every load, so that loading a file a second time can be told
   from going on with the first. */
static const char *cur_source;
static int cur_load, nloads;

/* A predicate belongs to the file that first gave it clauses. When a file
   is loaded again, its predicates start empty, so their clauses are
   replaced rather than added to; when another file gives clauses to one,
   that file takes it over, with a warning, as SWI-Prolog does. A library
   predicate is taken over without one, so that a program may define its
   own member/2. A predicate declared multifile collects clauses from
   every file. Clauses added outside a file, by boot or by assert, are
   kept. */
static void claim(Pred *p)
{
    if (!cur_source) return;
    if (p->multifile) {
        if (!p->source) { p->source = cur_source; p->load = cur_load; }
        return;
    }
    if (p->source == cur_source) {
        if (p->load != cur_load) { pred_abolish(p); p->load = cur_load; }
        return;
    }
    if (p->source) {
        fprintf(stderr, "Warning: %s: redefined %s/%d, which was defined in %s\n",
                cur_source, atom_name(p->functor), p->arity, p->source);
        pred_abolish(p);
    } else if (p->library) {
        pred_abolish(p);
        p->library = 0;
    }
    p->source = cur_source;
    p->load = cur_load;
}

static int add_clause(Term *t)
{
    Term *head, *body;
    Pred *p;
    int f, n;

    t = deref(t);
    if (t->tag == TAG_STR && FN(t) == a_neck && AR(t) == 2) {
        head = deref(ARG(t, 0));
        body = deref(ARG(t, 1));
    } else {
        head = t;
        body = mk_atom(a_true);
    }
    if (head->tag == TAG_VAR) { instantiation_error(); return PL_ERROR; }
    if (!IS_CALLABLE(head)) { type_error("callable", head); return PL_ERROR; }
    if (head->tag == TAG_ATOM) { f = AT(head); n = 0; }
    else { f = FN(head); n = AR(head); }
    if (builtin_exists(f, n)) {
        permission_error("modify", "static_procedure",
                         mk2(a_slash, mk_atom(f), mk_int(n)));
        return PL_ERROR;
    }
    p = pred_lookup(f, n, 1);
    claim(p);
    pred_add_clause(p, clause_make(head, body), 1);
    return PL_OK;
}

int consult_reader(Reader *r)
{
    init_local();
    for (;;) {
        HeapMark hm = heap_mark();
        size_t tm = trail_mark();
        Term *t, *names;
        int rc = read_term_from(r, &t, &names);

        if (rc == 0) { heap_release(hm); break; }         /* end of file */
        if (rc < 0) {                                     /* syntax error */
            print_current_error();
            trail_undo(tm);
            heap_release(hm);
            continue;
        }
        t = deref(t);
        if (t->tag == TAG_STR && AR(t) == 1 &&
            (FN(t) == a_neck || FN(t) == intern("?-"))) {
            rc = run_directive(deref(ARG(t, 0)));
            if (rc == PL_HALT) { trail_undo(tm); heap_release(hm); return PL_HALT; }
        } else if (t->tag == TAG_STR && FN(t) == a_dcg && AR(t) == 2) {
            Term *out = mk_var();
            Term *goal = mk2(a_dcg_translate, t, out);
            int roots = gc_root_top();
            gc_protect(&out);
            rc = solve_once(goal);
            gc_unprotect(roots);
            if (rc == PL_ERROR) print_current_error();
            else if (rc == PL_FAIL)
                fprintf(stderr, "Warning: cannot translate grammar rule\n");
            else if (add_clause(out) != PL_OK) print_current_error();
        } else {
            if (add_clause(t) != PL_OK) print_current_error();
        }
        trail_undo(tm);
        heap_release(hm);
        if (m_halt) return PL_HALT;
    }
    return PL_OK;
}

/* The files being loaded now, innermost last, so that a relative path in
   one of them can be found beside it. */
#define MAX_LOAD_DEPTH 64
static char *loading[MAX_LOAD_DEPTH];
static int nloading;

/* Opens path, or path with .pl added, into buf; NULL if neither exists. */
static FILE *open_source(const char *path, char *buf, size_t n)
{
    FILE *f;
    snprintf(buf, n, "%s", path);
    if ((f = fopen(buf, "r")) != NULL) return f;
    snprintf(buf, n, "%s.pl", path);   /* the conventional extension */
    return fopen(buf, "r");
}

/* Rewrites a path in place without its . segments, doubled slashes, or a
   name followed by .., so that one file reached by two spellings of its
   path, tests/reload.pl and ./tests/../tests/reload.pl, is known as one:
   a predicate belongs to the file that defined it, and two names would
   make a reload look like another file redefining it. A .. that has no
   name before it stays. The spelling is all C99 gives: a symbolic link, or
   an absolute path against a relative one, needs realpath(), which is
   POSIX. */
static void normalize_path(char *path)
{
    char *seg[512];
    size_t len[512];
    int n = 0, i, absolute = path[0] == '/';
    char *p = path, *out;

    while (*p) {
        char *start;
        while (*p == '/') p++;
        if (!*p) break;
        start = p;
        while (*p && *p != '/') p++;
        if (p - start == 1 && start[0] == '.') continue;
        if (p - start == 2 && start[0] == '.' && start[1] == '.' && n > 0 &&
            !(len[n - 1] == 2 && seg[n - 1][0] == '.' && seg[n - 1][1] == '.')) {
            n--;
            continue;
        }
        if (p - start == 2 && start[0] == '.' && start[1] == '.' && absolute)
            continue;                           /* /.. is / */
        if (n == 512) return;                   /* leave it as it was */
        seg[n] = start;
        len[n++] = (size_t)(p - start);
    }
    out = path;
    if (absolute) *out++ = '/';
    for (i = 0; i < n; i++) {
        if (i > 0) *out++ = '/';
        memmove(out, seg[i], len[i]);
        out += len[i];
    }
    if (out == path) *out++ = '.';
    *out = '\0';
}

/* Loads a file. A relative path met while another file is loading is
   looked for in that file's directory first, as SWI-Prolog does, so that a
   program split into files loads from wherever it is run; then in the
   current directory, as it always was here, so that paths written for that
   still work. */
int consult_file(const char *path)
{
    FILE *f = NULL;
    Reader r;
    int rc, outer_load;
    const char *outer_source;
    char found[1024];

    if (path[0] != '/' && nloading > 0) {
        const char *outer = loading[nloading - 1], *slash = strrchr(outer, '/');
        if (slash) {
            char joined[1024];
            snprintf(joined, sizeof(joined), "%.*s/%s", (int)(slash - outer), outer, path);
            f = open_source(joined, found, sizeof(found));
        }
    }
    if (!f) f = open_source(path, found, sizeof(found));
    if (!f) return PL_FAIL;
    if (nloading == MAX_LOAD_DEPTH) {       /* a file that loads itself, say */
        fclose(f);
        return pl_throw(mk1(intern("resource_error"), mk_atom_str("load_depth")));
    }
    normalize_path(found);
    loading[nloading++] = pl_strdup(found);
    outer_source = cur_source;
    outer_load = cur_load;
    cur_source = atom_name(intern(found));
    cur_load = ++nloads;
    reader_init_file(&r, f, loading[nloading - 1]);
    rc = consult_reader(&r);
    fclose(f);
    free(loading[--nloading]);
    cur_source = outer_source;
    cur_load = outer_load;
    return rc;
}

int consult_string(const char *s)
{
    Reader r;
    reader_init_string(&r, s, strlen(s));
    r.name = "boot";
    return consult_reader(&r);
}
