/* A native bootstrap gives only this app the OpenSSL 3 lookup path required
 * by Microsoft ODBC 18.7. Homebrew's unversioned openssl alias can point to 4.
 * No system links, TLS settings or shell profiles are modified. */
#include <mach-o/dyld.h>
#include <limits.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

int main(int argc, char **argv) {
    (void)argc;
    const char *paths[] = {
        "/opt/homebrew/opt/openssl@3/lib", "/usr/local/opt/openssl@3/lib", NULL
    };
    for (int i = 0; paths[i]; ++i) {
        char library[PATH_MAX];
        if (snprintf(library, sizeof(library), "%s/libssl.3.dylib", paths[i]) < 0) continue;
        if (access(library, R_OK) == 0) {
            const char *previous = getenv("DYLD_LIBRARY_PATH");
            size_t length = strlen(paths[i]) + (previous ? strlen(previous) + 1 : 0) + 1;
            char *value = malloc(length);
            if (!value) { perror("SQLGarden"); return 1; }
            snprintf(value, length, "%s%s%s", paths[i], previous && *previous ? ":" : "", previous ? previous : "");
            int status = setenv("DYLD_LIBRARY_PATH", value, 1);
            free(value);
            if (status != 0) { perror("SQLGarden"); return 1; }
            break;
        }
    }
    char executable[PATH_MAX];
    uint32_t size = sizeof(executable);
    if (_NSGetExecutablePath(executable, &size) != 0) { fputs("SQLGarden: caminho do app muito longo.\n", stderr); return 1; }
    char *slash = strrchr(executable, '/');
    if (!slash || (size_t)(slash - executable) + sizeof("/SQLGarden") > sizeof(executable)) return 1;
    strcpy(slash, "/SQLGarden");
    argv[0] = executable;
    execv(executable, argv);
    perror("SQLGarden");
    return 1;
}
