/* term.c -- memory management, atom table, terms, unification. */
#include "prolog.h"
#include <time.h>

/* ------------------------------------------------------------------ */
/* Backtrackable heap                                                 */
/* ------------------------------------------------------------------ */

#define HEAP_CHUNK_MIN (256 * 1024)

static HeapChunk *heap_head, *heap_cur;
static size_t heap_total;
static unsigned heap_epoch = 1;
long long m_gc_count;
long long m_gc_freed;        /* bytes of heap in use given back, over every collection */
long long m_gc_msecs;        /* time spent collecting */

static HeapChunk *chunk_new(size_t size)
{
    HeapChunk *c = (HeapChunk *)malloc(sizeof(HeapChunk));
    if (!c) { fprintf(stderr, "prolog: out of memory\n"); exit(1); }
    if (size < HEAP_CHUNK_MIN) size = HEAP_CHUNK_MIN;
    c->data = (char *)malloc(size);
    if (!c->data) { fprintf(stderr, "prolog: out of memory\n"); exit(1); }
    c->size = size;
    c->used = 0;
    c->next = NULL;
    heap_total += size;
    return c;
}

static void heap_init(void)
{
    heap_head = heap_cur = chunk_new(HEAP_CHUNK_MIN);
}

/* strdup is POSIX, not C99, and is hidden by glibc under -std=c99: calling it
   there truncates the returned pointer to an int. */
char *pl_strdup(const char *s)
{
    size_t n = strlen(s) + 1;
    char *p = (char *)malloc(n);
    if (!p) { fprintf(stderr, "prolog: out of memory\n"); exit(1); }
    memcpy(p, s, n);
    return p;
}

void *heap_alloc(size_t n)
{
    HeapChunk *c;
    void *p;

    n = (n + 7) & ~(size_t)7;               /* 8 is enough for every member of Term */
    if (!heap_cur) heap_init();
    if (heap_cur->used + n <= heap_cur->size) {
        p = heap_cur->data + heap_cur->used;
        heap_cur->used += n;
        return p;
    }
    /* Re-use a following chunk if one is large enough, else splice a new
       chunk in after the current one (keeping the rest of the list). */
    if (heap_cur->next && heap_cur->next->size >= n) {
        heap_cur = heap_cur->next;
        heap_cur->used = n;
        return heap_cur->data;
    }
    c = chunk_new(n);
    c->next = heap_cur->next;
    heap_cur->next = c;
    heap_cur = c;
    heap_cur->used = n;
    return heap_cur->data;
}

HeapMark heap_mark(void)
{
    HeapMark m;
    if (!heap_cur) heap_init();
    m.chunk = heap_cur;
    m.used = heap_cur->used;
    m.epoch = heap_epoch;
    return m;
}

void heap_release(HeapMark m)
{
    HeapChunk *c;
    if (!m.chunk) return;
    /* A mark taken before a garbage collection no longer describes a
       position in the current heap; the collector has already reclaimed it. */
    if (m.epoch != heap_epoch) return;
    /* Chunks after the mark stay allocated but become free space again. */
    for (c = m.chunk->next; c; c = c->next) c->used = 0;
    heap_cur = m.chunk;
    heap_cur->used = m.used;
}

size_t heap_in_use(void)
{
    HeapChunk *c;
    size_t n = 0;
    for (c = heap_head; c; c = c->next) {
        n += c->used;
        if (c == heap_cur) break;
    }
    return n;
}

/* ------------------------------------------------------------------ */
/* Permanent arenas                                                   */
/* ------------------------------------------------------------------ */

typedef struct ABlock ABlock;
struct ABlock { ABlock *next; size_t size, used; char data[1]; };

struct Arena { ABlock *block; };

#define ARENA_BLOCK 4096

Arena *arena_new(void)
{
    Arena *a = (Arena *)malloc(sizeof(Arena));
    if (!a) { fprintf(stderr, "prolog: out of memory\n"); exit(1); }
    a->block = NULL;
    return a;
}

