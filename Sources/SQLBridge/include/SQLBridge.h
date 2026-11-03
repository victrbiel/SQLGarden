#ifndef SQLGARDEN_BRIDGE_H
#define SQLGARDEN_BRIDGE_H
#include <stddef.h>
typedef struct SGSession SGSession;
/* The caller serializes connect/execute/free. cancel may run on another thread.
 * JSON and load errors are owned by the caller; release with sg_string_free. */
SGSession *sg_session_create(char **error);
char *sg_connect(SGSession *session, const char *connection_string);
char *sg_execute(SGSession *session, const char *sql, unsigned timeout_seconds, unsigned max_rows);
char *sg_current_database(SGSession *session);
void sg_cancel(SGSession *session);
void sg_session_free(SGSession *session);
void sg_string_free(char *string);
#endif
