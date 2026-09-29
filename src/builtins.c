/* builtins.c -- the builtin predicates. */
#include "prolog.h"
#include <ctype.h>
#include <math.h>
#include <time.h>

#define BI(name) static int name(Term **A, Goal *cont, size_t cutb)
#define UNUSED   (void)A; (void)cont; (void)cutb;
#define RET(x)   return (x) ? PL_OK : PL_FAIL

/* ------------------------------------------------------------------ */
/* Text helpers                                                       */
/* ------------------------------------------------------------------ */

/* Converts an atom, number, code list or char list into malloc'd text.
   Returns 1 on success. */
int text_of(Term *t, char **out, size_t *len)
{
    t = deref(t);
    switch (t->tag) {
    case TAG_ATOM: {
        size_t n = atom_len(AT(t));
        char *s = (char *)malloc(n + 1);
        memcpy(s, atom_name(AT(t)), n + 1);
        *out = s;
        if (len) *len = n;
        return 1;
    }
    case TAG_INT: case TAG_FLT: {
        char buf[64];
        if (t->tag == TAG_INT) snprintf(buf, sizeof(buf), "%lld", IV(t));
        else format_float(buf, sizeof(buf), FV(t));
        *out = pl_strdup(buf);
        if (len) *len = strlen(buf);
        return 1;
    }
    case TAG_STR: {
        size_t cap = 64, n = 0;
        char *s = (char *)malloc(cap);
        Term *l = t;
        while (l->tag == TAG_STR && FN(l) == a_dot && AR(l) == 2) {
            Term *h = deref(ARG(l, 0));
            int c;
            if (h->tag == TAG_INT) c = (int)IV(h);   /* a character code */
            else if (h->tag == TAG_ATOM && atom_len(AT(h)) >= 1)
                { const char *nm = atom_name(AT(h));
                  size_t ln = atom_len(AT(h));
                  if (n + ln + 1 > cap) { while (n + ln + 1 > cap) cap *= 2;
                                          s = (char *)realloc(s, cap); }
                  memcpy(s + n, nm, ln); n += ln;
                  l = deref(ARG(l, 1)); continue; }
            else { free(s); return 0; }
            if (n + 8 > cap) { cap *= 2; s = (char *)realloc(s, cap); }
            n += utf8_encode(c, s + n);
            l = deref(ARG(l, 1));
        }
        if (!(l->tag == TAG_ATOM && AT(l) == a_nil)) { free(s); return 0; }
        s[n] = 0;
        *out = s;
        if (len) *len = n;
        return 1;
    }
    default:
        return 0;
    }
}

/* Parses text as a Prolog number.  Returns NULL if it is not one. */
Term *parse_number_str(const char *s, size_t n)
{
    Reader r;
    Term *t = NULL, *names;
    char *buf = (char *)malloc(n + 3);
    size_t base;
    int rc;

    memcpy(buf, s, n);
    buf[n] = ' ';
    buf[n + 1] = '.';
    buf[n + 2] = 0;
    reader_init_string(&r, buf, n + 2);
    r.name = "number";
    base = m_cp_top;
    (void)base;
    rc = read_term_from(&r, &t, &names);
    free(buf);
    if (rc != 1) { m_ball = NULL; return NULL; }
    t = deref(t);
    if (IS_NUM(t)) return t;
    /* Accept a leading sign: -(1) reads as a compound term. */
    if (t->tag == TAG_STR && AR(t) == 1 && (FN(t) == a_minus || FN(t) == a_plus)) {
        Term *a = deref(ARG(t, 0));
        if (IS_NUM(a)) {
            if (FN(t) == a_plus) return a;
            return a->tag == TAG_INT ? mk_int(-IV(a)) : mk_float(-FV(a));
        }
    }
    return NULL;
}

static int get_atom(Term *t, int *a)
{
    *a = 0;                 /* always written, so callers need no initialiser */
    t = deref(t);
    if (t->tag == TAG_VAR) return instantiation_error();
    if (t->tag != TAG_ATOM) return type_error("atom", t);
    *a = AT(t);
    return PL_OK;
}

static int get_int(Term *t, long long *v)
{
    *v = 0;
    t = deref(t);
    if (t->tag == TAG_VAR) return instantiation_error();
    if (t->tag != TAG_INT) return type_error("integer", t);
    *v = IV(t);
    return PL_OK;
}

static int get_text(Term *t, char **s, size_t *n, const char *type)
{
    Term *d = deref(t);
    *s = NULL;
    if (n) *n = 0;
    if (d->tag == TAG_VAR) return instantiation_error();
    if (!text_of(d, s, n)) return type_error(type, d);
    return PL_OK;
}

/* ------------------------------------------------------------------ */
/* Type checking                                                      */
/* ------------------------------------------------------------------ */

BI(bi_var)      { UNUSED; RET(deref(A[0])->tag == TAG_VAR); }
BI(bi_nonvar)   { UNUSED; RET(deref(A[0])->tag != TAG_VAR); }
BI(bi_atom)     { UNUSED; RET(deref(A[0])->tag == TAG_ATOM); }
BI(bi_number)   { UNUSED; RET(IS_NUM(deref(A[0]))); }
BI(bi_integer)  { UNUSED; RET(deref(A[0])->tag == TAG_INT); }
BI(bi_float)    { UNUSED; RET(deref(A[0])->tag == TAG_FLT); }
BI(bi_compound) { UNUSED; RET(deref(A[0])->tag == TAG_STR); }
BI(bi_callable) { UNUSED; RET(IS_CALLABLE(deref(A[0]))); }
BI(bi_atomic)   { UNUSED; Term *t = deref(A[0]);
                  RET(t->tag == TAG_ATOM || IS_NUM(t)); }
BI(bi_is_list)  { UNUSED; RET(list_length(A[0]) >= 0); }

/* This walk and the ones below keep their pending arguments on a
   WorkStack, as unify does, so a term nested deep in any argument costs
   no C stack. */
static int is_ground(Term *t)
{
    static WorkStack ws;
    size_t base = ws.n;
    int i;

    for (;;) {
        t = deref(t);
        if (t->tag == TAG_VAR) { ws.n = base; return 0; }
        if (t->tag == TAG_STR && AR(t) > 0) {
            for (i = AR(t) - 1; i > 0; i--) WS_PUSH(&ws, ARG(t, i));
            t = ARG(t, 0);
            continue;
        }
        if (ws.n == base) return 1;
        t = (Term *)WS_POP(&ws);
    }
}

BI(bi_ground) { UNUSED; RET(is_ground(A[0])); }

/* ------------------------------------------------------------------ */
/* Unification and comparison                                         */
/* ------------------------------------------------------------------ */

BI(bi_unify) { UNUSED; RET(unify(A[0], A[1])); }

BI(bi_not_unify)
{
    UNUSED;
    size_t tm = trail_mark();
    int ok = unify(A[0], A[1]);
    trail_undo(tm);
    RET(!ok);
}

static int occurs_in(Term *v, Term *t)
{
    static WorkStack ws;
    size_t base = ws.n;
    int i;

    for (;;) {
        t = deref(t);
        if (t == v) { ws.n = base; return 1; }
        if (t->tag == TAG_STR && AR(t) > 0) {
            for (i = AR(t) - 1; i > 0; i--) WS_PUSH(&ws, ARG(t, i));
            t = ARG(t, 0);
            continue;
        }
        if (ws.n == base) return 0;
        t = (Term *)WS_POP(&ws);
    }
}

static int unify_oc(Term *a, Term *b)
{
    static WorkStack ws;
    size_t base = ws.n;
    int i;

    for (;;) {
        a = deref(a);
        b = deref(b);
        if (a == b) goto next;
        if (b->tag == TAG_VAR && a->tag != TAG_VAR) { Term *x = a; a = b; b = x; }
        if (a->tag == TAG_VAR) {
            if (occurs_in(a, b)) goto fail;
            bind(a, b);
            goto next;
        }
        if (a->tag != b->tag) goto fail;
        switch (a->tag) {
        case TAG_ATOM: if (AT(a) != AT(b)) goto fail; goto next;
        case TAG_INT:  if (IV(a) != IV(b)) goto fail; goto next;
        case TAG_FLT:  if (FV(a) != FV(b)) goto fail; goto next;
        }
        if (FN(a) != FN(b) || AR(a) != AR(b)) goto fail;
        if (AR(a) == 0) goto next;
        for (i = AR(a) - 1; i > 0; i--) {
            WS_PUSH(&ws, ARG(a, i));
            WS_PUSH(&ws, ARG(b, i));
        }
        a = ARG(a, 0);
        b = ARG(b, 0);
        continue;
    next:
        if (ws.n == base) return 1;
        b = (Term *)WS_POP(&ws);
        a = (Term *)WS_POP(&ws);
    }
fail:
    ws.n = base;
    return 0;
}

BI(bi_unify_oc)
{
    UNUSED;
    size_t tm = trail_mark();
    if (unify_oc(A[0], A[1])) return PL_OK;
    trail_undo(tm);
    return PL_FAIL;
}

/* Structural equivalence: the terms are the same up to variable renaming.
   The renaming is kept both ways, as two variable maps. */
static int variant_rec(Term *a, Term *b, VarMap *lr, VarMap *rl)
{
    static WorkStack ws;
    size_t base = ws.n;
    int i;

    for (;;) {
        a = deref(a);
        b = deref(b);
        if (a->tag == TAG_VAR || b->tag == TAG_VAR) {
            Term *seen;
            if (a->tag != TAG_VAR || b->tag != TAG_VAR) goto fail;
            if ((seen = varmap_get(lr, a)) != NULL) {
                if (seen != b) goto fail;
                goto next;
            }
            if (varmap_get(rl, b)) goto fail;
            varmap_put(lr, a, b);
            varmap_put(rl, b, a);
            goto next;
        }
        if (a->tag != b->tag) goto fail;
        switch (a->tag) {
        case TAG_ATOM: if (AT(a) != AT(b)) goto fail; goto next;
        case TAG_INT:  if (IV(a) != IV(b)) goto fail; goto next;
        case TAG_FLT:  if (FV(a) != FV(b)) goto fail; goto next;
        }
        if (FN(a) != FN(b) || AR(a) != AR(b)) goto fail;
        if (AR(a) == 0) goto next;
        for (i = AR(a) - 1; i > 0; i--) {
            WS_PUSH(&ws, ARG(a, i));
            WS_PUSH(&ws, ARG(b, i));
        }
        a = ARG(a, 0);
        b = ARG(b, 0);
        continue;
    next:
        if (ws.n == base) return 1;
        b = (Term *)WS_POP(&ws);
        a = (Term *)WS_POP(&ws);
    }
fail:
    ws.n = base;
    return 0;
}

static int is_variant(Term *a, Term *b)
{
    VarMap lr = VARMAP_INIT, rl = VARMAP_INIT;
    int ok = variant_rec(a, b, &lr, &rl);
    varmap_free(&lr);
    varmap_free(&rl);
    return ok;
}

BI(bi_variant)     { UNUSED; RET(is_variant(A[0], A[1])); }
BI(bi_not_variant) { UNUSED; RET(!is_variant(A[0], A[1])); }

BI(bi_eq)     { UNUSED; RET(compare_terms(A[0], A[1]) == 0); }
BI(bi_neq)    { UNUSED; RET(compare_terms(A[0], A[1]) != 0); }
BI(bi_lt)     { UNUSED; RET(compare_terms(A[0], A[1]) < 0); }
BI(bi_gt)     { UNUSED; RET(compare_terms(A[0], A[1]) > 0); }
BI(bi_le)     { UNUSED; RET(compare_terms(A[0], A[1]) <= 0); }
BI(bi_ge)     { UNUSED; RET(compare_terms(A[0], A[1]) >= 0); }

BI(bi_compare)
{
    UNUSED;
    int c = compare_terms(A[1], A[2]);
    Term *o = deref(A[0]);
    const char *s = c < 0 ? "<" : c > 0 ? ">" : "=";
    if (o->tag != TAG_VAR) {
        if (o->tag != TAG_ATOM) return type_error("atom", o);
        if (strcmp(atom_name(AT(o)), "<") && strcmp(atom_name(AT(o)), ">") &&
            strcmp(atom_name(AT(o)), "="))
            return domain_error("order", o);
    }
    RET(unify(A[0], mk_atom_str(s)));
}

/* ------------------------------------------------------------------ */
/* Arithmetic                                                         */
/* ------------------------------------------------------------------ */

BI(bi_is)
{
    UNUSED;
    Term *r;
    if (arith_eval(A[1], &r) != PL_OK) return PL_ERROR;
    RET(unify(A[0], r));
}

static int arith_cmp_bi(Term **A, int lo, int hi)
{
    int c;
    if (arith_compare(A[0], A[1], &c) != PL_OK) return PL_ERROR;
    return (c >= lo && c <= hi) ? PL_OK : PL_FAIL;
}

