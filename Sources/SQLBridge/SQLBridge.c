#include "SQLBridge.h"
#include <dlfcn.h>
#include <pthread.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/* Private unixODBC ABI subset. Keeping it here avoids Homebrew header and
 * linker paths in the app build; unixODBC is loaded at runtime. SQLLEN is
 * pointer-sized on the supported 64-bit platforms. No Microsoft code bundled. */
typedef int16_t Small;
typedef uint16_t USmall;
typedef int32_t Integer;
typedef intptr_t Len;
typedef uintptr_t ULen;
typedef void *Handle;
typedef unsigned char Char;
enum { OK=0, INFO=1, NO_DATA=100, ENV=1, DBC=2, STMT=3, NTS=-3,
       NULL_DATA=-1, C_CHAR=1, C_BINARY=-2 };
#define GOOD(rc) ((rc)==OK || (rc)==INFO)
#define CELL_LIMIT (256u * 1024u)
#define OUTPUT_LIMIT (32u * 1024u * 1024u)

typedef struct { char *p; size_t n, cap; int failed; } Buffer;
static void addn(Buffer *b, const char *s, size_t n) {
    if (b->failed || !n) return;
    if (b->n + n + 1 > b->cap) {
        size_t cap = (b->n + n + 1) * 2;
        char *next = realloc(b->p, cap);
        if (!next) { b->failed=1; return; }
        b->p=next; b->cap=cap;
    }
    memcpy(b->p+b->n,s,n); b->n+=n; b->p[b->n]=0;
}
static void add(Buffer *b, const char *s) { addn(b,s,strlen(s)); }
static void number(Buffer *b, long long n) { char s[48]; snprintf(s,sizeof(s),"%lld",n); add(b,s); }
static void quotedn(Buffer *b, const char *s, size_t n) {
    add(b,"\"");
    for (const unsigned char *p=(const unsigned char *)s, *end=p+n; p<end; ++p) {
        char escaped[7];
        switch (*p) {
            case '"': add(b,"\\\""); break;
            case '\\': add(b,"\\\\"); break;
            case '\n': add(b,"\\n"); break;
            case '\r': add(b,"\\r"); break;
            case '\t': add(b,"\\t"); break;
            default:
                if (*p<32) { snprintf(escaped,sizeof(escaped),"\\u%04x",*p); add(b,escaped); }
                else addn(b,(const char *)p,1);
        }
    }
    add(b,"\"");
}
static void quoted(Buffer *b, const char *s) { quotedn(b,s,strlen(s)); }
static char *finish(Buffer *b) {
    if (b->failed) { free(b->p); return strdup("{\"success\":false,\"messages\":\"Memória insuficiente.\",\"sets\":[]}"); }
    return b->p ? b->p : strdup("");
}

typedef struct {
    Small (*alloc)(Small,Handle,Handle*);
    Small (*free_handle)(Small,Handle);
    Small (*env_attr)(Handle,Integer,void*,Integer);
    Small (*connect_attr)(Handle,Integer,void*,Integer);
    Small (*get_connect_attr)(Handle,Integer,void*,Integer,Integer*);
    Small (*driver_connect)(Handle,Handle,Char*,Small,Char*,Small,Small*,USmall);
    Small (*disconnect)(Handle);
    Small (*stmt_attr)(Handle,Integer,void*,Integer);
    Small (*exec)(Handle,Char*,Integer);
    Small (*num_cols)(Handle,Small*);
    Small (*describe)(Handle,USmall,Char*,Small,Small*,Small*,ULen*,Small*,Small*);
    Small (*fetch)(Handle);
    Small (*get_data)(Handle,USmall,Small,void*,Len,Len*);
    Small (*row_count)(Handle,Len*);
    Small (*more)(Handle);
    Small (*diag)(Small,Handle,Small,Char*,Integer*,Char*,Small,Small*);
    Small (*cancel)(Handle);
} API;
#if defined(__has_include)
#if __has_include(<sql.h>) && __has_include(<sqlext.h>)
#include <sql.h>
#include <sqlext.h>
/* When headers are available, also have the compiler verify this private ABI.
 * The app does not require headers to be installed at build time. */