void *arena_alloc(Arena *a, size_t n)
{
    ABlock *b;
    void *p;

    n = (n + 7) & ~(size_t)7;
    if (a->block && a->block->used + n <= a->block->size) {
        p = a->block->data + a->block->used;
        a->block->used += n;
        return p;
    }
    {
        size_t size = n > ARENA_BLOCK ? n : ARENA_BLOCK;
        b = (ABlock *)malloc(sizeof(ABlock) + size);
        if (!b) { fprintf(stderr, "prolog: out of memory\n"); exit(1); }
        b->size = size;
        b->used = n;
        b->next = a->block;
        a->block = b;
        return b->data;
    }
}

void arena_free(Arena *a)
{
    ABlock *b, *nx;
    if (!a) return;
    for (b = a->block; b; b = nx) { nx = b->next; free(b); }
    free(a);
}

/* ------------------------------------------------------------------ */
/* Atom table                                                         */
/* ------------------------------------------------------------------ */

typedef struct { char *name; size_t len; } AtomEntry;

static AtomEntry *atoms;
static int natoms, atoms_cap;
static int *atom_hash;            /* open addressing, holds index+1 */
static int atom_hash_cap;

static unsigned long hash_bytes(const char *s, size_t n)
{
    unsigned long h = 5381;
    size_t i;
    for (i = 0; i < n; i++) h = ((h << 5) + h) ^ (unsigned char)s[i];
    return h;
}

static void atom_rehash(int newcap)
{
    int i;
    free(atom_hash);
    atom_hash = (int *)calloc(newcap, sizeof(int));
    if (!atom_hash) { fprintf(stderr, "prolog: out of memory\n"); exit(1); }
    atom_hash_cap = newcap;
    for (i = 0; i < natoms; i++) {
        unsigned long h = hash_bytes(atoms[i].name, atoms[i].len) % newcap;
        while (atom_hash[h]) h = (h + 1) % newcap;
        atom_hash[h] = i + 1;
    }
}

int intern_n(const char *s, size_t n)
{
    unsigned long h;
    int idx;

    if (!atom_hash) atom_rehash(1024);
    h = hash_bytes(s, n) % atom_hash_cap;
    while ((idx = atom_hash[h])) {
        AtomEntry *e = &atoms[idx - 1];
        if (e->len == n && memcmp(e->name, s, n) == 0) return idx - 1;
        h = (h + 1) % atom_hash_cap;
    }
    if (natoms == atoms_cap) {
        atoms_cap = atoms_cap ? atoms_cap * 2 : 512;
        atoms = (AtomEntry *)realloc(atoms, atoms_cap * sizeof(AtomEntry));
        if (!atoms) { fprintf(stderr, "prolog: out of memory\n"); exit(1); }
    }
    atoms[natoms].name = (char *)malloc(n + 1);
    memcpy(atoms[natoms].name, s, n);
    atoms[natoms].name[n] = 0;
    atoms[natoms].len = n;
    natoms++;
    atom_hash[h] = natoms;
    if (natoms * 2 > atom_hash_cap) atom_rehash(atom_hash_cap * 2);
    return natoms - 1;
}

int intern(const char *s) { return intern_n(s, strlen(s)); }

const char *atom_name(int a) { return atoms[a].name; }
size_t atom_len(int a) { return atoms[a].len; }

int a_nil, a_dot, a_true, a_fail, a_false, a_comma, a_semicolon;
int a_arrow, a_softarrow, a_cut, a_curly, a_minus, a_plus, a_error;
int a_call, a_catch, a_end_of_file, a_eq, a_clause, a_dcg, a_var_prefix;
int a_empty, a_star, a_slash, a_colon, a_bar, a_neck, a_not, a_dollar_var;

void pl_init_atoms(void)
{
    a_nil = intern("[]");
    a_dot = intern(".");
    a_true = intern("true");
    a_fail = intern("fail");
    a_false = intern("false");
    a_comma = intern(",");
    a_semicolon = intern(";");
    a_arrow = intern("->");
    a_softarrow = intern("*->");
    a_cut = intern("!");
    a_curly = intern("{}");
    a_minus = intern("-");
    a_plus = intern("+");
    a_error = intern("error");
    a_call = intern("call");
    a_catch = intern("catch");
    a_end_of_file = intern("end_of_file");
    a_eq = intern("=");
    a_clause = intern(":-");
    a_dcg = intern("-->");
    a_empty = intern("");
    a_star = intern("*");
    a_slash = intern("/");
    a_colon = intern(":");
    a_bar = intern("|");
    a_neck = intern(":-");
    a_not = intern("\\+");
    a_dollar_var = intern("$VAR");
    a_var_prefix = intern("_G");
}