BI(bi_num_eq) { UNUSED; return arith_cmp_bi(A, 0, 0); }
BI(bi_num_ne)
{
    UNUSED;
    int c;
    if (arith_compare(A[0], A[1], &c) != PL_OK) return PL_ERROR;
    RET(c != 0);
}
BI(bi_num_lt) { UNUSED; return arith_cmp_bi(A, -1, -1); }
BI(bi_num_gt) { UNUSED; return arith_cmp_bi(A, 1, 1); }
BI(bi_num_le) { UNUSED; return arith_cmp_bi(A, -1, 0); }
BI(bi_num_ge) { UNUSED; return arith_cmp_bi(A, 0, 1); }

BI(bi_succ)
{
    UNUSED;
    Term *a = deref(A[0]), *b = deref(A[1]);
    if (a->tag == TAG_INT) {
        if (IV(a) < 0) return type_error("not_less_than_zero", a);
        RET(unify(A[1], mk_int(IV(a) + 1)));
    }
    if (b->tag == TAG_INT) {
        if (IV(b) <= 0) {
            if (IV(b) < 0) return type_error("not_less_than_zero", b);
            return PL_FAIL;
        }
        RET(unify(A[0], mk_int(IV(b) - 1)));
    }
    if (a->tag == TAG_VAR && b->tag == TAG_VAR) return instantiation_error();
    return type_error("integer", a->tag == TAG_INT ? b : a);
}

/* between(+Low, +High, ?X) -- one choice point, retried in place, so that a
   failure-driven loop over it does not grow the heap. */
BI(bi_between)
{
    Term *low = deref(A[0]), *high = deref(A[1]), *x = deref(A[2]);
    long long lo, hi;

    if (low->tag == TAG_VAR || high->tag == TAG_VAR) return instantiation_error();
    if (low->tag != TAG_INT) return type_error("integer", low);
    if (high->tag == TAG_INT)
        hi = IV(high);
    else if (high->tag == TAG_ATOM && (!strcmp(atom_name(AT(high)), "inf") ||
                                       !strcmp(atom_name(AT(high)), "infinite")))
        hi = LLONG_MAX;
    else
        return type_error("integer", high);
    lo = IV(low);

    if (x->tag == TAG_INT) return (IV(x) >= lo && IV(x) <= hi) ? PL_OK : PL_FAIL;
    if (x->tag != TAG_VAR) return type_error("integer", x);
    if (lo > hi) return PL_FAIL;
    if (lo < hi) redo_push(REDO_BETWEEN, lo + 1, hi, x, cont, cutb);
    RET(unify(A[2], mk_int(lo)));
}

/* repeat -- succeeds endlessly, from a single choice point. */
BI(bi_repeat)
{
    (void)A;
    redo_push(REDO_REPEAT, 0, 0, NULL, cont, cutb);
    return PL_OK;
}

BI(bi_plus)
{
    UNUSED;
    Term *a = deref(A[0]), *b = deref(A[1]), *c = deref(A[2]);
    if (a->tag == TAG_INT && b->tag == TAG_INT) RET(unify(A[2], mk_int(IV(a) + IV(b))));
    if (a->tag == TAG_INT && c->tag == TAG_INT) RET(unify(A[1], mk_int(IV(c) - IV(a))));
    if (b->tag == TAG_INT && c->tag == TAG_INT) RET(unify(A[0], mk_int(IV(c) - IV(b))));
    return instantiation_error();
}

/* ------------------------------------------------------------------ */
/* Term construction and inspection                                   */
/* ------------------------------------------------------------------ */

BI(bi_functor)
{
    UNUSED;
    Term *t = deref(A[0]);
    if (t->tag != TAG_VAR) {
        Term *nm, *ar;
        if (t->tag == TAG_STR) { nm = mk_atom(FN(t)); ar = mk_int(AR(t)); }
        else { nm = t; ar = mk_int(0); }
        RET(unify(A[1], nm) && unify(A[2], ar));
    } else {
        Term *nm = deref(A[1]), *ar = deref(A[2]);
        long long n;
        int i;
        if (nm->tag == TAG_VAR || ar->tag == TAG_VAR) return instantiation_error();
        if (ar->tag != TAG_INT) return type_error("integer", ar);
        n = IV(ar);
        if (n < 0) return domain_error("not_less_than_zero", ar);
        if (n > MAX_ARITY) return representation_error("max_arity");
        if (n == 0) RET(unify(A[0], nm));
        if (nm->tag != TAG_ATOM) {
            if (IS_NUM(nm)) return type_error("atomic", nm);
            return type_error("atomic", nm);
        }
        {
            Term *s = mk_str(AT(nm), (int)n);
            for (i = 0; i < n; i++) ARG(s, i) = mk_var();
            RET(unify(A[0], s));
        }
    }
}

BI(bi_arg)
{
    UNUSED;
    Term *n = deref(A[0]), *t = deref(A[1]);
    if (t->tag == TAG_VAR) return instantiation_error();
    if (t->tag != TAG_STR) return type_error("compound", t);
    if (n->tag == TAG_VAR) {
        /* arg(N, T, A) with N unbound is handled in the library. */
        return instantiation_error();
    }
    if (n->tag != TAG_INT) return type_error("integer", n);
    if (IV(n) < 1 || IV(n) > AR(t)) return PL_FAIL;
    RET(unify(A[2], ARG(t, (int)IV(n) - 1)));
}

BI(bi_univ)
{
    UNUSED;
    Term *t = deref(A[0]);
    if (t->tag != TAG_VAR) {
        Term *list;
        int i;
        if (t->tag == TAG_STR) {
            list = mk_atom(a_nil);
            for (i = AR(t) - 1; i >= 0; i--) list = mk_cons(ARG(t, i), list);
            list = mk_cons(mk_atom(FN(t)), list);
        } else {
            list = mk_cons(t, mk_atom(a_nil));
        }
        RET(unify(A[1], list));
    } else {
        Term *l = deref(A[1]), *head;
        Term *items[MAX_ARITY + 1];    /* the name, then its arguments */
        int n = 0;
        if (l->tag == TAG_VAR) return instantiation_error();
        while (l->tag == TAG_STR && FN(l) == a_dot && AR(l) == 2) {
            if (n > MAX_ARITY) return representation_error("max_arity");
            items[n++] = deref(ARG(l, 0));
            l = deref(ARG(l, 1));
        }
        if (l->tag == TAG_VAR) return instantiation_error();
        if (!(l->tag == TAG_ATOM && AT(l) == a_nil)) return type_error("list", A[1]);
        if (n == 0) return domain_error("non_empty_list", A[1]);
        head = items[0];
        if (n == 1) RET(unify(A[0], head));
        if (head->tag == TAG_VAR) return instantiation_error();
        if (head->tag != TAG_ATOM) return type_error("atom", head);
        {
            Term *s = mk_str(AT(head), n - 1);
            int i;
            for (i = 1; i < n; i++) ARG(s, i - 1) = items[i];
            RET(unify(A[0], s));
        }
    }
}

BI(bi_copy_term) { UNUSED; RET(unify(A[1], heap_copy(A[0]))); }

BI(bi_term_variables)
{
    UNUSED;
    int n, ok;
    Term **vars = term_variables(A[0], &n);
    ok = unify(A[1], list_from_array(vars, n));
    free(vars);
    RET(ok);
}

static long long numbervars_walk(Term *t, long long n)
{
    static WorkStack ws;
    size_t base = ws.n;
    int i;

    for (;;) {
        t = deref(t);
        if (t->tag == TAG_VAR) bind(t, mk1(a_dollar_var, mk_int(n++)));
        else if (t->tag == TAG_STR && AR(t) > 0) {
            /* Left to right, so the numbers follow the order of reading. */
            for (i = AR(t) - 1; i > 0; i--) WS_PUSH(&ws, ARG(t, i));
            t = ARG(t, 0);
            continue;
        }
        if (ws.n == base) return n;
        t = (Term *)WS_POP(&ws);
    }
}

BI(bi_numbervars)
{
    UNUSED;
    long long start;
    if (get_int(A[1], &start) != PL_OK) return PL_ERROR;
    RET(unify(A[2], mk_int(numbervars_walk(A[0], start))));
}

BI(bi_setarg)
{
    UNUSED;
    Term *n = deref(A[0]), *t = deref(A[1]);
    long long i;
    if (n->tag != TAG_INT) return type_error("integer", n);
    if (t->tag != TAG_STR) return type_error("compound", t);
    i = IV(n);
    if (i < 1 || i > AR(t)) return PL_FAIL;
    /* Backtrackable assignment through a fresh variable cell. */
    {
        Term *cell = mk_var();
        bind(cell, deref(A[2]));
        ARG(t, (int)i - 1) = cell;
    }
    return PL_OK;
}

/* ------------------------------------------------------------------ */
/* Atoms and text                                                     */
/* ------------------------------------------------------------------ */

/* Counts UTF-8 characters. */
static size_t utf8_len(const char *s, size_t n)
{
    size_t i, k = 0;
    for (i = 0; i < n; i++) if (((unsigned char)s[i] & 0xC0) != 0x80) k++;
    return k;
}

static size_t utf8_offset(const char *s, size_t n, size_t chars)
{
    size_t i = 0, k = 0;
    while (i < n && k < chars) {
        i++;
        while (i < n && ((unsigned char)s[i] & 0xC0) == 0x80) i++;
        k++;
    }
    return i;
}

BI(bi_atom_length)
{
    UNUSED;
    char *s;
    size_t n;
    int rc = get_text(A[0], &s, &n, "atom");
    if (rc != PL_OK) return rc;
    {
        Term *l = deref(A[1]);
        int ok;
        if (l->tag != TAG_VAR && l->tag != TAG_INT) { free(s); return type_error("integer", l); }
        if (l->tag == TAG_INT && IV(l) < 0) { free(s); return domain_error("not_less_than_zero", l); }
        ok = unify(A[1], mk_int((long long)utf8_len(s, n)));
        free(s);
        RET(ok);
    }
}

BI(bi_atom_codes)
{
    UNUSED;
    Term *a = deref(A[0]);
    if (a->tag != TAG_VAR) {
        char *s;
        size_t n;
        int ok;
        if (!text_of(a, &s, &n)) return type_error("atom", a);
        ok = unify(A[1], mk_codes(s, n));
        free(s);
        RET(ok);
    } else {
        char *s;
        size_t n;
        int rc = get_text(A[1], &s, &n, "list");
        int ok;
        if (rc != PL_OK) return rc;
        ok = unify(A[0], mk_atom(intern_n(s, n)));
        free(s);
        RET(ok);
    }
}

BI(bi_atom_chars)
{
    UNUSED;
    Term *a = deref(A[0]);
    if (a->tag != TAG_VAR) {
        char *s;
        size_t n;
        int ok;
        if (!text_of(a, &s, &n)) return type_error("atom", a);
        ok = unify(A[1], mk_chars(s, n));
        free(s);
        RET(ok);
    } else {
        char *s;
        size_t n;
        int rc = get_text(A[1], &s, &n, "list");
        int ok;
        if (rc != PL_OK) return rc;
        ok = unify(A[0], mk_atom(intern_n(s, n)));
        free(s);
        RET(ok);
    }
}

BI(bi_char_code)
{
    UNUSED;
    Term *c = deref(A[0]), *n = deref(A[1]);
    if (c->tag == TAG_ATOM) {
        const char *s = atom_name(AT(c));
        size_t len = atom_len(AT(c));
        long code;
        unsigned char b0 = (unsigned char)s[0];
        if (utf8_len(s, len) != 1) return type_error("character", c);
        if (b0 < 0x80) code = b0;
        else {
            int extra = b0 >= 0xF0 ? 3 : b0 >= 0xE0 ? 2 : 1;
            int i;
            code = b0 & (0x3F >> extra);
            for (i = 1; i <= extra && (size_t)i < len; i++)
                code = (code << 6) | ((unsigned char)s[i] & 0x3F);
        }
        RET(unify(A[1], mk_int(code)));
    }
    if (n->tag == TAG_INT) {
        char buf[8];
        long code = (long)IV(n);
        size_t k = 0;
        if (code < 0 || code > 0x10FFFF) return representation_error("character_code");
        if (code < 0x80) buf[k++] = (char)code;
        else if (code < 0x800) {
            buf[k++] = (char)(0xC0 | (code >> 6));
            buf[k++] = (char)(0x80 | (code & 0x3F));
        } else if (code < 0x10000) {
            buf[k++] = (char)(0xE0 | (code >> 12));
            buf[k++] = (char)(0x80 | ((code >> 6) & 0x3F));
            buf[k++] = (char)(0x80 | (code & 0x3F));
        } else {
            buf[k++] = (char)(0xF0 | (code >> 18));
            buf[k++] = (char)(0x80 | ((code >> 12) & 0x3F));
            buf[k++] = (char)(0x80 | ((code >> 6) & 0x3F));
            buf[k++] = (char)(0x80 | (code & 0x3F));
        }
        RET(unify(A[0], mk_atom(intern_n(buf, k))));
    }
    if (c->tag == TAG_VAR && n->tag == TAG_VAR) return instantiation_error();
    return type_error(c->tag == TAG_VAR ? "integer" : "character",
                      c->tag == TAG_VAR ? n : c);
}

