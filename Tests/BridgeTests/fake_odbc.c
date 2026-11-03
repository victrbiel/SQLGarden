/* Deterministic test driver, never included in the app product. */
#define _POSIX_C_SOURCE 200809L
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <stdatomic.h>
#include <time.h>
typedef int16_t S;
typedef uint16_t U;
typedef int32_t I;
typedef intptr_t L;
typedef uintptr_t UL;
typedef struct { char sql[100]; int set,row,column; size_t offset; atomic_int canceled; } Statement;
S SQLAllocHandle(S kind,void *parent,void **out) { (void)parent; *out=calloc(1,kind==3 ? sizeof(Statement) : 8); return *out ? 0 : -1; }
S SQLFreeHandle(S kind,void *h) { (void)kind; free(h); return 0; }
S SQLSetEnvAttr(void *h,I key,void *value,I length) { (void)h;(void)key;(void)value;(void)length;return 0; }
S SQLSetConnectAttr(void *h,I key,void *value,I length) { return SQLSetEnvAttr(h,key,value,length); }
S SQLGetConnectAttr(void *h,I key,void *out,I length,I *actual) { (void)h;(void)key;snprintf(out,(size_t)length,"master");*actual=6;return 0; }
S SQLDriverConnect(void *h,void *window,unsigned char *input,S size,unsigned char *output,S capacity,S *written,U mode) {
    (void)h;(void)window;(void)size;(void)output;(void)capacity;(void)written;(void)mode;
    return strstr((char *)input,"BAD") ? -1 : 0;
}
S SQLDisconnect(void *h) { (void)h; return 0; }
S SQLSetStmtAttr(void *h,I key,void *value,I length) { return SQLSetEnvAttr(h,key,value,length); }
S SQLExecDirect(void *h,unsigned char *sql,I length) {
    (void)length; Statement *s=h; snprintf(s->sql,sizeof(s->sql),"%s",sql);
    if(!strcmp(s->sql,"CANCEL")) {
        struct timespec pause={0,1000000};
        for(int i=0;i<5000 && !atomic_load(&s->canceled);i++) nanosleep(&pause,NULL);
        return -1;
    }
    return !strcmp(s->sql,"ERROR") ? -1 : (!strcmp(s->sql,"MULTI") ? 1 : 0);
}
S SQLNumResultCols(void *h,S *cols) { Statement *s=h;*cols=(!strcmp(s->sql,"MULTI") && s->set==1) ? 0 : (!strcmp(s->sql,"VALUES") ? 4 : 1); return 0; }
S SQLDescribeCol(void *h,U col,unsigned char *name,S capacity,S *length,S *type,UL *size,S *scale,S *nullable) {
    Statement *s=h;(void)col;snprintf((char *)name,(size_t)capacity,"coluna \"ação\"");*length=(S)strlen((char *)name);
    *type=(!strcmp(s->sql,"BINARY") || !strcmp(s->sql,"BINARY_WARN")) ? -3 : 12;*size=100;*scale=0;*nullable=1;return 0;
}
S SQLFetch(void *h) {
    Statement *s=h;s->offset=0;s->column=0;
    if(!strcmp(s->sql,"FETCH_ERROR") && s->row==1) return -1;
    int rows=!strcmp(s->sql,"MANY") ? 10 : 1;
    return s->row++<rows ? 0 : 100;
}
S SQLGetData(void *h,U col,S type,void *output,L capacity,L *indicator) {
    Statement *s=h;
    if(s->column!=col) { s->offset=0;s->column=col; }
    if(!strcmp(s->sql,"DATA_ERROR")) return -1;
    if(!strcmp(s->sql,"VALUES") && col==2) { *indicator=-1;return 0; }
    const char *text="ação 🎓 \"aspas\"\nbarra\\tab\t";
    if(!strcmp(s->sql,"VALUES") && col==3) text="";
    if(!strcmp(s->sql,"VALUES") && col==4) text="NULL";
    size_t textLength=strlen(text);
    char nulLarge[10001];
    if(!strcmp(s->sql,"NUL")) { text="A\0B\0"; textLength=4; }
    if(!strcmp(s->sql,"NUL_LONG")) {
        memset(nulLarge,'x',10000); nulLarge[0]=0; nulLarge[4094]=0; nulLarge[4095]=0; nulLarge[9999]=0;
        text=nulLarge; textLength=10000;
    }
    size_t length=textLength;int large=!strcmp(s->sql,"LONG") || !strcmp(s->sql,"CAP");
    if(large) length=!strcmp(s->sql,"LONG") ? 10000 : 400000;
    unsigned char binary[]={0,1,255,16};
    if(type==-2) length=sizeof(binary);
    if(s->offset>=length && length>0) return 100;
    size_t remaining=length-s->offset;
    size_t limit=(size_t)capacity-(type==-2 ? 0 : 1);
    size_t n=remaining<limit ? remaining : limit;
    if(large) memset(output,'x',n);
    else memcpy(output,type==-2 ? (const void *)(binary+s->offset) : (const void *)(text+s->offset),n);
    if(type!=-2) ((char *)output)[n]=0;
    s->offset+=n;*indicator=(L)remaining;
    return remaining>limit || !strcmp(s->sql,"BINARY_WARN") ? 1 : 0;
}
S SQLRowCount(void *h,L *count) { Statement *s=h;*count=(!strcmp(s->sql,"MULTI") && s->set==1) ? 7 : -1;return 0; }
S SQLMoreResults(void *h) { Statement *s=h;s->row=0;s->offset=0;s->column=0;return !strcmp(s->sql,"MULTI") && ++s->set<3 ? 0 : 100; }
S SQLGetDiagRec(S kind,void *h,S record,unsigned char *state,I *native,unsigned char *message,S capacity,S *length) {
    (void)kind;(void)h;if(record>1) return 100;
    strcpy((char *)state,"42000");*native=50000;snprintf((char *)message,(size_t)capacity,"Mensagem de teste: ação");*length=(S)strlen((char *)message);return 0;
}
S SQLCancel(void *h) { Statement *s=h;atomic_store(&s->canceled,1);return 0; }