/* ------------------------------------------------------------------ */
/* Term construction                                                  */
/* ------------------------------------------------------------------ */

static unsigned long var_serial;

Term *mk_var(void)
{
    Term *t = (Term *)heap_alloc(sizeof(Term));
    t->tag = TAG_VAR;
    t->u.v.ref = NULL;
    t->u.v.serial = ++var_serial;
    return t;
}

Term *mk_atom(int a)
{
    Term *t = (Term *)heap_alloc(sizeof(Term));
    t->tag = TAG_ATOM;
    t->u.atom = a;
    return t;
}

Term *mk_atom_str(const char *s) { return mk_atom(intern(s)); }

Term *mk_int(long long i)
{
    Term *t = (Term *)heap_alloc(sizeof(Term));
    t->tag = TAG_INT;
    t->u.i = i;
    return t;
}

Term *mk_float(double f)
{
    Term *t = (Term *)heap_alloc(sizeof(Term));
    t->tag = TAG_FLT;
    t->u.f = f;
    return t;
}

Term *mk_str(int functor, int arity)
{
    Term *t = (Term *)heap_alloc(sizeof(Term) + arity * sizeof(Term *));
    t->tag = TAG_STR;
    t->u.s.functor = functor;
    t->u.s.arity = arity;
    t->u.s.args = (Term **)((char *)t + sizeof(Term));
    return t;
}

Term *mk1(int f, Term *a)
{
    Term *t = mk_str(f, 1);
    ARG(t, 0) = a;
    return t;
}

Term *mk2(int f, Term *a, Term *b)
{
    Term *t = mk_str(f, 2);
    ARG(t, 0) = a; ARG(t, 1) = b;
    return t;
}

Term *mk3(int f, Term *a, Term *b, Term *c)
{
    Term *t = mk_str(f, 3);
    ARG(t, 0) = a; ARG(t, 1) = b; ARG(t, 2) = c;
    return t;
}

Term *mk4(int f, Term *a, Term *b, Term *c, Term *d)
{
    Term *t = mk_str(f, 4);
    ARG(t, 0) = a; ARG(t, 1) = b; ARG(t, 2) = c; ARG(t, 3) = d;
    return t;
}

Term *mk_cons(Term *head, Term *tail) { return mk2(a_dot, head, tail); }

/* Decodes one UTF-8 character starting at s[i], advancing i. */
long utf8_decode(const char *s, size_t n, size_t *i)
{
    unsigned char c = (unsigned char)s[*i];
    int extra, k;
    long code;

    if (c < 0x80) { (*i)++; return c; }
    extra = c >= 0xF0 ? 3 : c >= 0xE0 ? 2 : 1;
    code = c & (0x3F >> extra);
    (*i)++;
    for (k = 0; k < extra && *i < n; k++, (*i)++) {
        unsigned char d = (unsigned char)s[*i];
        if ((d & 0xC0) != 0x80) break;
        code = (code << 6) | (d & 0x3F);
    }
    return code;
}

size_t utf8_encode(long code, char *buf)
{
    if (code < 0) code = 0xFFFD;
    if (code < 0x80) { buf[0] = (char)code; return 1; }
    if (code < 0x800) {
        buf[0] = (char)(0xC0 | (code >> 6));
        buf[1] = (char)(0x80 | (code & 0x3F));
        return 2;
    }
    if (code < 0x10000) {
        buf[0] = (char)(0xE0 | (code >> 12));
        buf[1] = (char)(0x80 | ((code >> 6) & 0x3F));
        buf[2] = (char)(0x80 | (code & 0x3F));
        return 3;
    }
    buf[0] = (char)(0xF0 | (code >> 18));
    buf[1] = (char)(0x80 | ((code >> 12) & 0x3F));
    buf[2] = (char)(0x80 | ((code >> 6) & 0x3F));
    buf[3] = (char)(0x80 | (code & 0x3F));
    return 4;
}