_Static_assert(sizeof(Small)==sizeof(SQLSMALLINT), "SQLSMALLINT ABI");
_Static_assert(sizeof(Integer)==sizeof(SQLINTEGER), "SQLINTEGER ABI");
_Static_assert(sizeof(Len)==sizeof(SQLLEN), "SQLLEN ABI");
_Static_assert(sizeof(ULen)==sizeof(SQLULEN), "SQLULEN ABI");
#if defined(__clang__) || defined(__GNUC__)
#define ABI_CHECK(field,symbol) _Static_assert(__builtin_types_compatible_p(__typeof__(((API *)0)->field),__typeof__(&symbol)), #symbol " ABI")
ABI_CHECK(alloc,SQLAllocHandle); ABI_CHECK(free_handle,SQLFreeHandle);
ABI_CHECK(env_attr,SQLSetEnvAttr); ABI_CHECK(connect_attr,SQLSetConnectAttr);
ABI_CHECK(get_connect_attr,SQLGetConnectAttr); ABI_CHECK(driver_connect,SQLDriverConnect);
ABI_CHECK(disconnect,SQLDisconnect); ABI_CHECK(stmt_attr,SQLSetStmtAttr);
ABI_CHECK(exec,SQLExecDirect); ABI_CHECK(num_cols,SQLNumResultCols);
ABI_CHECK(describe,SQLDescribeCol); ABI_CHECK(fetch,SQLFetch);
ABI_CHECK(get_data,SQLGetData); ABI_CHECK(row_count,SQLRowCount);
ABI_CHECK(more,SQLMoreResults); ABI_CHECK(diag,SQLGetDiagRec); ABI_CHECK(cancel,SQLCancel);
#undef ABI_CHECK
#endif
#endif
#endif
struct SGSession { void *lib; API api; Handle env, dbc, active; pthread_mutex_t lock; int connected; };

static void diagnostics(SGSession *s,Small kind,Handle handle,Buffer *out) {
    for (Small i=1; i<100; ++i) {
        Char state[6]={0}, message[8192]={0}; Integer native=0; Small length=0;
        Small rc=s->api.diag(kind,handle,i,state,&native,message,sizeof(message),&length);
        if (!GOOD(rc)) break;
        if (out->n) add(out,"\n");
        add(out,"["); add(out,(char *)state); add(out,"] "); add(out,(char *)message);
    }
}
static char *response(int success,Buffer *messages,Buffer *sets) {
    Buffer out={0};
    add(&out,success ? "{\"success\":true,\"messages\":" : "{\"success\":false,\"messages\":");
    quoted(&out,messages->p ? messages->p : ""); add(&out,",\"sets\":[");
    if (sets) add(&out,sets->p ? sets->p : "");
    add(&out,"]}"); free(messages->p);
    if (sets) { if (sets->failed) out.failed=1; free(sets->p); }
    return finish(&out);
}

SGSession *sg_session_create(char **error) {
    if (error) *error=NULL;
    SGSession *s=calloc(1,sizeof(*s));
    if (!s) { if(error) *error=strdup("Memória insuficiente."); return NULL; }
    pthread_mutex_init(&s->lock,NULL);
    const char *paths[]={
#ifdef SG_TESTING
        "./.test-build/libodbc-test.so",
#endif
        "/opt/homebrew/opt/unixodbc/lib/libodbc.2.dylib",
        "/usr/local/opt/unixodbc/lib/libodbc.2.dylib", "libodbc.2.dylib", "libodbc.so.2",NULL
    };
    for (int i=0; paths[i] && !s->lib; ++i) s->lib=dlopen(paths[i],RTLD_NOW|RTLD_LOCAL);
    if (!s->lib) {
        if(error) *error=strdup("unixODBC não encontrado. Execute scripts/setup-mac.sh e reabra o app.");
        sg_session_free(s); return NULL;
    }
#define LOAD(field,name) do { *(void **)(&s->api.field)=dlsym(s->lib,name); if(!s->api.field) goto symbol_error; } while(0)
    LOAD(alloc,"SQLAllocHandle"); LOAD(free_handle,"SQLFreeHandle"); LOAD(env_attr,"SQLSetEnvAttr");
    LOAD(connect_attr,"SQLSetConnectAttr"); LOAD(driver_connect,"SQLDriverConnect");
    LOAD(get_connect_attr,"SQLGetConnectAttr");
    LOAD(disconnect,"SQLDisconnect"); LOAD(stmt_attr,"SQLSetStmtAttr"); LOAD(exec,"SQLExecDirect");
    LOAD(num_cols,"SQLNumResultCols"); LOAD(describe,"SQLDescribeCol"); LOAD(fetch,"SQLFetch");
    LOAD(get_data,"SQLGetData"); LOAD(row_count,"SQLRowCount"); LOAD(more,"SQLMoreResults");
    LOAD(diag,"SQLGetDiagRec"); LOAD(cancel,"SQLCancel");
#undef LOAD
    if(!GOOD(s->api.alloc(ENV,NULL,&s->env)) || !GOOD(s->api.env_attr(s->env,200,(void *)(intptr_t)3,0)) ||
       !GOOD(s->api.alloc(DBC,s->env,&s->dbc))) {
        if(error) *error=strdup("Não foi possível inicializar o unixODBC.");
        sg_session_free(s); return NULL;
    }
    s->api.connect_attr(s->dbc,103,(void *)(intptr_t)8,0); /* login timeout */
    return s;
symbol_error:
    if(error) *error=strdup("A instalação do unixODBC está incompleta.");
    sg_session_free(s); return NULL;
}