BI(bi_number_codes)
{
    UNUSED;
    Term *a = deref(A[0]);
    char *s;
    size_t n;
    int rc, ok;
    if (a->tag != TAG_VAR) {
        if (!IS_NUM(a)) return type_error("number", a);
        text_of(a, &s, &n);
        ok = unify(A[1], mk_codes(s, n));
        free(s);
        RET(ok);
    }
    rc = get_text(A[1], &s, &n, "list");
    if (rc != PL_OK) return rc;
    {
        Term *num = parse_number_str(s, n);
        free(s);
        if (!num) return pl_throw(mk1(intern("syntax_error"),
                                      mk_atom_str("illegal_number")));
        RET(unify(A[0], num));
    }
}

BI(bi_number_chars)
{
    UNUSED;
    Term *a = deref(A[0]);
    char *s;
    size_t n;
    int rc, ok;
    if (a->tag != TAG_VAR) {
        if (!IS_NUM(a)) return type_error("number", a);
        text_of(a, &s, &n);
        ok = unify(A[1], mk_chars(s, n));
        free(s);
        RET(ok);
    }
    rc = get_text(A[1], &s, &n, "list");
    if (rc != PL_OK) return rc;
    {
        Term *num = parse_number_str(s, n);
        free(s);
        if (!num) return pl_throw(mk1(intern("syntax_error"),
                                      mk_atom_str("illegal_number")));
        RET(unify(A[0], num));
    }
}

BI(bi_atom_number)
{
    UNUSED;
    Term *a = deref(A[0]);
    if (a->tag != TAG_VAR) {
        char *s;
        size_t n;
        Term *num;
        if (!text_of(a, &s, &n)) return type_error("atom", a);
        num = parse_number_str(s, n);
        free(s);
        if (!num) return PL_FAIL;
        RET(unify(A[1], num));
    } else {
        Term *num = deref(A[1]);
        char *s;
        size_t n;
        int ok;
        if (num->tag == TAG_VAR) return instantiation_error();
        if (!IS_NUM(num)) return type_error("number", num);
        text_of(num, &s, &n);
        ok = unify(A[0], mk_atom(intern_n(s, n)));
        free(s);
        RET(ok);
    }
}

/* '$atom_concat'(+A, +B, -C): the deterministic half of atom_concat/3. */
BI(bi_atom_concat3)
{
    UNUSED;
    char *a, *b, *c;
    size_t na, nb;
    int rc, ok;
    if ((rc = get_text(A[0], &a, &na, "atomic")) != PL_OK) return rc;
    if ((rc = get_text(A[1], &b, &nb, "atomic")) != PL_OK) { free(a); return rc; }
    c = (char *)malloc(na + nb + 1);
    memcpy(c, a, na);
    memcpy(c + na, b, nb);
    c[na + nb] = 0;
    ok = unify(A[2], mk_atom(intern_n(c, na + nb)));
    free(a); free(b); free(c);
    RET(ok);
}

/* '$join'(+List, +Sep, -Atom): the parts of List with Sep between them,
   gathered into one buffer and interned once.  Joining in Prolog made a
   new atom at every step, and atoms are never freed, so a million parts
   cost quadratic time and memory. */
BI(bi_join3)
{
    UNUSED;
    Term *l = deref(A[0]);
    char *sep = NULL, *buf = NULL;
    size_t nsep = 0, len = 0, cap = 0;
    int rc = PL_OK, first = 1, ok;

    while (l->tag == TAG_STR && FN(l) == a_dot && AR(l) == 2) {
        char *part;
        size_t n;
        if ((rc = get_text(ARG(l, 0), &part, &n, "atomic")) != PL_OK) break;
        l = deref(ARG(l, 1));
        if (!first && !sep && (rc = get_text(A[1], &sep, &nsep, "atomic")) != PL_OK) {
            free(part);
            break;
        }
        if (len + nsep + n + 1 > cap) {
            while (len + nsep + n + 1 > cap) cap = cap ? cap * 2 : 256;
            buf = (char *)realloc(buf, cap);
        }
        if (!first) { memcpy(buf + len, sep, nsep); len += nsep; }
        memcpy(buf + len, part, n);
        len += n;
        free(part);
        first = 0;
    }
    free(sep);
    if (rc != PL_OK) { free(buf); return rc; }
    ok = unify(A[2], mk_atom(intern_n(buf ? buf : "", len)));
    free(buf);
    RET(ok);
}

/* '$split_atom'(+Atom, +Sep, -Parts): Atom cut at each occurrence of Sep,
   leftmost first, into a list of atoms.  One pass over the text, where the
   Prolog version interned every remainder on the way and was quadratic.
   Both are taken as text, as '$join' takes them, so that splitting undoes
   joining for a separator that is a number.  Sep is not ''. */
BI(bi_split_atom3)
{
    UNUSED;
    char *a, *sep;
    size_t na, ns, i, start = 0;
    int rc, ok;
    Term *head = NULL, *last = NULL, *cell;

    if ((rc = get_text(A[0], &a, &na, "atom")) != PL_OK) return rc;
    if ((rc = get_text(A[1], &sep, &ns, "atom")) != PL_OK) { free(a); return rc; }
    for (i = 0; ns && i + ns <= na; ) {
        if (memcmp(a + i, sep, ns) == 0) {
            cell = mk_cons(mk_atom(intern_n(a + start, i - start)), mk_atom(a_nil));
            if (last) ARG(last, 1) = cell; else head = cell;
            last = cell;
            i += ns;
            start = i;
        } else i++;
    }
    cell = mk_cons(mk_atom(intern_n(a + start, na - start)), mk_atom(a_nil));
    if (last) ARG(last, 1) = cell; else head = cell;
    ok = unify(A[2], head);
    free(a);
    free(sep);
    RET(ok);
}

/* '$sub_atom'(+Atom, +Before, +Len, -Sub) in characters. */
BI(bi_sub_atom4)
{
    UNUSED;
    char *s;
    size_t n;
    long long b, l;
    int rc, ok;
    size_t from, to;
    if ((rc = get_text(A[0], &s, &n, "atom")) != PL_OK) return rc;
    if ((rc = get_int(A[1], &b)) != PL_OK) { free(s); return rc; }
    if ((rc = get_int(A[2], &l)) != PL_OK) { free(s); return rc; }
    if (b < 0 || l < 0) { free(s); return PL_FAIL; }
    from = utf8_offset(s, n, (size_t)b);
    to = utf8_offset(s, n, (size_t)(b + l));
    if (from > n || to > n) { free(s); return PL_FAIL; }
    ok = unify(A[3], mk_atom(intern_n(s + from, to - from)));
    free(s);
    RET(ok);
}

BI(bi_upcase)
{
    UNUSED;
    char *s;
    size_t n, i;
    int rc = get_text(A[0], &s, &n, "atom"), ok;
    if (rc != PL_OK) return rc;
    for (i = 0; i < n; i++) s[i] = (char)toupper((unsigned char)s[i]);
    ok = unify(A[1], mk_atom(intern_n(s, n)));
    free(s);
    RET(ok);
}

BI(bi_downcase)
{
    UNUSED;
    char *s;
    size_t n, i;
    int rc = get_text(A[0], &s, &n, "atom"), ok;
    if (rc != PL_OK) return rc;
    for (i = 0; i < n; i++) s[i] = (char)tolower((unsigned char)s[i]);
    ok = unify(A[1], mk_atom(intern_n(s, n)));
    free(s);
    RET(ok);
}

BI(bi_term_to_atom)
{
    UNUSED;
    Term *t = deref(A[0]);
    if (t->tag != TAG_VAR || deref(A[1])->tag == TAG_VAR) {
        char *s = term_to_string(A[0], WR_QUOTED | WR_NUMBERVARS, NULL);
        int ok = unify(A[1], mk_atom_str(s));
        free(s);
        RET(ok);
    } else {
        char *s;
        size_t n;
        int rc = get_text(A[1], &s, &n, "atom");
        Reader r;
        Term *parsed, *names;
        char *buf;
        if (rc != PL_OK) return rc;
        buf = (char *)malloc(n + 3);
        memcpy(buf, s, n);
        strcpy(buf + n, " .");
        reader_init_string(&r, buf, n + 2);
        r.name = "term_to_atom";
        rc = read_term_from(&r, &parsed, &names);
        free(s); free(buf);
        if (rc < 0) return PL_ERROR;
        if (rc == 0) return PL_FAIL;
        RET(unify(A[0], parsed));
    }
}

BI(bi_atom_to_term)
{
    UNUSED;
    char *s;
    size_t n;
    int rc = get_text(A[0], &s, &n, "atom");
    Reader r;
    Term *parsed, *names;
    char *buf;
    if (rc != PL_OK) return rc;
    buf = (char *)malloc(n + 3);
    memcpy(buf, s, n);
    strcpy(buf + n, " .");
    reader_init_string(&r, buf, n + 2);
    r.name = "atom_to_term";
    rc = read_term_from(&r, &parsed, &names);
    free(s); free(buf);
    if (rc < 0) return PL_ERROR;
    if (rc == 0) { parsed = mk_atom(a_end_of_file); names = mk_atom(a_nil); }
    RET(unify(A[1], parsed) && unify(A[2], names));
}

/* ------------------------------------------------------------------ */
/* findall/3 and friends                                              */
/* ------------------------------------------------------------------ */

typedef struct FASol {
    struct FASol *next;
    Term *t;
    int   nvars;
} FASol;

typedef struct {
    Arena  *arena;
    FASol  *first, *last;
    Term   *tmpl;
    long long count;
    int     limit;          /* stop after this many solutions, 0 = all */
} FACtx;

static int findall_collect(void *ctx)
{
    FACtx *fa = (FACtx *)ctx;
    FASol *s = (FASol *)arena_alloc(fa->arena, sizeof(FASol));
    s->next = NULL;
    s->t = arena_compile(fa->arena, fa->tmpl, &s->nvars);
    if (fa->last) fa->last->next = s;
    else fa->first = s;
    fa->last = s;
    fa->count++;
    if (fa->limit && fa->count >= fa->limit) return 0;
    return 1;
}

static int findall_run(Term *tmpl, Term *goal, Term **out, Term *tail, int limit)
{
    FACtx fa;
    FASol *s;
    Term *list;
    int rc;

    fa.arena = arena_new();
    fa.first = fa.last = NULL;
    fa.tmpl = tmpl;
    fa.count = 0;
    fa.limit = limit;
    rc = solve_sub(goal, findall_collect, &fa);
    if (rc != PL_OK) { arena_free(fa.arena); return rc; }

    /* Rebuild the collected solutions on the heap, in order. */
    {
        Term **items = (Term **)malloc((size_t)(fa.count + 1) * sizeof(Term *));
        long long i = 0;
        for (s = fa.first; s; s = s->next) {
            Term **vars = (Term **)heap_alloc((s->nvars + 1) * sizeof(Term *));
            int k;
            for (k = 0; k < s->nvars; k++) vars[k] = NULL;
            items[i++] = heap_instantiate(s->t, vars, s->nvars);
        }
        list = tail ? tail : mk_atom(a_nil);
        for (i = fa.count - 1; i >= 0; i--) list = mk_cons(items[i], list);
        free(items);
    }
    arena_free(fa.arena);
    *out = list;
    return PL_OK;
}

BI(bi_findall)
{
    UNUSED;
    Term *list;
    int rc = findall_run(A[0], A[1], &list, NULL, 0);
    if (rc != PL_OK) return rc;
    RET(unify(A[2], list));
}

BI(bi_findall4)
{
    UNUSED;
    Term *list;
    int rc = findall_run(A[0], A[1], &list, A[3], 0);
    if (rc != PL_OK) return rc;
    RET(unify(A[2], list));
}

/* '$findnsols'(+N, ?Tmpl, :Goal, -List) */
BI(bi_findnsols)
{
    UNUSED;
    long long n;
    Term *list;
    int rc = get_int(A[0], &n);
    if (rc != PL_OK) return rc;
    rc = findall_run(A[1], A[2], &list, NULL, (int)n);
    if (rc != PL_OK) return rc;
    RET(unify(A[3], list));
}

/* ------------------------------------------------------------------ */
/* Sorting                                                            */
/* ------------------------------------------------------------------ */

static long long sort_key;

static Term *key_of(Term *t)
{
    if (sort_key == 0) return t;
    t = deref(t);
    if (t->tag != TAG_STR || AR(t) < sort_key) return t;
    return ARG(t, (int)sort_key - 1);
}