Term *mk_codes(const char *s, size_t n)
{
    Term *list = mk_atom(a_nil);
    long *codes;
    size_t i = 0, k = 0;

    codes = (long *)malloc((n + 1) * sizeof(long));
    while (i < n) codes[k++] = utf8_decode(s, n, &i);
    while (k > 0) list = mk_cons(mk_int(codes[--k]), list);
    free(codes);
    return list;
}

Term *mk_chars(const char *s, size_t n)
{
    Term *list = mk_atom(a_nil);
    size_t *starts;
    size_t i = 0, k = 0;

    starts = (size_t *)malloc((n + 2) * sizeof(size_t));
    while (i < n) { starts[k++] = i; utf8_decode(s, n, &i); }
    starts[k] = n;
    while (k > 0) {
        k--;
        list = mk_cons(mk_atom(intern_n(s + starts[k], starts[k + 1] - starts[k])),
                       list);
    }
    free(starts);
    return list;
}

Term *list_from_array(Term **items, int n)
{
    Term *list = mk_atom(a_nil);
    int i;
    for (i = n - 1; i >= 0; i--) list = mk_cons(items[i], list);
    return list;
}

int list_length(Term *t)
{
    int n = 0;
    t = deref(t);
    while (t->tag == TAG_STR && FN(t) == a_dot && AR(t) == 2) {
        n++;
        t = deref(ARG(t, 1));
    }
    return (t->tag == TAG_ATOM && AT(t) == a_nil) ? n : -1;
}

/* ------------------------------------------------------------------ */
/* Dereferencing, trail and binding                                   */
/* ------------------------------------------------------------------ */

Term *deref(Term *t)
{
    while (t->tag == TAG_VAR && t->u.v.ref) t = t->u.v.ref;
    return t;
}

enum { TR_BIND, TR_FLAG };

typedef struct {
    unsigned char kind;
    union { Term *var; int *slot; } p;
    int old;
} TrailEntry;

static TrailEntry *trail;
static size_t tr_top, tr_cap;

static void trail_grow(void)
{
    tr_cap = tr_cap ? tr_cap * 2 : 4096;
    trail = (TrailEntry *)realloc(trail, tr_cap * sizeof(TrailEntry));
    if (!trail) { fprintf(stderr, "prolog: out of memory\n"); exit(1); }
}

void bind(Term *var, Term *val)
{
    var->u.v.ref = val;
    if (tr_top == tr_cap) trail_grow();
    trail[tr_top].kind = TR_BIND;
    trail[tr_top].p.var = var;
    tr_top++;
}

void trail_flag(int *slot)
{
    if (tr_top == tr_cap) trail_grow();
    trail[tr_top].kind = TR_FLAG;
    trail[tr_top].p.slot = slot;
    trail[tr_top].old = *slot;
    tr_top++;
}

size_t trail_mark(void) { return tr_top; }

void trail_undo(size_t mark)
{
    while (tr_top > mark) {
        tr_top--;
        if (trail[tr_top].kind == TR_BIND)
            trail[tr_top].p.var->u.v.ref = NULL;
        else
            *trail[tr_top].p.slot = trail[tr_top].old;
    }
}

void ws_grow(WorkStack *s)
{
    s->cap = s->cap ? s->cap * 2 : 256;
    s->item = (void **)realloc(s->item, s->cap * sizeof(void *));
    if (!s->item) { fprintf(stderr, "prolog: out of memory\n"); exit(1); }
}

/* ------------------------------------------------------------------ */
/* Garbage collection                                                 */
/* ------------------------------------------------------------------ */

/* Roots held in C variables across a call into the machine.  Anything the
   caller still needs after machine_run() returns must be registered here. */
#define MAX_GC_ROOTS 32
static Term **gc_roots[MAX_GC_ROOTS];
static int gc_nroots;

void gc_protect(Term **slot)
{
    if (gc_nroots < MAX_GC_ROOTS) gc_roots[gc_nroots++] = slot;
}

int  gc_root_top(void) { return gc_nroots; }
void gc_unprotect(int n) { gc_nroots = n; }