char *sg_connect(SGSession *s,const char *connection_string) {
    Buffer msg={0};
    if(s->connected) { s->api.disconnect(s->dbc); s->connected=0; }
    Small rc=s->api.driver_connect(s->dbc,NULL,(Char *)connection_string,NTS,NULL,0,NULL,0);
    if(rc==INFO || !GOOD(rc)) diagnostics(s,DBC,s->dbc,&msg);
    s->connected=GOOD(rc);
    return response(s->connected,&msg,NULL);
}

/* SQLGetData streams large values. The per-cell cap keeps the UI responsive;
 * binary types are represented as hex and NULL remains JSON null. */
static int cell(SGSession *s,Handle stmt,USmall col,Small type,Buffer *out,Buffer *msg,int *truncated) {
    Buffer value={0}; int binary=type==-2 || type==-3 || type==-4;
    if(binary) add(&value,"0x");
    for(;;) {
        unsigned char chunk[4096]; Len indicator=0;
        // A sentinel lets us locate the FINAL driver terminator even when data
        // contains embedded zeroes or a UTF-8 chunk ends before BufferLength-1.
        memset(chunk,0xff,sizeof(chunk));
        Small rc=s->api.get_data(stmt,col,binary ? C_BINARY : C_CHAR,chunk,sizeof(chunk),&indicator);
        if(indicator==NULL_DATA) { add(out,"null"); free(value.p); return 1; }
        if(rc==NO_DATA) break;
        if(!GOOD(rc)) { diagnostics(s,STMT,stmt,msg); free(value.p); return 0; }
        size_t n;
        if(binary) {
            if(indicator>=0) n=(size_t)indicator<sizeof(chunk) ? (size_t)indicator : sizeof(chunk);
            else if(rc==INFO) n=sizeof(chunk); /* SQL_NO_TOTAL on a full chunk */
            else {
                add(msg,"\nO driver não informou o comprimento do binário; o valor não foi exibido.");
                free(value.p); return 0;
            }
        }
        else {
            size_t end=sizeof(chunk);
            while(end && chunk[end-1]!=0) --end;
            if(!end) {
                add(msg,"\nO driver retornou texto sem terminador; o valor não foi exibido.");
                free(value.p); return 0;
            }
            n=end-1;
        }
        if(binary) {
            for(size_t i=0;i<n;i++) { char hex[3]; snprintf(hex,sizeof(hex),"%02X",chunk[i]); add(&value,hex); }
        } else addn(&value,(char *)chunk,n);
        if(n==0) break;
        if(value.n>=CELL_LIMIT) { *truncated=1; add(&value," … [valor limitado]"); break; }
        if(rc==OK) break;
    }
    /* If a UTF-8 codepoint is cut by CELL_LIMIT, Swift decodes it with a
     * replacement character rather than failing the entire result. */
    quotedn(out,value.p ? value.p : "",value.n);
    if(value.failed) out->failed=1;
    free(value.p); return 1;
}

