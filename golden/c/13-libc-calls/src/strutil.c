#include <stdlib.h>
#include <string.h>

size_t safe_len(const char *s) {
    return s ? strlen(s) : 0;
}

char *dup_str(const char *s) {
    char *p = malloc(safe_len(s) + 1);
    if (p)
        memcpy(p, s, safe_len(s) + 1);
    return p;
}