static int (*sort_cmp)(Term *, Term *);

static int cmp_asc(Term *a, Term *b) { return compare_terms(key_of(a), key_of(b)); }
static int cmp_desc(Term *a, Term *b) { return -compare_terms(key_of(a), key_of(b)); }

/* Stable merge sort, so that keysort/2 keeps the input order of equals. */
static void msort_rec(Term **a, Term **tmp, int n)
{
    int mid, i, j, k;
    if (n < 2) return;
    mid = n / 2;
    msort_rec(a, tmp, mid);
    msort_rec(a + mid, tmp, n - mid);
    i = 0; j = mid; k = 0;
    while (i < mid && j < n)
        tmp[k++] = (sort_cmp(a[j], a[i]) < 0) ? a[j++] : a[i++];
    while (i < mid) tmp[k++] = a[i++];
    while (j < n) tmp[k++] = a[j++];
    memcpy(a, tmp, (size_t)n * sizeof(Term *));
}

static int list_to_array(Term *l, Term ***out, int *n)
{
    int cap = 64, k = 0;
    *out = NULL;
    *n = 0;
    Term **a = (Term **)malloc((size_t)cap * sizeof(Term *));
    l = deref(l);
    while (l->tag == TAG_STR && FN(l) == a_dot && AR(l) == 2) {
        if (k == cap) { cap *= 2; a = (Term **)realloc(a, (size_t)cap * sizeof(Term *)); }
        a[k++] = deref(ARG(l, 0));
        l = deref(ARG(l, 1));
    }
    if (l->tag == TAG_VAR) { free(a); return instantiation_error(); }
    if (!(l->tag == TAG_ATOM && AT(l) == a_nil)) { free(a); return type_error("list", l); }
    *out = a;
    *n = k;
    return PL_OK;
}

/* order: 0 = @<, 1 = @=<, 2 = @>, 3 = @>= */
static int do_sort(Term *list, long long key, int order, Term *result)
{
    Term **a, **tmp;
    int n, i, k, rc;
    int dedup = (order == 0 || order == 2);

    rc = list_to_array(list, &a, &n);
    if (rc != PL_OK) return rc;
    sort_key = key;
    sort_cmp = (order >= 2) ? cmp_desc : cmp_asc;
    tmp = (Term **)malloc((size_t)(n + 1) * sizeof(Term *));
    msort_rec(a, tmp, n);
    if (dedup) {
        for (i = 0, k = 0; i < n; i++)
            if (k == 0 || compare_terms(key_of(a[k - 1]), key_of(a[i])) != 0)
                a[k++] = a[i];
        n = k;
    }
    {
        Term *l = list_from_array(a, n);
        free(a); free(tmp);
        RET(unify(result, l));
    }
}

BI(bi_msort) { UNUSED; return do_sort(A[0], 0, 1, A[1]); }
BI(bi_sort)  { UNUSED; return do_sort(A[0], 0, 0, A[1]); }

BI(bi_sort4)
{
    UNUSED;
    long long key;
    int rc, order;
    const char *o;
    Term *ot = deref(A[1]);
    if ((rc = get_int(A[0], &key)) != PL_OK) return rc;
    if (ot->tag != TAG_ATOM) return type_error("atom", ot);
    o = atom_name(AT(ot));
    if (!strcmp(o, "@<")) order = 0;
    else if (!strcmp(o, "@=<")) order = 1;
    else if (!strcmp(o, "@>")) order = 2;
    else if (!strcmp(o, "@>=")) order = 3;
    else return domain_error("order", ot);
    if (key < 0) return domain_error("not_less_than_zero", deref(A[0]));
    return do_sort(A[2], key, order, A[3]);
}

BI(bi_keysort)
{
    UNUSED;
    Term **a, **tmp;
    int n, i, rc;
    rc = list_to_array(A[0], &a, &n);
    if (rc != PL_OK) return rc;
    for (i = 0; i < n; i++) {
        Term *p = deref(a[i]);
        if (p->tag == TAG_VAR) { free(a); return instantiation_error(); }
        if (p->tag != TAG_STR || FN(p) != a_minus || AR(p) != 2) {
            free(a);
            return type_error("pair", p);
        }
    }
    sort_key = 1;
    sort_cmp = cmp_asc;
    tmp = (Term **)malloc((size_t)(n + 1) * sizeof(Term *));
    msort_rec(a, tmp, n);
    {
        Term *l = list_from_array(a, n);
        free(a); free(tmp);
        RET(unify(A[1], l));
    }
}

/* '$skip_list'(?List, -Len, -Tail): walks as far as the list goes. */
BI(bi_skip_list)
{
    UNUSED;
    Term *l = deref(A[0]);
    long long n = 0;
    while (l->tag == TAG_STR && FN(l) == a_dot && AR(l) == 2) {
        n++;
        l = deref(ARG(l, 1));
    }
    RET(unify(A[1], mk_int(n)) && unify(A[2], l));
}

/* '$make_list'(+N, -List): a list of N fresh variables. */
BI(bi_make_list)
{
    UNUSED;
    long long n;
    Term *l;
    int rc = get_int(A[0], &n);
    if (rc != PL_OK) return rc;
    if (n < 0) return PL_FAIL;
    l = mk_atom(a_nil);
    while (n-- > 0) l = mk_cons(mk_var(), l);
    RET(unify(A[1], l));
}

/* ------------------------------------------------------------------ */
/* The database                                                       */
/* ------------------------------------------------------------------ */

static int split_clause(Term *cl, Term **head, Term **body)
{
    cl = deref(cl);
    if (cl->tag == TAG_VAR) return instantiation_error();
    if (cl->tag == TAG_STR && FN(cl) == a_neck && AR(cl) == 2) {
        *head = deref(ARG(cl, 0));
        *body = deref(ARG(cl, 1));
    } else {
        *head = cl;
        *body = mk_atom(a_true);
    }
    if ((*head)->tag == TAG_VAR) return instantiation_error();
    if (!IS_CALLABLE(*head)) return type_error("callable", *head);
    return PL_OK;
}

static int pred_of(Term *head, Pred **p, int create)
{
    int f, n;
    head = deref(head);
    if (head->tag == TAG_ATOM) { f = AT(head); n = 0; }
    else if (head->tag == TAG_STR) { f = FN(head); n = AR(head); }
    else return type_error("callable", head);
    if (builtin_exists(f, n))
        return permission_error("modify", "static_procedure",
                                mk2(a_slash, mk_atom(f), mk_int(n)));
    *p = pred_lookup(f, n, create);
    return PL_OK;
}

static int do_assert(Term *cl, int at_end)
{
    Term *head, *body;
    Pred *p;
    Clause *c;
    int rc;

    if ((rc = split_clause(cl, &head, &body)) != PL_OK) return rc;
    if ((rc = pred_of(head, &p, 1)) != PL_OK) return rc;
    c = clause_make(head, body);
    p->dynamic = 1;
    pred_add_clause(p, c, at_end);
    return PL_OK;
}

BI(bi_assertz) { UNUSED; return do_assert(A[0], 1); }
BI(bi_asserta) { UNUSED; return do_assert(A[0], 0); }

BI(bi_retract)
{
    Term *head, *body;
    Pred *p;
    int rc;

    if ((rc = split_clause(A[0], &head, &body)) != PL_OK) return rc;
    if ((rc = pred_of(head, &p, 0)) != PL_OK) return rc;
    if (!p) return PL_FAIL;
    return clause_iter_start(p, head, body, ITER_RETRACT, cont, cutb);
}

BI(bi_clause)
{
    Term *head = deref(A[0]), *body = deref(A[1]);
    Pred *p;
    int rc;

    if (head->tag == TAG_VAR) return instantiation_error();
    if (!IS_CALLABLE(head)) return type_error("callable", head);
    if (body->tag != TAG_VAR && !IS_CALLABLE(body)) return type_error("callable", body);
    if ((rc = pred_of(head, &p, 0)) != PL_OK) return rc;
    if (!p) return PL_FAIL;
    return clause_iter_start(p, head, body, ITER_CLAUSE, cont, cutb);
}

BI(bi_retractall)
{
    UNUSED;
    Term *head = deref(A[0]);
    Pred *p;
    Clause *c, *nx;
    int rc;

    if (head->tag == TAG_VAR) return instantiation_error();
    if ((rc = pred_of(head, &p, 1)) != PL_OK) return rc;
    p->dynamic = 1;
    p->defined = 1;
    for (c = p->first; c; c = nx) {
        size_t tm = trail_mark();
        Term **vars = (Term **)heap_alloc((c->nvars + 1) * sizeof(Term *));
        Term *h;
        int i;
        nx = c->next;
        for (i = 0; i < c->nvars; i++) vars[i] = NULL;
        h = heap_instantiate(c->head, vars, c->nvars);
        if (unify(head, h)) clause_retract(p, c);
        trail_undo(tm);
    }
    return PL_OK;
}

static int decl_each(Term *spec, int what)   /* 1 = dynamic, 2 = discontiguous, 3 = multifile */
{
    Term *t = deref(spec);
    int rc;

    if (t->tag == TAG_VAR) return instantiation_error();
    if (t->tag == TAG_STR && AR(t) == 2 &&
        (FN(t) == a_comma || FN(t) == a_dot)) {
        if ((rc = decl_each(ARG(t, 0), what)) != PL_OK) return rc;
        if (FN(t) == a_dot) {
            Term *tail = deref(ARG(t, 1));
            if (tail->tag == TAG_ATOM && AT(tail) == a_nil) return PL_OK;
        }
        return decl_each(ARG(t, 1), what);
    }
    if (t->tag == TAG_ATOM && AT(t) == a_nil) return PL_OK;
    if (t->tag == TAG_STR && FN(t) == a_slash && AR(t) == 2) {
        Term *nm = deref(ARG(t, 0)), *ar = deref(ARG(t, 1));
        Pred *p;
        if (nm->tag == TAG_VAR || ar->tag == TAG_VAR) return instantiation_error();
        if (nm->tag != TAG_ATOM) return type_error("atom", nm);
        if (ar->tag != TAG_INT) return type_error("integer", ar);
        if (builtin_exists(AT(nm), (int)IV(ar)))
            return permission_error("modify", "static_procedure", t);
        p = pred_lookup(AT(nm), (int)IV(ar), 1);
        if (what == 1) { p->dynamic = 1; p->defined = 1; }
        else if (what == 2) p->discontiguous = 1;
        else p->multifile = 1;
        return PL_OK;
    }
    return type_error("predicate_indicator", t);
}

BI(bi_dynamic)        { UNUSED; return decl_each(A[0], 1); }
BI(bi_discontiguous)  { UNUSED; return decl_each(A[0], 2); }
BI(bi_multifile)      { UNUSED; return decl_each(A[0], 3); }

BI(bi_abolish)
{
    UNUSED;
    Term *t = deref(A[0]);
    Pred *p;
    if (t->tag == TAG_STR && FN(t) == a_slash && AR(t) == 2) {
        Term *nm = deref(ARG(t, 0)), *ar = deref(ARG(t, 1));
        if (nm->tag == TAG_VAR || ar->tag == TAG_VAR) return instantiation_error();
        if (nm->tag != TAG_ATOM) return type_error("atom", nm);
        if (ar->tag != TAG_INT) return type_error("integer", ar);
        if (builtin_exists(AT(nm), (int)IV(ar)))
            return permission_error("modify", "static_procedure", t);
        p = pred_lookup(AT(nm), (int)IV(ar), 0);
        if (p) pred_abolish(p);
        return PL_OK;
    }
    return type_error("predicate_indicator", t);
}

/* '$predicate_property'(+Head, ?Prop) for a few useful properties. */
BI(bi_predicate_defined)
{
    UNUSED;
    Term *head = deref(A[0]);
    int f, n;
    Pred *p;
    if (head->tag == TAG_VAR) return instantiation_error();
    if (head->tag == TAG_ATOM) { f = AT(head); n = 0; }
    else if (head->tag == TAG_STR) { f = FN(head); n = AR(head); }
    else return type_error("callable", head);
    if (builtin_exists(f, n)) return PL_OK;
    p = pred_lookup(f, n, 0);
    RET(p && p->defined);
}

/* '$predicates'(-List) : all user predicates as Name/Arity. */
BI(bi_predicates)
{
    UNUSED;
    Term *list = mk_atom(a_nil);
    Term **buf;
    int i = 0, n = 0, cap = 256;
    Pred *p;
    buf = (Term **)malloc((size_t)cap * sizeof(Term *));
    while (pred_enumerate(i++, &p)) {
        if (!p->defined) continue;
        if (n == cap) { cap *= 2; buf = (Term **)realloc(buf, (size_t)cap * sizeof(Term *)); }
        buf[n++] = mk2(a_slash, mk_atom(p->functor), mk_int(p->arity));
    }
    list = list_from_array(buf, n);
    free(buf);
    RET(unify(A[0], list));
}

