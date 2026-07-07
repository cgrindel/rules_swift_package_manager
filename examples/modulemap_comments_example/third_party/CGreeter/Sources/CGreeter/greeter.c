#include "greeter.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

const char *greet(const char *name) {
    const char *prefix = "Hello, ";
    const char *suffix = "!";
    size_t len = strlen(prefix) + strlen(name) + strlen(suffix) + 1;
    char *result = (char *)malloc(len);
    snprintf(result, len, "%s%s%s", prefix, name, suffix);
    return result;
}