/* Copies one term into the new heap, leaving a forwarding pointer behind so
   that shared (and cyclic) structure is copied exactly once. */
static Term *gc_copy(Term *t)
{
    static WorkStack ws;                /* pending (source, slot) pairs */
    size_t base = ws.n;
    Term *result = NULL, *c;
    Term **slot = &result;
    int i;

    for (;;) {
        while (t->tag == TAG_VAR && t->u.v.ref) t = t->u.v.ref;
        switch (t->tag) {
        case TAG_FWD:
            *slot = t->u.v.ref;
            break;
        case TAG_VAR:
            c = (Term *)heap_alloc(sizeof(Term));
            c->tag = TAG_VAR;
            c->u.v.ref = NULL;
            c->u.v.serial = t->u.v.serial;  /* keep the standard order stable */
            t->tag = TAG_FWD;
            t->u.v.ref = c;
            *slot = c;
            break;
        case TAG_ATOM: case TAG_INT: case TAG_FLT:
            c = (Term *)heap_alloc(sizeof(Term));
            *c = *t;
            *slot = c;
            break;
        default: {
            int f = FN(t), n = AR(t);
            Term **args = t->u.s.args;      /* saved: forwarding clobbers it */
            c = mk_str(f, n);
            t->tag = TAG_FWD;
            t->u.v.ref = c;
            *slot = c;
            if (n == 0) break;
            for (i = n - 1; i > 0; i--) {
                WS_PUSH(&ws, args[i]);
                WS_PUSH(&ws, &ARG(c, i));
            }
            slot = &ARG(c, 0);
            t = args[0];
            continue;
        }
        }
        if (ws.n == base) return result;
        slot = (Term **)WS_POP(&ws);
        t = (Term *)WS_POP(&ws);
    }
}

void heap_gc(Goal **goals_root)
{
    HeapChunk *old_head = heap_head, *c, *nx;
    Goal *g, **link;
    int i;
    size_t before = heap_in_use();
    clock_t t0 = clock();

    /* Start a fresh heap; everything reachable is copied into it. */
    heap_head = heap_cur = chunk_new(HEAP_CHUNK_MIN);

    for (g = *goals_root, link = goals_root; g; g = g->next) {
        Goal *ng = (Goal *)heap_alloc(sizeof(Goal));
        ng->cutb = g->cutb;
        ng->next = NULL;
        ng->goal = gc_copy(g->goal);
        *link = ng;
        link = &ng->next;
    }
    for (i = 0; i < gc_nroots; i++)
        if (*gc_roots[i]) *gc_roots[i] = gc_copy(*gc_roots[i]);

    /* With no choice points there is nothing left to undo. */
    tr_top = 0;
    heap_epoch++;
    m_gc_count++;
    if (heap_in_use() < before) m_gc_freed += (long long)(before - heap_in_use());

    for (c = old_head; c; c = nx) {
        nx = c->next;
        heap_total -= c->size;
        free(c->data);
        free(c);
    }
    m_gc_msecs += (long long)((double)(clock() - t0) * 1000.0 / CLOCKS_PER_SEC);
}

/* ------------------------------------------------------------------ */
/* Unification                                                        */
/* ------------------------------------------------------------------ */

/* Unifies two dereferenced terms that are not both compound. */
static ALWAYS_INLINE int unify_leaf(Term *a, Term *b)
{
    if (a == b) return 1;
    if (a->tag == TAG_VAR) {
        /* Bind the younger variable to the older one. */
        if (b->tag == TAG_VAR && a->u.v.serial < b->u.v.serial) bind(b, a);
        else bind(a, b);
        return 1;
    }
    if (b->tag == TAG_VAR) { bind(b, a); return 1; }
    if (a->tag != b->tag) return 0;
    switch (a->tag) {
    case TAG_ATOM: return AT(a) == AT(b);
    case TAG_INT:  return IV(a) == IV(b);
    case TAG_FLT:  return FV(a) == FV(b);
    }
    return 0;
}