/* '$clauses'(+Name/Arity, -List): clauses as Head-Body pairs, for listing. */
BI(bi_clauses)
{
    UNUSED;
    Term *t = deref(A[0]);
    Pred *p;
    Term **buf;
    int n = 0, cap = 64;
    Clause *c;

    if (t->tag != TAG_STR || FN(t) != a_slash || AR(t) != 2)
        return type_error("predicate_indicator", t);
    {
        Term *nm = deref(ARG(t, 0)), *ar = deref(ARG(t, 1));
        if (nm->tag != TAG_ATOM || ar->tag != TAG_INT) return instantiation_error();
        p = pred_lookup(AT(nm), (int)IV(ar), 0);
    }
    if (!p) return PL_FAIL;
    buf = (Term **)malloc((size_t)cap * sizeof(Term *));
    for (c = p->first; c; c = c->next) {
        Term **vars = (Term **)heap_alloc((c->nvars + 1) * sizeof(Term *));
        int i;
        for (i = 0; i < c->nvars; i++) vars[i] = NULL;
        if (n == cap) { cap *= 2; buf = (Term **)realloc(buf, (size_t)cap * sizeof(Term *)); }
        buf[n++] = mk2(a_minus, heap_instantiate(c->head, vars, c->nvars),
                       heap_instantiate(c->body, vars, c->nvars));
    }
    {
        Term *l = list_from_array(buf, n);
        free(buf);
        RET(unify(A[1], l));
    }
}

/* ------------------------------------------------------------------ */
/* Global variables                                                   */
/* ------------------------------------------------------------------ */

typedef struct GVar {
    struct GVar *next;
    int    name;
    Arena *arena;
    Term  *t;
    int    nvars;
} GVar;

static GVar *gvars;

BI(bi_nb_setval)
{
    UNUSED;
    int name;
    GVar *g;
    int rc = get_atom(A[0], &name);
    if (rc != PL_OK) return rc;
    for (g = gvars; g; g = g->next) if (g->name == name) break;
    if (!g) {
        g = (GVar *)calloc(1, sizeof(GVar));
        g->name = name;
        g->next = gvars;
        gvars = g;
    } else {
        arena_free(g->arena);
    }
    g->arena = arena_new();
    g->t = arena_compile(g->arena, A[1], &g->nvars);
    return PL_OK;
}

BI(bi_nb_getval)
{
    UNUSED;
    int name;
    GVar *g;
    int rc = get_atom(A[0], &name);
    if (rc != PL_OK) return rc;
    for (g = gvars; g; g = g->next)
        if (g->name == name) {
            Term **vars = (Term **)heap_alloc((g->nvars + 1) * sizeof(Term *));
            int i;
            for (i = 0; i < g->nvars; i++) vars[i] = NULL;
            RET(unify(A[1], heap_instantiate(g->t, vars, g->nvars)));
        }
    return existence_error("variable", deref(A[0]));
}

/* ------------------------------------------------------------------ */
/* Output                                                             */
/* ------------------------------------------------------------------ */

static void emit_stream(void *ctx, const char *s, size_t n)
{
    stream_write((PStream *)ctx, s, n);
}

static void write_to(PStream *s, Term *t, int flags, int maxdepth)
{
    Writer w;
    memset(&w, 0, sizeof(w));
    w.emit = emit_stream;
    w.ctx = s;
    w.flags = flags;
    w.maxdepth = maxdepth;
    write_term(&w, t);
}

static int stream_arg(Term *t, PStream **s)
{
    Term *d = deref(t);
    if (d->tag == TAG_VAR) return instantiation_error();
    *s = stream_of(d);
    if (!*s) return existence_error("stream", d);
    return PL_OK;
}

#define OUT_1(fn, flags)                                          \
    BI(fn) { UNUSED; write_to(stream_current_output(), A[0], flags, 0); \
             return PL_OK; }
#define OUT_2(fn, flags)                                          \
    BI(fn) { UNUSED; PStream *s; int rc = stream_arg(A[0], &s);   \
             if (rc != PL_OK) return rc;                          \
             write_to(s, A[1], flags, 0); return PL_OK; }

OUT_1(bi_write,           WR_NUMBERVARS)
OUT_2(bi_write2,          WR_NUMBERVARS)
OUT_1(bi_print,           WR_NUMBERVARS | WR_QUOTED)
OUT_2(bi_print2,          WR_NUMBERVARS | WR_QUOTED)
OUT_1(bi_writeq,          WR_NUMBERVARS | WR_QUOTED)
OUT_2(bi_writeq2,         WR_NUMBERVARS | WR_QUOTED)
OUT_1(bi_write_canonical, WR_QUOTED | WR_IGNORE_OPS)
OUT_2(bi_write_canonical2,WR_QUOTED | WR_IGNORE_OPS)

BI(bi_nl)  { UNUSED; stream_write(stream_current_output(), "\n", 1); return PL_OK; }
BI(bi_nl1) { UNUSED; PStream *s; int rc = stream_arg(A[0], &s);
             if (rc != PL_OK) return rc;
             stream_write(s, "\n", 1); return PL_OK; }

BI(bi_writeln)
{
    UNUSED;
    write_to(stream_current_output(), A[0], WR_NUMBERVARS, 0);
    stream_write(stream_current_output(), "\n", 1);
    return PL_OK;
}

BI(bi_writeln2)
{
    UNUSED;
    PStream *s;
    int rc = stream_arg(A[0], &s);
    if (rc != PL_OK) return rc;
    write_to(s, A[1], WR_NUMBERVARS, 0);
    stream_write(s, "\n", 1);
    return PL_OK;
}

static int write_options(Term *opts, int *flags, int *maxdepth)
{
    Term *l = deref(opts);
    *flags = 0;
    *maxdepth = 0;
    while (l->tag == TAG_STR && FN(l) == a_dot && AR(l) == 2) {
        Term *o = deref(ARG(l, 0));
        if (o->tag == TAG_STR && AR(o) == 1) {
            Term *v = deref(ARG(o, 0));
            const char *nm = atom_name(FN(o));
            int on = v->tag == TAG_ATOM && AT(v) == a_true;
            if (!strcmp(nm, "quoted")) { if (on) *flags |= WR_QUOTED; }
            else if (!strcmp(nm, "ignore_ops")) { if (on) *flags |= WR_IGNORE_OPS; }
            else if (!strcmp(nm, "numbervars")) { if (on) *flags |= WR_NUMBERVARS; }
            else if (!strcmp(nm, "max_depth") && v->tag == TAG_INT)
                *maxdepth = (int)IV(v);
        } else if (o->tag == TAG_VAR) return instantiation_error();
        l = deref(ARG(l, 1));
    }
    if (l->tag == TAG_VAR) return instantiation_error();
    if (!(l->tag == TAG_ATOM && AT(l) == a_nil)) return type_error("list", opts);
    return PL_OK;
}

BI(bi_write_term)
{
    UNUSED;
    int flags, md;
    int rc = write_options(A[1], &flags, &md);
    if (rc != PL_OK) return rc;
    write_to(stream_current_output(), A[0], flags, md);
    return PL_OK;
}

BI(bi_write_term3)
{
    UNUSED;
    int flags, md;
    PStream *s;
    int rc = stream_arg(A[0], &s);
    if (rc != PL_OK) return rc;
    rc = write_options(A[2], &flags, &md);
    if (rc != PL_OK) return rc;
    write_to(s, A[1], flags, md);
    return PL_OK;
}

BI(bi_tab)
{
    UNUSED;
    Term *n;
    long long i;
    if (arith_eval(A[0], &n) != PL_OK) return PL_ERROR;
    if (n->tag != TAG_INT) return type_error("integer", n);
    for (i = 0; i < IV(n); i++) stream_write(stream_current_output(), " ", 1);
    return PL_OK;
}

/* ------------------------------------------------------------------ */
/* Characters: get_char/1,2, peek_char/1,2, put_char/1,2,             */
/* at_end_of_stream/0,1                                               */
/* ------------------------------------------------------------------ */

static int input_stream_arg(Term *t, PStream **s)
{
    int rc = stream_arg(t, s);
    if (rc != PL_OK) return rc;
    if (!stream_is_input(*s)) return permission_error("input", "stream", t);
    return PL_OK;
}

static int output_stream_arg(Term *t, PStream **s)
{
    int rc = stream_arg(t, s);
    if (rc != PL_OK) return rc;
    if (stream_is_input(*s)) return permission_error("output", "stream", t);
    return PL_OK;
}

static int is_char_atom(Term *t)
{
    return t->tag == TAG_ATOM
        && utf8_len(atom_name(AT(t)), atom_len(AT(t))) == 1;
}

/* The stream as an error names it: by its alias when the goal did not
   name it at all. */
static Term *stream_culprit(PStream *s, Term *given)
{
    if (given) return deref(given);
    return stream_alias(s) >= 0 ? mk_atom(stream_alias(s)) : stream_term(s);
}

/* Asks the stream whether a read may go ahead.  PL_OK to read, PL_FAIL
   when the answer is end_of_file without reading, and the error when the
   stream is already past its end and its eof_action is error. */
static int check_read(PStream *s, Term *given)
{
    switch (stream_read_check(s)) {
    case STREAM_READ: return PL_OK;
    case STREAM_EOF:  return PL_FAIL;
    default:
        return permission_error("input", "past_end_of_stream",
                                stream_culprit(s, given));
    }
}

/* get_char and peek_char: the next character as a one-character atom, or
   end_of_file.  After end_of_file, the next read does what the stream's
   eof_action says. */
static int read_char(PStream *s, Term *given, Term *out, int peek)
{
    Term *c = deref(out);
    char buf[4];
    int n, rc;
    if (c->tag != TAG_VAR && !is_char_atom(c)
        && !(c->tag == TAG_ATOM && AT(c) == a_end_of_file))
        return type_error("in_character", c);
    rc = check_read(s, given);
    if (rc == PL_FAIL) RET(unify(out, mk_atom(a_end_of_file)));
    if (rc != PL_OK) return rc;
    n = peek ? stream_peek_char(s, buf) : stream_get_char(s, buf);
    RET(unify(out, mk_atom(n ? intern_n(buf, (size_t)n) : a_end_of_file)));
}

BI(bi_get_char)  { UNUSED; return read_char(stream_current_input(), NULL, A[0], 0); }
BI(bi_peek_char) { UNUSED; return read_char(stream_current_input(), NULL, A[0], 1); }
BI(bi_get_char2) { UNUSED; PStream *s; int rc = input_stream_arg(A[0], &s);
                   if (rc != PL_OK) return rc;
                   return read_char(s, A[0], A[1], 0); }
BI(bi_peek_char2){ UNUSED; PStream *s; int rc = input_stream_arg(A[0], &s);
                   if (rc != PL_OK) return rc;
                   return read_char(s, A[0], A[1], 1); }

/* read_line_to_string/2 and read_line_to_codes/2, as SWI-Prolog has them:
   the next line without its line ending, \n or \r\n, as an atom, since
   there is no string type, or as a code list. At the end of the stream the
   answer is end_of_file or -1; a last line with no line ending is a line,
   and leaves the stream at its end, not past it, so the next call answers
   end_of_file rather than what eof_action says a read past the end does.
   The characters come through the stream layer, as get_char's do, so the
   two can be mixed on one stream. */
static int read_line(Term *given, Term *out, int codes)
{
    PStream *s;
    char buf[4], *line = NULL;
    size_t len = 0, cap = 0;
    int n, rc = input_stream_arg(given, &s);
    Term *t;

    if (rc != PL_OK) return rc;
    rc = check_read(s, given);
    if (rc == PL_FAIL)
        RET(unify(out, codes ? mk_int(-1) : mk_atom(a_end_of_file)));
    if (rc != PL_OK) return rc;
    if (stream_peek_char(s, buf) == 0) {
        stream_get_char(s, buf);                    /* now past the end */
        RET(unify(out, codes ? mk_int(-1) : mk_atom(a_end_of_file)));
    }
    n = stream_get_char(s, buf);
    while (!(n == 1 && buf[0] == '\n')) {
        if (len + (size_t)n > cap) {
            cap = cap ? cap * 2 : 128;
            line = (char *)realloc(line, cap);
            if (!line) { fprintf(stderr, "prolog: out of memory\n"); exit(1); }
        }
        memcpy(line + len, buf, (size_t)n);
        len += (size_t)n;
        if (stream_peek_char(s, buf) == 0) break;   /* at the end, not past */
        n = stream_get_char(s, buf);
    }
    if (len > 0 && line[len - 1] == '\r') len--;
    t = codes ? mk_codes(line ? line : "", len)
              : mk_atom(intern_n(line ? line : "", len));
    free(line);
    RET(unify(out, t));
}

