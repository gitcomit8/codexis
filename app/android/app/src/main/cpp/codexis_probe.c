#include <stdio.h>
#include <string.h>
#include <unistd.h>

int main(int argc, char **argv) {
    if (argc > 1 && strcmp(argv[1], "--version") == 0) {
        puts("CODEXIS_ANDROID_PROBE_V1");
        return 0;
    }

    puts("CODEXIS_STDOUT_OK");
    fprintf(stderr, "CODEXIS_STDERR_OK pid=%ld\n", (long)getpid());
    fflush(stdout);
    fflush(stderr);
    return 23;
}