int unify(Term *a, Term *b)
{
    static WorkStack ws;                /* pending argument pairs */
    size_t base;
    int i, j, n;

    /* Most calls meet a variable or a constant at once. */
    a = deref(a);
    b = deref(b);
    if (a->tag != TAG_STR || b->tag != TAG_STR) return unify_leaf(a, b);
    base = ws.n;
next:
    a = deref(a);
    b = deref(b);
    if (a->tag != TAG_STR || b->tag != TAG_STR) {
        if (!unify_leaf(a, b)) goto fail;
    } else if (a != b) {
        if (FN(a) != FN(b) || AR(a) != AR(b)) goto fail;
        n = AR(a);
        /* Leaves in place, in order; the first pair of compounds is gone
           into, and the pairs after it wait. */
        for (i = 0; i < n; i++) {
            Term *x = deref(ARG(a, i)), *y = deref(ARG(b, i));
            if (x->tag != TAG_STR || y->tag != TAG_STR) {
                if (!unify_leaf(x, y)) goto fail;
                continue;
            }
            if (x == y) continue;
            for (j = n - 1; j > i; j--) {
                WS_PUSH(&ws, ARG(a, j));
                WS_PUSH(&ws, ARG(b, j));
            }
            a = x;
            b = y;
            goto next;
        }
    }
    if (ws.n == base) return 1;
    b = (Term *)WS_POP(&ws);
    a = (Term *)WS_POP(&ws);
    goto next;
fail:
    ws.n = base;
    return 0;
}

/* ------------------------------------------------------------------ */
/* Standard order of terms                                            */
/* ------------------------------------------------------------------ */

static int type_rank(Term *t)
{
    switch (t->tag) {
    case TAG_VAR:  return 0;
    case TAG_FLT:  return 1;
    case TAG_INT:  return 1;   /* numbers compare by value, float first */
    case TAG_ATOM: return 3;
    default:       return 4;
    }
}

static int cmp_ll(long long a, long long b) { return a < b ? -1 : a > b ? 1 : 0; }
static int cmp_d(double a, double b) { return a < b ? -1 : a > b ? 1 : 0; }

/* Compares two dereferenced terms that are not both compound, or are of
   different ranks. */
static ALWAYS_INLINE int compare_leaf(Term *a, Term *b)
{
    int ra, rb, c;
    if (a == b) return 0;
    ra = type_rank(a);
    rb = type_rank(b);
    if (ra != rb) return ra < rb ? -1 : 1;
    switch (a->tag) {
    case TAG_VAR:
        return a->u.v.serial < b->u.v.serial ? -1 :
               a->u.v.serial > b->u.v.serial ? 1 : 0;
    case TAG_INT:
        if (b->tag == TAG_INT) return cmp_ll(IV(a), IV(b));
        c = cmp_d((double)IV(a), FV(b));
        return c ? c : 1;                       /* Float < Int if equal */
    case TAG_FLT:
        if (b->tag == TAG_FLT) return cmp_d(FV(a), FV(b));
        c = cmp_d(FV(a), (double)IV(b));
        return c ? c : -1;
    case TAG_ATOM:
        c = strcmp(atom_name(AT(a)), atom_name(AT(b)));
        return c < 0 ? -1 : c > 0 ? 1 : 0;
    }
    return 0;
}

int compare_terms(Term *a, Term *b)
{
    static WorkStack ws;                /* pending argument pairs */
    size_t base = ws.n;
    int c = 0, i, j, n;

next:
    a = deref(a);
    b = deref(b);
    if (a->tag != TAG_STR || b->tag != TAG_STR) {
        if ((c = compare_leaf(a, b)) != 0) goto done;
    } else if (a != b) {
        if (AR(a) != AR(b)) { c = AR(a) < AR(b) ? -1 : 1; goto done; }
        c = strcmp(atom_name(FN(a)), atom_name(FN(b)));
        if (c) { c = c < 0 ? -1 : 1; goto done; }
        n = AR(a);
        /* Arguments left to right: leaves in place, the first pair of
           compounds gone into, the pairs after it waiting. */
        for (i = 0; i < n; i++) {
            Term *x = deref(ARG(a, i)), *y = deref(ARG(b, i));
            if (x->tag != TAG_STR || y->tag != TAG_STR) {
                if ((c = compare_leaf(x, y)) != 0) goto done;
                continue;
            }
            if (x == y) continue;
            for (j = n - 1; j > i; j--) {
                WS_PUSH(&ws, ARG(a, j));
                WS_PUSH(&ws, ARG(b, j));
            }
            a = x;
            b = y;
            goto next;
        }
    }
    if (ws.n == base) return 0;
    b = (Term *)WS_POP(&ws);
    a = (Term *)WS_POP(&ws);
    goto next;
done:
    ws.n = base;
    return c;
}