BI(bi_read_line_to_string) { UNUSED; return read_line(A[0], A[1], 0); }
BI(bi_read_line_to_codes)  { UNUSED; return read_line(A[0], A[1], 1); }

static int write_char(PStream *s, Term *t)
{
    Term *c = deref(t);
    if (c->tag == TAG_VAR) return instantiation_error();
    if (!is_char_atom(c)) return type_error("character", c);
    stream_write(s, atom_name(AT(c)), atom_len(AT(c)));
    return PL_OK;
}

BI(bi_put_char)  { UNUSED; return write_char(stream_current_output(), A[0]); }
BI(bi_put_char2) { UNUSED; PStream *s; int rc = output_stream_arg(A[0], &s);
                   if (rc != PL_OK) return rc;
                   return write_char(s, A[1]); }

BI(bi_at_end_of_stream) { UNUSED; RET(stream_at_end(stream_current_input())); }

BI(bi_at_end_of_stream1)
{
    UNUSED;
    PStream *s;
    int rc = input_stream_arg(A[0], &s);
    if (rc != PL_OK) return rc;
    RET(stream_at_end(s));
}

BI(bi_flush_output)
{
    UNUSED;
    FILE *f = stream_file(stream_current_output());
    fflush(f ? f : stdout);
    return PL_OK;
}

BI(bi_halt)  { UNUSED; m_halt = 1; m_halt_code = 0; return PL_HALT; }
BI(bi_halt1) { UNUSED; long long c; int rc = get_int(A[0], &c);
               if (rc != PL_OK) return rc;
               m_halt = 1; m_halt_code = (int)c; return PL_HALT; }

/* ------------------------------------------------------------------ */
/* format/1,2,3                                                       */
/* ------------------------------------------------------------------ */

typedef struct {
    char  *buf;
    size_t len, cap;
    size_t line_start;      /* offset of the current line                */
    size_t seg_start;       /* offset where the current column segment began */
    struct { size_t pos; char fill; } fills[16];
    int    nfills;
} FBuf;

static void fb_put(FBuf *b, const char *s, size_t n)
{
    size_t i;
    if (b->len + n + 1 > b->cap) {
        while (b->len + n + 1 > b->cap) b->cap = b->cap ? b->cap * 2 : 256;
        b->buf = (char *)realloc(b->buf, b->cap);
    }
    memcpy(b->buf + b->len, s, n);
    b->len += n;
    b->buf[b->len] = 0;
    for (i = b->len - n; i < b->len; i++)
        if (b->buf[i] == '\n') {
            b->line_start = i + 1;
            b->seg_start = i + 1;
            b->nfills = 0;
        }
}

static void fb_puts(FBuf *b, const char *s) { fb_put(b, s, strlen(s)); }

static size_t fb_column(FBuf *b)
{
    return utf8_len(b->buf + b->line_start, b->len - b->line_start);
}

static void fb_column_stop(FBuf *b, size_t target)
{
    size_t col = fb_column(b);
    size_t pad, i;

    if (col >= target) { b->seg_start = b->len; b->nfills = 0; return; }
    pad = target - col;
    if (b->nfills == 0) {
        for (i = 0; i < pad; i++) fb_put(b, " ", 1);
    } else {
        int k;
        size_t base = pad / (size_t)b->nfills, extra = pad % (size_t)b->nfills;
        /* Insert from the rightmost fill point so earlier offsets stay valid. */
        for (k = b->nfills - 1; k >= 0; k--) {
            size_t n = base + (k == b->nfills - 1 ? extra : 0);
            size_t at = b->fills[k].pos;
            char fill = b->fills[k].fill;
            if (!n) continue;
            if (b->len + n + 1 > b->cap) {
                while (b->len + n + 1 > b->cap) b->cap = b->cap ? b->cap * 2 : 256;
                b->buf = (char *)realloc(b->buf, b->cap);
            }
            memmove(b->buf + at + n, b->buf + at, b->len - at);
            memset(b->buf + at, fill, n);
            b->len += n;
            b->buf[b->len] = 0;
        }
    }
    b->seg_start = b->len;
    b->nfills = 0;
}

static int fmt_next_arg(Term **args, Term **out)
{
    Term *l = deref(*args);
    if (l->tag == TAG_STR && FN(l) == a_dot && AR(l) == 2) {
        *out = deref(ARG(l, 0));
        *args = deref(ARG(l, 1));
        return PL_OK;
    }
    return pl_throw(mk1(intern("format"),
                        mk_atom_str("not enough arguments")));
}

static void fb_write_term(FBuf *b, Term *t, int flags)
{
    size_t n;
    char *s = term_to_string(t, flags, &n);
    fb_put(b, s, n);
    free(s);
}

static int do_format(FBuf *b, const char *f, size_t flen, Term *args)
{
    size_t i = 0;
    int rc;

    while (i < flen) {
        char c = f[i++];
        long long num = -1;
        int have_num = 0;
        char fillchar = ' ';

        if (c != '~') { fb_put(b, &c, 1); continue; }
        if (i >= flen) break;
        /* Optional numeric / character / star argument. */
        if (f[i] == '`') { fillchar = f[i + 1]; i += 2; have_num = 1; num = (unsigned char)fillchar; }
        else if (f[i] == '*') {
            Term *a;
            i++;
            if ((rc = fmt_next_arg(&args, &a)) != PL_OK) return rc;
            if (a->tag != TAG_INT) return type_error("integer", a);
            num = IV(a);
            have_num = 1;
        } else if (isdigit((unsigned char)f[i])) {
            num = 0;
            while (i < flen && isdigit((unsigned char)f[i]))
                num = num * 10 + (f[i++] - '0');
            have_num = 1;
        }
        if (i >= flen) break;
        c = f[i++];
        switch (c) {
        case 'w': case 'p': case 'q': {
            Term *a;
            if ((rc = fmt_next_arg(&args, &a)) != PL_OK) return rc;
            fb_write_term(b, a, c == 'w' ? WR_NUMBERVARS
                                         : WR_NUMBERVARS | WR_QUOTED);
            break;
        }
        case 'a': {
            Term *a;
            char *s;
            size_t n;
            if ((rc = fmt_next_arg(&args, &a)) != PL_OK) return rc;
            if (a->tag == TAG_VAR) return instantiation_error();
            if (!text_of(a, &s, &n)) return type_error("atom", a);
            fb_put(b, s, n);
            free(s);
            break;
        }
        case 's': {
            Term *a;
            char *s;
            size_t n;
            if ((rc = fmt_next_arg(&args, &a)) != PL_OK) return rc;
            if (!text_of(a, &s, &n)) return type_error("text", a);
            fb_put(b, s, n);
            free(s);
            break;
        }
        case 'd': case 'D': {
            Term *a, *v;
            char tmp[64];
            if ((rc = fmt_next_arg(&args, &a)) != PL_OK) return rc;
            if (arith_eval(a, &v) != PL_OK) return PL_ERROR;
            if (v->tag != TAG_INT) return type_error("integer", v);
            snprintf(tmp, sizeof(tmp), "%lld", IV(v) < 0 ? -IV(v) : IV(v));
            {
                char out[128];
                size_t k = 0, dlen = strlen(tmp), j;
                size_t decimals = (c == 'd' && have_num) ? (size_t)num : 0;
                size_t group = (c == 'D') ? 3 : 0;
                if (IV(v) < 0) out[k++] = '-';
                if (decimals) {
                    /* Insert a decimal point `decimals` digits from the right. */
                    if (dlen <= decimals) {
                        out[k++] = '0';
                        out[k++] = '.';
                        for (j = dlen; j < decimals; j++) out[k++] = '0';
                        memcpy(out + k, tmp, dlen);
                        k += dlen;
                    } else {
                        memcpy(out + k, tmp, dlen - decimals);
                        k += dlen - decimals;
                        out[k++] = '.';
                        memcpy(out + k, tmp + dlen - decimals, decimals);
                        k += decimals;
                    }
                } else if (group) {
                    for (j = 0; j < dlen; j++) {
                        if (j && (dlen - j) % group == 0) out[k++] = ',';
                        out[k++] = tmp[j];
                    }
                } else {
                    memcpy(out + k, tmp, dlen);
                    k += dlen;
                }
                out[k] = 0;
                fb_put(b, out, k);
            }
            break;
        }
        case 'f': case 'e': case 'g': {
            Term *a, *v;
            char spec[16], tmp[512];
            double d;
            if ((rc = fmt_next_arg(&args, &a)) != PL_OK) return rc;
            if (arith_eval(a, &v) != PL_OK) return PL_ERROR;
            d = v->tag == TAG_INT ? (double)IV(v) : FV(v);
            snprintf(spec, sizeof(spec), "%%.%d%c", have_num ? (int)num : 6, c);
            snprintf(tmp, sizeof(tmp), spec, d);
            fb_puts(b, tmp);
            break;
        }
        case 'c': {
            Term *a;
            long long k, reps = have_num ? num : 1;
            if ((rc = fmt_next_arg(&args, &a)) != PL_OK) return rc;
            if (a->tag != TAG_INT) return type_error("integer", a);
            for (k = 0; k < reps; k++) {
                char ch = (char)IV(a);
                fb_put(b, &ch, 1);
            }
            break;
        }
        case 'r': case 'R': {
            Term *a, *v;
            long long base = have_num ? num : 8;
            char tmp[80];
            int k = 0, neg = 0;
            long long x;
            if ((rc = fmt_next_arg(&args, &a)) != PL_OK) return rc;
            if (arith_eval(a, &v) != PL_OK) return PL_ERROR;
            if (v->tag != TAG_INT) return type_error("integer", v);
            if (base < 2 || base > 36) return domain_error("radix", mk_int(base));
            x = IV(v);
            if (x < 0) { neg = 1; x = -x; }
            if (!x) tmp[k++] = '0';
            while (x) {
                int d = (int)(x % base);
                tmp[k++] = (char)(d < 10 ? '0' + d
                                         : (c == 'r' ? 'a' : 'A') + d - 10);
                x /= base;
            }
            if (neg) tmp[k++] = '-';
            while (k--) fb_put(b, &tmp[k], 1);
            break;
        }
        case 'n': {
            long long k, reps = have_num ? num : 1;
            for (k = 0; k < reps; k++) fb_put(b, "\n", 1);
            break;
        }
        case 'i': {
            Term *a;
            if ((rc = fmt_next_arg(&args, &a)) != PL_OK) return rc;
            break;
        }
        case 't':
            if (b->nfills < 16) {
                b->fills[b->nfills].pos = b->len;
                b->fills[b->nfills].fill = have_num ? (char)num : ' ';
                b->nfills++;
            }
            break;
        case '|':
            fb_column_stop(b, have_num ? (size_t)num : fb_column(b));
            break;
        case '+':
            fb_column_stop(b, utf8_len(b->buf + b->line_start,
                                       b->seg_start - b->line_start) +
                              (have_num ? (size_t)num : 8));
            break;
        case '~':
            fb_put(b, "~", 1);
            break;
        default: {
            char msg[64];
            snprintf(msg, sizeof(msg), "unknown directive ~%c", c);
            return pl_throw(mk1(intern("format"), mk_atom_str(msg)));
        }
        }
    }
    return PL_OK;
}

static int format_run(PStream *out, Term *fmt, Term *args, Term **text)
{
    FBuf b;
    char *f;
    size_t flen;
    Term *l = deref(args);
    int rc;

    if ((rc = get_text(fmt, &f, &flen, "text")) != PL_OK) return rc;
    /* A non-list argument is treated as a single argument. */
    if (!(l->tag == TAG_ATOM && AT(l) == a_nil) &&
        !(l->tag == TAG_STR && FN(l) == a_dot && AR(l) == 2))
        l = mk_cons(l, mk_atom(a_nil));

    memset(&b, 0, sizeof(b));
    b.cap = 256;
    b.buf = (char *)malloc(b.cap);
    b.buf[0] = 0;
    rc = do_format(&b, f, flen, l);
    free(f);
    if (rc != PL_OK) { free(b.buf); return rc; }
    if (out) stream_write(out, b.buf, b.len);
    if (text) *text = mk_codes(b.buf, b.len);
    free(b.buf);
    return PL_OK;
}

BI(bi_format1) { UNUSED; return format_run(stream_current_output(), A[0],
                                           mk_atom(a_nil), NULL); }
BI(bi_format2) { UNUSED; return format_run(stream_current_output(), A[0], A[1], NULL); }

