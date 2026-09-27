/* db.c -- the clause database. */
#include "prolog.h"

#define PRED_BUCKETS 1024

static Pred *preds[PRED_BUCKETS];

static unsigned pred_hash(int functor, int arity)
{
    return ((unsigned)functor * 31u + (unsigned)arity) % PRED_BUCKETS;
}

void db_init(void)
{
    memset(preds, 0, sizeof(preds));
}

Pred *pred_lookup(int functor, int arity, int create)
{
    unsigned h = pred_hash(functor, arity);
    Pred *p;

    for (p = preds[h]; p; p = p->next)
        if (p->functor == functor && p->arity == arity) return p;
    if (!create) return NULL;
    p = (Pred *)calloc(1, sizeof(Pred));
    p->functor = functor;
    p->arity = arity;
    p->next = preds[h];
    preds[h] = p;
    return p;
}

int pred_enumerate(int i, Pred **out)
{
    int b, n = 0;
    Pred *p;
    for (b = 0; b < PRED_BUCKETS; b++)
        for (p = preds[b]; p; p = p->next)
            if (n++ == i) { *out = p; return 1; }
    return 0;
}

/* Marks every predicate defined so far as the library's: called once,
   when lib/boot.pl has been loaded. */
void pred_mark_library(void)
{
    int b;
    Pred *p;
    for (b = 0; b < PRED_BUCKETS; b++)
        for (p = preds[b]; p; p = p->next)
            if (p->defined || p->dynamic) p->library = 1;
}

/* ---- first argument indexing ---- */

static void clause_index(Clause *c)
{
    Term *h = c->head, *a;

    c->first_arg_tag = -1;
    c->first_arg_key = 0;
    if (h->tag != TAG_STR || AR(h) == 0) return;
    a = ARG(h, 0);
    while (a->tag == TAG_VAR && a->u.v.ref) a = a->u.v.ref;
    switch (a->tag) {
    case TAG_ATOM: c->first_arg_tag = TAG_ATOM; c->first_arg_key = AT(a); break;
    case TAG_INT:  c->first_arg_tag = TAG_INT;  c->first_arg_key = (int)IV(a); break;
    case TAG_STR:  c->first_arg_tag = TAG_STR;
                   c->first_arg_key = FN(a) * 64 + AR(a); break;
    default: break;               /* variables and floats are not indexed */
    }
}

int clause_may_match(Clause *c, Term *goal)
{
    Term *a;
    int tag, key;

    if (!c->alive) return 0;
    if (c->first_arg_tag < 0) return 1;
    if (goal->tag != TAG_STR || AR(goal) == 0) return 1;
    a = deref(ARG(goal, 0));
    switch (a->tag) {
    case TAG_ATOM: tag = TAG_ATOM; key = AT(a); break;
    case TAG_INT:  tag = TAG_INT;  key = (int)IV(a); break;
    case TAG_STR:  tag = TAG_STR;  key = FN(a) * 64 + AR(a); break;
    default: return 1;
    }
    return tag == c->first_arg_tag && key == c->first_arg_key;
}

/* ---- clauses ---- */

/* ISO's conversion of a clause body: a variable where a goal stands is
   call(V), so that a cut it is later bound to is local to it rather than
   cutting the clause.  Only the control constructs are walked, iteratively,
   since a body may be a conjunction a million goals long; every other goal
   is kept as it is. */
static Term *body_convert(Term *b)
{
    WorkStack ws = { NULL, 0, 0 };
    Term *result = NULL, **slot;

    WS_PUSH(&ws, b);
    WS_PUSH(&ws, &result);
    while (ws.n) {
        slot = (Term **)WS_POP(&ws);
        b = deref((Term *)WS_POP(&ws));
        if (b->tag == TAG_VAR) *slot = mk1(a_call, b);
        else if (b->tag == TAG_STR && AR(b) == 2 &&
                 (FN(b) == a_comma || FN(b) == a_semicolon ||
                  FN(b) == a_arrow || FN(b) == a_softarrow)) {
            Term *c = mk_str(FN(b), 2);
            *slot = c;
            WS_PUSH(&ws, ARG(b, 1));
            WS_PUSH(&ws, &ARG(c, 1));
            WS_PUSH(&ws, ARG(b, 0));
            WS_PUSH(&ws, &ARG(c, 0));
        } else *slot = b;
    }
    free(ws.item);
    return result;
}

Clause *clause_make(Term *head, Term *body)
{
    Arena *a = arena_new();
    Clause *c = (Clause *)calloc(1, sizeof(Clause));
    Term *pair = mk2(a_neck, head, body_convert(body));
    Term *compiled;
    int nvars = 0;

    compiled = arena_compile(a, pair, &nvars);
    c->arena = a;
    c->head = ARG(compiled, 0);
    c->body = ARG(compiled, 1);
    c->nvars = nvars;
    c->alive = 1;
    clause_index(c);
    return c;
}

void pred_add_clause(Pred *p, Clause *c, int at_end)
{
    p->defined = 1;
    if (at_end) {
        c->next = NULL;
        if (p->last) p->last->next = c;
        else p->first = c;
        p->last = c;
    } else {
        c->next = p->first;
        p->first = c;
        if (!p->last) p->last = c;
    }
}

/* Frees the clauses retracted from p, once no choice point is left on
   p's clauses: only a choice point can still reach a retracted clause,
   through the next pointers it keeps. */
long long m_clauses_retained;   /* retracted clauses not yet freed */

void pred_reclaim(Pred *p)
{
    Clause *c, *nx;
    if (p->cprefs > 0) return;
    for (c = p->garbage; c; c = nx) {
        nx = c->gnext;
        arena_free(c->arena);
        free(c);
        m_clauses_retained--;
    }
    p->garbage = NULL;
}

void clause_retract(Pred *p, Clause *c)
{
    Clause **link = &p->first, *prev = NULL;

    /* What was retracted before can go now if nothing is iterating p.
       This clause cannot, as the caller may still be reading it. */
    pred_reclaim(p);

    while (*link && *link != c) { prev = *link; link = &(*link)->next; }
    if (*link != c) return;
    *link = c->next;         /* c->next stays intact so iterators can go on */
    if (p->last == c) p->last = prev;
    c->alive = 0;
    /* Not freed yet: a choice point may still point at it, or the caller
       be reading it. It is kept on the garbage list for pred_reclaim. */
    c->gnext = p->garbage;
    p->garbage = c;
    m_clauses_retained++;
}

/* Every clause goes to the garbage list, dead, with its next pointer
   kept, and is freed at once unless a choice point is still on one of
   them, when it is freed as the last such choice point goes. */
void pred_abolish(Pred *p)
{
    Clause *c, *nx;
    for (c = p->first; c; c = nx) {
        nx = c->next;
        c->alive = 0;
        c->gnext = p->garbage;
        p->garbage = c;
        m_clauses_retained++;
    }
    p->first = p->last = NULL;
    p->defined = 0;
    pred_reclaim(p);
}