/* ------------------------------------------------------------------ */
/* Copying                                                            */
/* ------------------------------------------------------------------ */

/* The index is open addressing on the variable's address and holds i+1,
   so a lookup costs the same however many variables came before. */
static int varmap_slot(const VarMap *m, Term *v)
{
    int h = (int)((((size_t)v >> 3) * 2654435761u) % (size_t)m->icap);
    while (m->index[h] && m->from[m->index[h] - 1] != v) h = (h + 1) % m->icap;
    return h;
}

Term *varmap_get(const VarMap *m, Term *v)
{
    int i;
    if (!m->icap) return NULL;
    i = m->index[varmap_slot(m, v)];
    return i ? m->to[i - 1] : NULL;
}

void varmap_put(VarMap *m, Term *from, Term *to)
{
    int i;
    if (m->n == m->cap) {
        m->cap = m->cap ? m->cap * 2 : 32;
        m->from = (Term **)realloc(m->from, m->cap * sizeof(Term *));
        m->to = (Term **)realloc(m->to, m->cap * sizeof(Term *));
    }
    m->from[m->n] = from;
    m->to[m->n] = to;
    m->n++;
    if (2 * m->n > m->icap) {               /* keep the index at most half full */
        free(m->index);
        m->icap = m->icap ? m->icap * 2 : 64;
        m->index = (int *)calloc((size_t)m->icap, sizeof(int));
        for (i = 0; i < m->n; i++) m->index[varmap_slot(m, m->from[i])] = i + 1;
    } else {
        m->index[varmap_slot(m, from)] = m->n;
    }
}

void varmap_free(VarMap *m) { free(m->from); free(m->to); free(m->index); }

/* One dereferenced term of copy_rec that is not a compound. */
static ALWAYS_INLINE Term *copy_leaf(Term *t, VarMap *m, Arena *a, int compile)
{
    Term *r;
    if (t->tag == TAG_VAR) {
        r = varmap_get(m, t);
        if (!r) {
            if (a) {
                r = (Term *)arena_alloc(a, sizeof(Term));
                r->tag = TAG_VAR;
                r->u.v.ref = NULL;
                r->u.v.serial = compile ? (unsigned long)m->n : 0;
            } else {
                r = mk_var();
            }
            varmap_put(m, t, r);
        }
        return r;
    }
    if (!a) return t;                   /* constants can be shared */
    r = (Term *)arena_alloc(a, sizeof(Term));
    *r = *t;
    return r;
}

static Term *copy_rec(Term *t, VarMap *m, Arena *a, int compile)
{
    static WorkStack ws;                /* pending (source, slot) pairs */
    size_t base = ws.n;
    Term *c, *result = NULL;
    Term **slot = &result;
    int i, j, n;

next:
    t = deref(t);
    if (t->tag != TAG_STR) *slot = copy_leaf(t, m, a, compile);
    else {
        n = AR(t);
        if (a) {
            c = (Term *)arena_alloc(a, sizeof(Term) + n * sizeof(Term *));
            c->tag = TAG_STR;
            c->u.s.functor = FN(t);
            c->u.s.arity = n;
            c->u.s.args = (Term **)((char *)c + sizeof(Term));
        } else {
            c = mk_str(FN(t), n);
        }
        *slot = c;
        /* Left to right, so variables are met, and numbered, in the order
           they appear: leaves in place, the first compound gone into, the
           arguments after it waiting. */
        for (i = 0; i < n; i++) {
            Term *x = deref(ARG(t, i));
            if (x->tag != TAG_STR) { ARG(c, i) = copy_leaf(x, m, a, compile); continue; }
            for (j = n - 1; j > i; j--) {
                WS_PUSH(&ws, ARG(t, j));
                WS_PUSH(&ws, &ARG(c, j));
            }
            slot = &ARG(c, i);
            t = x;
            goto next;
        }
    }
    if (ws.n == base) return result;
    slot = (Term **)WS_POP(&ws);
    t = (Term *)WS_POP(&ws);
    goto next;
}