BI(bi_format3)
{
    UNUSED;
    Term *sink = deref(A[0]);
    PStream *s;

    if (sink->tag == TAG_STR && AR(sink) == 1) {
        const char *kind = atom_name(FN(sink));
        Term *text;
        int rc;
        char *raw;
        size_t n;
        if (!strcmp(kind, "atom") || !strcmp(kind, "string") ||
            !strcmp(kind, "codes") || !strcmp(kind, "chars")) {
            rc = format_run(NULL, A[1], A[2], &text);
            if (rc != PL_OK) return rc;
            if (!text_of(text, &raw, &n)) return PL_FAIL;
            if (!strcmp(kind, "codes")) rc = unify(ARG(sink, 0), mk_codes(raw, n));
            else if (!strcmp(kind, "chars")) rc = unify(ARG(sink, 0), mk_chars(raw, n));
            else rc = unify(ARG(sink, 0), mk_atom(intern_n(raw, n)));
            free(raw);
            RET(rc);
        }
    }
    {
        int rc = stream_arg(A[0], &s);
        if (rc != PL_OK) return rc;
    }
    return format_run(s, A[1], A[2], NULL);
}

/* ------------------------------------------------------------------ */
/* Streams                                                            */
/* ------------------------------------------------------------------ */

/* open/4's options, all checked before the file is touched.  alias/1 and
   eof_action/1 are honoured.  type(text) and reposition(false) describe
   every stream here, so they are accepted; type(binary) and
   reposition(true) ask for byte input and seeking, which this stream
   layer does not have, and are refused with the permission error ISO
   gives for reposition(true). */
static int open_opts(Term *opts, int *alias, int *eof_action)
{
    Term *l = deref(opts);
    *alias = -1;
    *eof_action = EOF_ERROR;
    while (l->tag == TAG_STR && FN(l) == a_dot && AR(l) == 2) {
        Term *o = deref(ARG(l, 0)), *v;
        const char *nm, *vn;
        if (o->tag == TAG_VAR) return instantiation_error();
        if (o->tag != TAG_STR || AR(o) != 1)
            return domain_error("stream_option", o);
        nm = atom_name(FN(o));
        v = deref(ARG(o, 0));
        if (v->tag == TAG_VAR) return instantiation_error();
        if (v->tag != TAG_ATOM) return domain_error("stream_option", o);
        vn = atom_name(AT(v));
        if (!strcmp(nm, "alias")) {
            if (stream_of(v)) return permission_error("open", "source_sink", o);
            *alias = AT(v);
        } else if (!strcmp(nm, "eof_action")) {
            if (!strcmp(vn, "error")) *eof_action = EOF_ERROR;
            else if (!strcmp(vn, "eof_code")) *eof_action = EOF_CODE;
            else if (!strcmp(vn, "reset")) *eof_action = EOF_RESET;
            else return domain_error("stream_option", o);
        } else if (!strcmp(nm, "type")) {
            if (!strcmp(vn, "binary"))
                return permission_error("open", "source_sink", o);
            if (strcmp(vn, "text")) return domain_error("stream_option", o);
        } else if (!strcmp(nm, "reposition")) {
            if (!strcmp(vn, "true"))
                return permission_error("open", "source_sink", o);
            if (strcmp(vn, "false")) return domain_error("stream_option", o);
        } else return domain_error("stream_option", o);
        l = deref(ARG(l, 1));
    }
    if (l->tag == TAG_VAR) return instantiation_error();
    if (!(l->tag == TAG_ATOM && AT(l) == a_nil)) return type_error("list", deref(opts));
    return PL_OK;
}

static int open_stream(Term **A, Term *opts)
{
    char *path;
    size_t n;
    int mode, rc, alias = -1, eof_action = EOF_ERROR;
    PStream *s;
    const char *m;

    if ((rc = get_text(A[0], &path, &n, "atom")) != PL_OK) return rc;
    if ((rc = get_atom(A[1], &mode)) != PL_OK) { free(path); return rc; }
    m = atom_name(mode);
    if (strcmp(m, "read") && strcmp(m, "write") && strcmp(m, "append")) {
        free(path);
        return domain_error("io_mode", deref(A[1]));
    }
    if (opts && (rc = open_opts(opts, &alias, &eof_action)) != PL_OK) {
        free(path);
        return rc;
    }
    if (!strcmp(m, "read")) s = stream_open(path, "r", 1);
    else if (!strcmp(m, "write")) s = stream_open(path, "w", 0);
    else s = stream_open(path, "a", 0);
    if (!s) {
        Term *culprit = mk_atom_str(path);
        free(path);
        return existence_error("source_sink", culprit);
    }
    free(path);
    if (alias >= 0) stream_set_alias(s, alias);
    stream_set_eof_action(s, eof_action);
    RET(unify(A[2], stream_term(s)));
}

BI(bi_open3) { UNUSED; return open_stream(A, NULL); }
BI(bi_open4) { UNUSED; return open_stream(A, A[3]); }

BI(bi_close)
{
    UNUSED;
    PStream *s;
    int rc = stream_arg(A[0], &s);
    if (rc != PL_OK) return rc;
    stream_close(s);
    return PL_OK;
}

BI(bi_current_output) { UNUSED; RET(unify(A[0], stream_term(stream_current_output()))); }
BI(bi_current_input)  { UNUSED; RET(unify(A[0], stream_term(stream_current_input()))); }

BI(bi_set_output)
{
    UNUSED;
    PStream *s;
    int rc = stream_arg(A[0], &s);
    if (rc != PL_OK) return rc;
    stream_set_output(s);
    return PL_OK;
}

BI(bi_set_input)
{
    UNUSED;
    PStream *s;
    int rc = stream_arg(A[0], &s);
    if (rc != PL_OK) return rc;
    stream_set_input(s);
    return PL_OK;
}

/* with_output_to(+Sink, :Goal) */
BI(bi_with_output_to)
{
    UNUSED;
    Term *sink = deref(A[0]);
    PStream *saved = stream_current_output();
    PStream *tmp;
    int rc;
    const char *kind;

    if (sink->tag != TAG_STR || AR(sink) != 1)
        return domain_error("output_sink", sink);
    kind = atom_name(FN(sink));
    tmp = stream_open_sink();
    if (!tmp) return pl_throw(mk_atom_str("resource_error(streams)"));
    stream_set_output(tmp);
    rc = solve_once(A[1]);
    stream_set_output(saved);
    if (rc == PL_OK) {
        size_t n;
        const char *text = stream_sink_text(tmp, &n);
        Term *result;
        if (!strcmp(kind, "codes")) result = mk_codes(text, n);
        else if (!strcmp(kind, "chars")) result = mk_chars(text, n);
        else result = mk_atom(intern_n(text, n));
        rc = unify(ARG(sink, 0), result) ? PL_OK : PL_FAIL;
    }
    stream_close(tmp);
    return rc;
}

static int read_opts(Term *opts, Term *varnames, Term *singles, Term *vars)
{
    Term *l = deref(opts);
    while (l->tag == TAG_STR && FN(l) == a_dot && AR(l) == 2) {
        Term *o = deref(ARG(l, 0));
        if (o->tag == TAG_STR && AR(o) == 1) {
            const char *nm = atom_name(FN(o));
            if (!strcmp(nm, "variable_names") || !strcmp(nm, "bindings")) {
                if (!unify(ARG(o, 0), varnames)) return PL_FAIL;
            } else if (!strcmp(nm, "variables")) {
                int n, ok;
                Term **vs = term_variables(vars, &n);
                ok = unify(ARG(o, 0), list_from_array(vs, n));
                free(vs);
                if (!ok) return PL_FAIL;
            } else if (!strcmp(nm, "singletons")) {
                if (!unify(ARG(o, 0), singles)) return PL_FAIL;
            }
        }
        l = deref(ARG(l, 1));
    }
    return PL_OK;
}

static int read_from_stream(PStream *s, Term *given, Term *out, Term *opts)
{
    Reader *r = stream_reader(s);
    Term *t, *names, *singles;
    int rc = check_read(s, given);
    if (rc == PL_FAIL) {
        t = mk_atom(a_end_of_file);
        names = singles = mk_atom(a_nil);
    } else if (rc != PL_OK) return rc;
    else {
        rc = read_term_full(r, &t, &names, &singles);
        if (rc < 0) return PL_ERROR;
        if (rc == 0) stream_set_past(s);
    }
    if (opts) {
        rc = read_opts(opts, names, singles, t);
        if (rc != PL_OK) return rc;
    }
    RET(unify(out, t));
}

BI(bi_read)  { UNUSED; return read_from_stream(stream_current_input(), NULL, A[0], NULL); }
BI(bi_read2) { UNUSED; PStream *s; int rc = input_stream_arg(A[0], &s);
               if (rc != PL_OK) return rc;
               return read_from_stream(s, A[0], A[1], NULL); }
BI(bi_read_term2) { UNUSED; return read_from_stream(stream_current_input(), NULL, A[0], A[1]); }
BI(bi_read_term3) { UNUSED; PStream *s; int rc = input_stream_arg(A[0], &s);
                    if (rc != PL_OK) return rc;
                    return read_from_stream(s, A[0], A[1], A[2]); }

/* ------------------------------------------------------------------ */
/* Flags, operators, statistics                                       */
/* ------------------------------------------------------------------ */

BI(bi_set_prolog_flag)
{
    UNUSED;
    int f, v;
    int rc = get_atom(A[0], &f);
    const char *nm, *val;
    if (rc != PL_OK) return rc;
    if ((rc = get_atom(A[1], &v)) != PL_OK) return rc;
    nm = atom_name(f);
    val = atom_name(v);
    if (!strcmp(nm, "double_quotes")) {
        if (!strcmp(val, "codes")) m_flag_double_quotes = DQ_CODES;
        else if (!strcmp(val, "chars")) m_flag_double_quotes = DQ_CHARS;
        else if (!strcmp(val, "atom")) m_flag_double_quotes = DQ_ATOM;
        else return domain_error("flag_value", deref(A[1]));
        return PL_OK;
    }
    if (!strcmp(nm, "unknown")) {
        if (!strcmp(val, "error")) m_flag_unknown_error = 1;
        else if (!strcmp(val, "fail")) m_flag_unknown_error = 0;
        else return domain_error("flag_value", deref(A[1]));
        return PL_OK;
    }
    return domain_error("prolog_flag", deref(A[0]));
}

/* '$flag'(+Name, -Value) */
BI(bi_flag)
{
    UNUSED;
    int f;
    int rc = get_atom(A[0], &f);
    const char *nm;
    if (rc != PL_OK) return rc;
    nm = atom_name(f);
    if (!strcmp(nm, "bounded")) RET(unify(A[1], mk_atom(a_true)));
    if (!strcmp(nm, "max_integer")) RET(unify(A[1], mk_int(LLONG_MAX)));
    if (!strcmp(nm, "min_integer")) RET(unify(A[1], mk_int(LLONG_MIN)));
    if (!strcmp(nm, "double_quotes"))
        RET(unify(A[1], mk_atom_str(m_flag_double_quotes == DQ_CODES ? "codes" :
                                    m_flag_double_quotes == DQ_CHARS ? "chars" : "atom")));
    if (!strcmp(nm, "unknown"))
        RET(unify(A[1], mk_atom_str(m_flag_unknown_error ? "error" : "fail")));
    if (!strcmp(nm, "dialect")) RET(unify(A[1], mk_atom_str("ariadne")));
    if (!strcmp(nm, "version")) RET(unify(A[1], mk_int(10000)));
    if (!strcmp(nm, "max_arity")) RET(unify(A[1], mk_int(MAX_ARITY)));
    return PL_FAIL;
}

static int op_type_of(const char *s)
{
    if (!strcmp(s, "xfx")) return OP_XFX;
    if (!strcmp(s, "xfy")) return OP_XFY;
    if (!strcmp(s, "yfx")) return OP_YFX;
    if (!strcmp(s, "fy")) return OP_FY;
    if (!strcmp(s, "fx")) return OP_FX;
    if (!strcmp(s, "xf")) return OP_XF;
    if (!strcmp(s, "yf")) return OP_YF;
    return 0;
}

BI(bi_op)
{
    UNUSED;
    long long prec;
    int type, rc;
    Term *names = deref(A[2]);
    int t;

    if ((rc = get_int(A[0], &prec)) != PL_OK) return rc;
    if ((rc = get_atom(A[1], &t)) != PL_OK) return rc;
    type = op_type_of(atom_name(t));
    if (!type) return domain_error("operator_specifier", deref(A[1]));
    if (prec < 0 || prec > 1200) return domain_error("operator_priority", deref(A[0]));

    if (names->tag == TAG_STR && FN(names) == a_dot && AR(names) == 2) {
        while (names->tag == TAG_STR && FN(names) == a_dot && AR(names) == 2) {
            Term *nm = deref(ARG(names, 0));
            if (nm->tag != TAG_ATOM) return type_error("atom", nm);
            if (AT(nm) == a_comma) return permission_error("modify", "operator", nm);
            op_define((int)prec, type, AT(nm));
            names = deref(ARG(names, 1));
        }
        return PL_OK;
    }
    if (names->tag == TAG_VAR) return instantiation_error();
    if (names->tag != TAG_ATOM) return type_error("atom", names);
    if (AT(names) == a_comma) return permission_error("modify", "operator", names);
    op_define((int)prec, type, AT(names));
    return PL_OK;
}