char *sg_execute(SGSession *s,const char *sql,unsigned timeout_seconds,unsigned max_rows) {
    Buffer msg={0},sets={0}; Handle stmt=NULL; int success=1, count=0;
    if(!s->connected) { add(&msg,"Conecte ao servidor antes de executar."); return response(0,&msg,NULL); }
    if(!GOOD(s->api.alloc(STMT,s->dbc,&stmt))) { diagnostics(s,DBC,s->dbc,&msg); return response(0,&msg,NULL); }
    Small attr=s->api.stmt_attr(stmt,0,(void *)(uintptr_t)timeout_seconds,0);
    if(!GOOD(attr)) diagnostics(s,STMT,stmt,&msg);
    pthread_mutex_lock(&s->lock); s->active=stmt; pthread_mutex_unlock(&s->lock);
    Small rc=s->api.exec(stmt,(Char *)sql,NTS);
    if(rc==INFO || (!GOOD(rc) && rc!=NO_DATA)) diagnostics(s,STMT,stmt,&msg);
    if(!GOOD(rc) && rc!=NO_DATA) success=0;
    /* SQLExecDirect may return SQL_NO_DATA for zero-row DML before later results. */
    if(rc==NO_DATA) {
        rc=s->api.more(stmt);
        if(rc==INFO || (!GOOD(rc) && rc!=NO_DATA)) diagnostics(s,STMT,stmt,&msg);
        if(!GOOD(rc) && rc!=NO_DATA) success=0;
    }
    while(success && rc!=NO_DATA) {
        if(count>=64) { add(&msg,"\nLimite de 64 resultados atingido. Execução interrompida; comandos pendentes podem não ter sido executados."); success=0; break; }
        Small cols=0;
        if(!GOOD(s->api.num_cols(stmt,&cols))) { diagnostics(s,STMT,stmt,&msg); success=0; break; }
        Len affected=-1; s->api.row_count(stmt,&affected);
        if(cols<0 || cols>512) { add(&msg,"\nResultado excede 512 colunas; exibição interrompida."); success=0; break; }
        if(count++) add(&sets,",");
        add(&sets,"{\"columns\":[");
        Small *types=calloc((size_t)(cols ? cols : 1),sizeof(Small));
        if(!types) { sets.failed=1; success=0; break; }
        for(Small i=0;i<cols;i++) {
            Char name[1024]={0}; Small len=0,scale=0,nullable=0; ULen size=0;
            Small desc=s->api.describe(stmt,(USmall)(i+1),name,sizeof(name),&len,&types[i],&size,&scale,&nullable);
            if(!GOOD(desc)) { diagnostics(s,STMT,stmt,&msg); success=0; }
            if(i) add(&sets,",");
            quoted(&sets,(char *)name);
        }
        add(&sets,"],\"rows\":[");
        unsigned rows=0; int truncated=0;
        while(success && cols>0) {
            Small fr=s->api.fetch(stmt);
            if(fr==NO_DATA) break;
            if(!GOOD(fr)) { diagnostics(s,STMT,stmt,&msg); success=0; break; }
            if(fr==INFO) diagnostics(s,STMT,stmt,&msg);
            if(rows>=max_rows || sets.n>OUTPUT_LIMIT) { truncated=1; break; }
            if(rows++) add(&sets,",");
            add(&sets,"[");
            for(Small i=0;i<cols;i++) {
                if(i) add(&sets,",");
                if(sets.n>OUTPUT_LIMIT) { add(&sets,"null"); truncated=1; continue; }
                if(!cell(s,stmt,(USmall)(i+1),types[i],&sets,&msg,&truncated)) {
                    add(&sets,"null"); success=0;
                }
            }
            add(&sets,"]");
        }
        free(types);
        add(&sets,"],\"affectedRows\":"); number(&sets,(long long)affected);
        add(&sets,truncated ? ",\"truncated\":true}" : ",\"truncated\":false}");
        if(sets.n>OUTPUT_LIMIT) { add(&msg,"\nLimite de memória dos resultados atingido. Execução interrompida; comandos pendentes podem não ter sido executados."); success=0; break; }
        if(!success) break;
        /* SQLMoreResults discards unread rows, then processes following DML,
         * PRINT messages and result sets. Never re-execute the user's SQL. */
        rc=s->api.more(stmt);
        if(rc==INFO || (!GOOD(rc) && rc!=NO_DATA)) diagnostics(s,STMT,stmt,&msg);
        if(!GOOD(rc) && rc!=NO_DATA) success=0;
    }
    pthread_mutex_lock(&s->lock); s->active=NULL;
    s->api.free_handle(STMT,stmt); pthread_mutex_unlock(&s->lock);
    if(!success && !msg.n) add(&msg,"A execução falhou. Verifique a conexão e o SQL.");
    return response(success,&msg,&sets);
}
void sg_cancel(SGSession *s) {
    if(!s) return;
    pthread_mutex_lock(&s->lock);
    if(s->active) s->api.cancel(s->active);
    pthread_mutex_unlock(&s->lock);
}
char *sg_current_database(SGSession *s) {
    char value[2048]={0}; Integer length=0;
    if(!s || !s->connected || !GOOD(s->api.get_connect_attr(s->dbc,109,value,sizeof(value),&length))) return NULL;
    return strdup(value);
}
void sg_session_free(SGSession *s) {
    if(!s) return;
    if(s->connected && s->api.disconnect) s->api.disconnect(s->dbc);
    if(s->dbc && s->api.free_handle) s->api.free_handle(DBC,s->dbc);
    if(s->env && s->api.free_handle) s->api.free_handle(ENV,s->env);
    if(s->lib) dlclose(s->lib);
    pthread_mutex_destroy(&s->lock); free(s);
}
void sg_string_free(char *s) { free(s); }