Term *heap_copy(Term *t)
{
    VarMap m = VARMAP_INIT;
    Term *r = copy_rec(t, &m, NULL, 0);
    varmap_free(&m);
    return r;
}

Term *arena_compile(Arena *a, Term *t, int *nvars)
{
    VarMap m = VARMAP_INIT;
    Term *r = copy_rec(t, &m, a, 1);
    if (nvars) *nvars = m.n;
    varmap_free(&m);
    return r;
}

/* One argument of heap_instantiate that is not a compound. */
static ALWAYS_INLINE Term *instantiate_leaf(Term *t, Term **vars, int nvars)
{
    Term *c;
    if (t->tag == TAG_VAR) {
        unsigned long idx = t->u.v.serial;
        if ((int)idx >= nvars) return mk_var();
        if (!vars[idx]) vars[idx] = mk_var();
        return vars[idx];
    }
    /* Constants are copied rather than shared: the source term may live in
       an arena (a clause, a findall buffer, an exception ball) that is
       released long before the instantiated copy dies. */
    c = (Term *)heap_alloc(sizeof(Term));
    *c = *t;
    return c;
}

Term *heap_instantiate(Term *t, Term **vars, int nvars)
{
    static WorkStack ws;                /* pending (source, slot) pairs */
    size_t base = ws.n;
    Term *c, *result = NULL;
    Term **slot = &result;
    int i, j, n;

next:
    if (t->tag != TAG_STR) *slot = instantiate_leaf(t, vars, nvars);
    else {
        n = AR(t);
        c = mk_str(FN(t), n);
        *slot = c;
        /* Leaves are done in place; the first compound argument is gone
           into, and the ones after it wait.  So arguments are met left to
           right, and a list of constants never touches the stack. */
        for (i = 0; i < n; i++) {
            Term *x = ARG(t, i);
            if (x->tag != TAG_STR) { ARG(c, i) = instantiate_leaf(x, vars, nvars); continue; }
            for (j = n - 1; j > i; j--) {
                WS_PUSH(&ws, ARG(t, j));
                WS_PUSH(&ws, &ARG(c, j));
            }
            slot = &ARG(c, i);
            t = x;
            goto next;
        }
    }
    if (ws.n == base) return result;
    slot = (Term **)WS_POP(&ws);
    t = (Term *)WS_POP(&ws);
    goto next;
}

/* The distinct unbound variables of t, depth first and left to right, as
   a malloc'd array the caller frees; *n is set to their number.  The walk
   keeps its own stack, so a long list costs no C stack.  A variable is
   bound to a marker when first found, so meeting it again costs nothing;
   the marks are taken off before return.  Nothing here allocates on the
   heap, so no collection can see a mark. */
Term **term_variables(Term *t, int *n)
{
    static Term seen;                   /* the marker; only its address matters */
    Term **vars = NULL, **stack = NULL;
    int nv = 0, cv = 0, top = 0, cs = 0, i;

    #define PUSH(x) do { if (top == cs) { cs = cs ? cs * 2 : 64;              \
                         stack = (Term **)realloc(stack, cs * sizeof(Term *)); } \
                         stack[top++] = (x); } while (0)
    PUSH(t);
    while (top) {
        t = deref(stack[--top]);
        if (t == &seen) continue;
        if (t->tag == TAG_VAR) {
            if (nv == cv) {
                cv = cv ? cv * 2 : 16;
                vars = (Term **)realloc(vars, cv * sizeof(Term *));
            }
            vars[nv++] = t;
            t->u.v.ref = &seen;
        } else if (t->tag == TAG_STR) {
            for (i = AR(t) - 1; i >= 0; i--) PUSH(ARG(t, i));
        }
    }
    #undef PUSH
    for (i = 0; i < nv; i++) vars[i]->u.v.ref = NULL;
    free(stack);
    *n = nv;
    return vars;
}