/* '$op_list'(-List): all current operators as op(Priority, Type, Name). */
BI(bi_op_list)
{
    UNUSED;
    Term **buf;
    int i = 0, n = 0, cap = 128;
    int prec = 0, type = 0, atom = 0;
    int f_op = intern("op");

    buf = (Term **)malloc((size_t)cap * sizeof(Term *));
    while (op_enumerate(i++, &prec, &type, &atom)) {
        if (!prec) continue;
        if (n == cap) { cap *= 2; buf = (Term **)realloc(buf, (size_t)cap * sizeof(Term *)); }
        buf[n++] = mk3(f_op, mk_int(prec), mk_atom_str(op_type_name(type)),
                       mk_atom(atom));
    }
    {
        Term *l = list_from_array(buf, n);
        free(buf);
        RET(unify(A[0], l));
    }
}

BI(bi_statistics)
{
    UNUSED;
    int k;
    int rc = get_atom(A[0], &k);
    const char *nm;
    long long v;
    static long long last_runtime;

    if (rc != PL_OK) return rc;
    nm = atom_name(k);
    if (!strcmp(nm, "runtime") || !strcmp(nm, "cputime") ||
        !strcmp(nm, "process_cputime") || !strcmp(nm, "walltime")) {
        long long now = (long long)((double)clock() * 1000.0 / (double)CLOCKS_PER_SEC);
        Term *l = mk_cons(mk_int(now), mk_cons(mk_int(now - last_runtime),
                                               mk_atom(a_nil)));
        last_runtime = now;
        RET(unify(A[1], l));
    }
    if (!strcmp(nm, "inferences")) {
        v = m_inferences;
        RET(unify(A[1], mk_int(v)));
    }
    if (!strcmp(nm, "retained_clauses")) {
        /* Retracted clauses still held for a choice point that may reach them. */
        RET(unify(A[1], mk_int(m_clauses_retained)));
    }
    if (!strcmp(nm, "garbage_collection")) {
        /* [Collections, BytesFreed, Milliseconds], as SWI has it. */
        Term *l = mk_cons(mk_int(m_gc_count), mk_cons(mk_int(m_gc_freed),
                          mk_cons(mk_int(m_gc_msecs), mk_atom(a_nil))));
        RET(unify(A[1], l));
    }
    if (!strcmp(nm, "memory") || !strcmp(nm, "heap")) {
        Term *l = mk_cons(mk_int((long long)heap_in_use()),
                          mk_cons(mk_int(0), mk_atom(a_nil)));
        RET(unify(A[1], l));
    }
    return domain_error("statistics_key", deref(A[0]));
}

BI(bi_garbage_collect) { UNUSED; return PL_OK; }

/* '$print_error'(+Ball): prints an exception the way the toplevel does. */
BI(bi_print_error)
{
    UNUSED;
    fprintf(stderr, "ERROR: ");
    print_error_term(stderr, deref(A[0]));
    return PL_OK;
}

/* ------------------------------------------------------------------ */
/* Consulting                                                         */
/* ------------------------------------------------------------------ */

/* Builds a file name from an atom or from the a/b/c path notation. */
static int path_text(Term *t, char **out, size_t *len)
{
    t = deref(t);
    if (t->tag == TAG_STR && FN(t) == a_slash && AR(t) == 2) {
        char *l, *r, *both;
        size_t ln, rn;
        if (path_text(ARG(t, 0), &l, &ln) != PL_OK) return PL_ERROR;
        if (path_text(ARG(t, 1), &r, &rn) != PL_OK) { free(l); return PL_ERROR; }
        both = (char *)malloc(ln + rn + 2);
        memcpy(both, l, ln);
        both[ln] = '/';
        memcpy(both + ln + 1, r, rn + 1);
        free(l);
        free(r);
        *out = both;
        *len = ln + rn + 1;
        return PL_OK;
    }
    return get_text(t, out, len, "atom");
}

static int consult_term(Term *t)
{
    char *path;
    size_t n;
    int rc;
    Term *d = deref(t);

    if (d->tag == TAG_ATOM && AT(d) == a_nil) return PL_OK;   /* end of list */

    if (d->tag == TAG_STR && FN(d) == a_dot && AR(d) == 2) {
        /* A list of files. */
        while (d->tag == TAG_STR && FN(d) == a_dot && AR(d) == 2) {
            if ((rc = consult_term(ARG(d, 0))) != PL_OK) return rc;
            d = deref(ARG(d, 1));
        }
        return PL_OK;
    }
    if ((rc = path_text(d, &path, &n)) != PL_OK) return rc;
    rc = consult_file(path);
    if (rc != PL_OK) {
        Term *culprit = mk_atom_str(path);
        free(path);
        if (rc == PL_ERROR) return PL_ERROR;
        return existence_error("source_sink", culprit);
    }
    free(path);
    return PL_OK;
}

BI(bi_consult) { UNUSED; return consult_term(A[0]); }

/* '.'(File, Rest) as a goal: the [file1, file2] notation. */
BI(bi_consult_list)
{
    UNUSED;
    int rc = consult_term(A[0]);
    if (rc != PL_OK) return rc;
    return consult_term(A[1]);
}

/* ------------------------------------------------------------------ */
/* Registration                                                       */
/* ------------------------------------------------------------------ */

typedef struct { const char *name; int arity; BiFn fn; } BiEntry;

static const BiEntry bi_table[] = {
    /* type checking */
    { "var", 1, bi_var }, { "nonvar", 1, bi_nonvar }, { "atom", 1, bi_atom },
    { "number", 1, bi_number }, { "integer", 1, bi_integer },
    { "float", 1, bi_float }, { "compound", 1, bi_compound },
    { "callable", 1, bi_callable }, { "atomic", 1, bi_atomic },
    { "is_list", 1, bi_is_list }, { "ground", 1, bi_ground },
    /* unification and comparison */
    { "=", 2, bi_unify }, { "\\=", 2, bi_not_unify },
    { "unify_with_occurs_check", 2, bi_unify_oc },
    { "==", 2, bi_eq }, { "\\==", 2, bi_neq },
    { "=@=", 2, bi_variant }, { "\\=@=", 2, bi_not_variant },
    { "@<", 2, bi_lt }, { "@>", 2, bi_gt },
    { "@=<", 2, bi_le }, { "@>=", 2, bi_ge },
    { "compare", 3, bi_compare },
    /* arithmetic */
    { "is", 2, bi_is }, { "=:=", 2, bi_num_eq }, { "=\\=", 2, bi_num_ne },
    { "<", 2, bi_num_lt }, { ">", 2, bi_num_gt },
    { "=<", 2, bi_num_le }, { ">=", 2, bi_num_ge },
    { "succ", 2, bi_succ }, { "plus", 3, bi_plus },
    { "between", 3, bi_between }, { "repeat", 0, bi_repeat },
    /* terms */
    { "functor", 3, bi_functor }, { "arg", 3, bi_arg }, { "=..", 2, bi_univ },
    { "copy_term", 2, bi_copy_term }, { "term_variables", 2, bi_term_variables },
    { "numbervars", 3, bi_numbervars }, { "setarg", 3, bi_setarg },
    /* atoms and text */
    { "atom_length", 2, bi_atom_length }, { "atom_codes", 2, bi_atom_codes },
    { "atom_chars", 2, bi_atom_chars }, { "char_code", 2, bi_char_code },
    { "number_codes", 2, bi_number_codes }, { "number_chars", 2, bi_number_chars },
    { "atom_number", 2, bi_atom_number }, { "$atom_concat", 3, bi_atom_concat3 }, { "$join", 3, bi_join3 }, { "$split_atom", 3, bi_split_atom3 },
    { "$sub_atom", 4, bi_sub_atom4 }, { "upcase_atom", 2, bi_upcase },
    { "downcase_atom", 2, bi_downcase }, { "term_to_atom", 2, bi_term_to_atom },
    { "atom_to_term", 3, bi_atom_to_term },
    /* findall and sorting */
    { "findall", 3, bi_findall }, { "findall", 4, bi_findall4 },
    { "$findnsols", 4, bi_findnsols },
    { "msort", 2, bi_msort }, { "sort", 2, bi_sort }, { "sort", 4, bi_sort4 },
    { "keysort", 2, bi_keysort },
    { "$skip_list", 3, bi_skip_list }, { "$make_list", 2, bi_make_list },
    /* database */
    { "assert", 1, bi_assertz }, { "assertz", 1, bi_assertz },
    { "asserta", 1, bi_asserta }, { "retract", 1, bi_retract },
    { "retractall", 1, bi_retractall }, { "clause", 2, bi_clause },
    { "dynamic", 1, bi_dynamic }, { "discontiguous", 1, bi_discontiguous },
    { "multifile", 1, bi_multifile },
    { "abolish", 1, bi_abolish },
    { "$defined", 1, bi_predicate_defined }, { "$predicates", 1, bi_predicates },
    { "$clauses", 2, bi_clauses },
    { "nb_setval", 2, bi_nb_setval }, { "nb_getval", 2, bi_nb_getval },
    { "b_setval", 2, bi_nb_setval }, { "b_getval", 2, bi_nb_getval },
    /* output */
    { "write", 1, bi_write }, { "write", 2, bi_write2 },
    { "print", 1, bi_print }, { "print", 2, bi_print2 },
    { "writeq", 1, bi_writeq }, { "writeq", 2, bi_writeq2 },
    { "write_canonical", 1, bi_write_canonical },
    { "write_canonical", 2, bi_write_canonical2 },
    { "write_term", 2, bi_write_term }, { "write_term", 3, bi_write_term3 },
    { "writeln", 1, bi_writeln }, { "writeln", 2, bi_writeln2 },
    { "nl", 0, bi_nl }, { "nl", 1, bi_nl1 },
    { "tab", 1, bi_tab },
    { "put_char", 1, bi_put_char }, { "put_char", 2, bi_put_char2 },
    { "flush_output", 0, bi_flush_output },
    { "halt", 0, bi_halt }, { "halt", 1, bi_halt1 },
    { "format", 1, bi_format1 }, { "format", 2, bi_format2 },
    { "format", 3, bi_format3 },
    /* streams */
    { "open", 3, bi_open3 }, { "open", 4, bi_open4 }, { "close", 1, bi_close },
    { "current_output", 1, bi_current_output },
    { "current_input", 1, bi_current_input },
    { "set_output", 1, bi_set_output }, { "set_input", 1, bi_set_input },
    { "with_output_to", 2, bi_with_output_to },
    { "read", 1, bi_read }, { "read", 2, bi_read2 },
    { "read_term", 2, bi_read_term2 }, { "read_term", 3, bi_read_term3 },
    { "get_char", 1, bi_get_char }, { "get_char", 2, bi_get_char2 },
    { "peek_char", 1, bi_peek_char }, { "peek_char", 2, bi_peek_char2 },
    { "read_line_to_string", 2, bi_read_line_to_string },
    { "read_line_to_codes", 2, bi_read_line_to_codes },
    { "at_end_of_stream", 0, bi_at_end_of_stream },
    { "at_end_of_stream", 1, bi_at_end_of_stream1 },
    /* flags, operators, misc */
    { "set_prolog_flag", 2, bi_set_prolog_flag }, { "$flag", 2, bi_flag },
    { "op", 3, bi_op }, { "$op_list", 1, bi_op_list },
    { "statistics", 2, bi_statistics },
    { "garbage_collect", 0, bi_garbage_collect },
    { "$print_error", 1, bi_print_error },
    { "consult", 1, bi_consult }, { "ensure_loaded", 1, bi_consult },
    { ".", 2, bi_consult_list },
    { NULL, 0, NULL }
};

typedef struct BiSlot { struct BiSlot *next; int functor, arity; BiFn fn; } BiSlot;

#define BI_BUCKETS 512
static BiSlot *bi_hash[BI_BUCKETS];

void builtins_init(void)
{
    int i;
    memset(bi_hash, 0, sizeof(bi_hash));
    for (i = 0; bi_table[i].name; i++) {
        int f = intern(bi_table[i].name);
        unsigned h = ((unsigned)f * 31u + (unsigned)bi_table[i].arity) % BI_BUCKETS;
        BiSlot *s = (BiSlot *)malloc(sizeof(BiSlot));
        s->functor = f;
        s->arity = bi_table[i].arity;
        s->fn = bi_table[i].fn;
        s->next = bi_hash[h];
        bi_hash[h] = s;
    }
}

BiFn builtin_lookup(int functor, int arity)
{
    unsigned h = ((unsigned)functor * 31u + (unsigned)arity) % BI_BUCKETS;
    BiSlot *s;
    for (s = bi_hash[h]; s; s = s->next)
        if (s->functor == functor && s->arity == arity) return s->fn;
    return NULL;
}

int builtin_exists(int functor, int arity)
{
    return builtin_lookup(functor, arity) != NULL;
}
