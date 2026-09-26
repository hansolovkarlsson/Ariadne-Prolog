/* stream.c -- a small stream layer: files, the standard streams and
   in-memory sinks used by format/3 and with_output_to/2. */
#include "prolog.h"

struct PStream {
    FILE  *f;
    char  *buf;             /* in-memory sink */
    size_t len, cap;
    int    in_use;
    int    is_input;
    int    alias;           /* atom, or -1 */
    char  *name;
    Reader reader;
    int    reader_ready;
};

#define MAX_STREAMS 64
static struct PStream streams[MAX_STREAMS];
static int cur_out = 1, cur_in = 0;
static int a_stream_functor;

void stream_init(void)
{
    a_stream_functor = intern("$stream");
    memset(streams, 0, sizeof(streams));
    streams[0].f = stdin;  streams[0].in_use = 1; streams[0].is_input = 1;
    streams[0].alias = intern("user_input");  streams[0].name = "user_input";
    streams[1].f = stdout; streams[1].in_use = 1;
    streams[1].alias = intern("user_output"); streams[1].name = "user_output";
    streams[2].f = stderr; streams[2].in_use = 1;
    streams[2].alias = intern("user_error");  streams[2].name = "user_error";
}

int stream_index(PStream *s) { return (int)(s - streams); }

PStream *stream_by_index(int i)
{
    if (i < 0 || i >= MAX_STREAMS || !streams[i].in_use) return NULL;
    return &streams[i];
}

Term *stream_term(PStream *s)
{
    return mk1(a_stream_functor, mk_int(stream_index(s)));
}

PStream *stream_of(Term *t)
{
    int i;
    t = deref(t);
    if (t->tag == TAG_STR && FN(t) == a_stream_functor && AR(t) == 1) {
        Term *n = deref(ARG(t, 0));
        if (n->tag == TAG_INT) return stream_by_index((int)IV(n));
        return NULL;
    }
    if (t->tag == TAG_ATOM) {
        for (i = 0; i < MAX_STREAMS; i++)
            if (streams[i].in_use && streams[i].alias == AT(t))
                return &streams[i];
    }
    return NULL;
}

PStream *stream_current_output(void) { return &streams[cur_out]; }
PStream *stream_current_input(void)  { return &streams[cur_in]; }
void     stream_set_output(PStream *s) { cur_out = stream_index(s); }
void     stream_set_input(PStream *s)  { cur_in = stream_index(s); }

FILE *stream_file(PStream *s) { return s->f; }
int   stream_is_input(PStream *s) { return s->is_input; }

PStream *stream_open(const char *path, const char *mode, int is_input)
{
    int i;
    FILE *f = fopen(path, mode);
    if (!f) return NULL;
    for (i = 3; i < MAX_STREAMS; i++) if (!streams[i].in_use) break;
    if (i == MAX_STREAMS) { fclose(f); return NULL; }
    memset(&streams[i], 0, sizeof(streams[i]));
    streams[i].f = f;
    streams[i].in_use = 1;
    streams[i].is_input = is_input;
    streams[i].alias = -1;
    streams[i].name = pl_strdup(path);
    return &streams[i];
}

/* An in-memory output stream; the text is collected in a buffer. */
PStream *stream_open_sink(void)
{
    int i;
    for (i = 3; i < MAX_STREAMS; i++) if (!streams[i].in_use) break;
    if (i == MAX_STREAMS) return NULL;
    memset(&streams[i], 0, sizeof(streams[i]));
    streams[i].in_use = 1;
    streams[i].alias = -1;
    streams[i].cap = 256;
    streams[i].buf = (char *)malloc(streams[i].cap);
    streams[i].buf[0] = 0;
    return &streams[i];
}

const char *stream_sink_text(PStream *s, size_t *len)
{
    if (len) *len = s->len;
    return s->buf ? s->buf : "";
}

int stream_close(PStream *s)
{
    int i = stream_index(s);
    if (i < 3) return 0;                       /* never close the std streams */
    if (cur_out == i) cur_out = 1;
    if (cur_in == i) cur_in = 0;
    if (s->f) fclose(s->f);
    free(s->buf);
    if (s->name) free(s->name);
    memset(s, 0, sizeof(*s));
    return 1;
}

void stream_write(PStream *s, const char *buf, size_t n)
{
    if (s->f) { fwrite(buf, 1, n, s->f); return; }
    if (s->len + n + 1 > s->cap) {
        while (s->len + n + 1 > s->cap) s->cap = s->cap ? s->cap * 2 : 256;
        s->buf = (char *)realloc(s->buf, s->cap);
    }
    memcpy(s->buf + s->len, buf, n);
    s->len += n;
    s->buf[s->len] = 0;
}

Reader *stream_reader(PStream *s)
{
    if (!s->reader_ready) {
        reader_init_file(&s->reader, s->f, s->name ? s->name : "stream");
        s->reader_ready = 1;
    }
    return &s->reader;
}

/* Reads one UTF-8 character into buf and returns its length in bytes, or
   0 at end of stream.  Bytes go through the stream's Reader, so that a
   character read and a term read see one input.  A byte that does not
   start a well-formed sequence is taken alone. */
int stream_get_char(PStream *s, char *buf)
{
    Reader *r = stream_reader(s);
    int c = reader_getc(r), n, i;
    if (c == EOF) return 0;
    buf[0] = (char)c;
    n = c >= 0xF0 && c < 0xF8 ? 4 : c >= 0xE0 ? 3 : c >= 0xC0 ? 2 : 1;
    if (c >= 0xF8) n = 1;
    for (i = 1; i < n; i++) {
        int d = reader_getc(r);
        if (d == EOF || (d & 0xC0) != 0x80) {
            reader_ungetc(r, d);
            return i;
        }
        buf[i] = (char)d;
    }
    return n;
}

/* As stream_get_char, then pushes the bytes back. */
int stream_peek_char(PStream *s, char *buf)
{
    int n = stream_get_char(s, buf), i;
    for (i = n - 1; i >= 0; i--)
        reader_ungetc(stream_reader(s), (unsigned char)buf[i]);
    return n;
}
