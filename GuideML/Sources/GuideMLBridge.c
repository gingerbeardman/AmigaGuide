#include "GuideMLBridge.h"

#include <errno.h>
#include <fcntl.h>
#include <limits.h>
#include <pthread.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>

static pthread_mutex_t guideml_mutex = PTHREAD_MUTEX_INITIALIZER;

extern char **argv_save;
int guideml_main(int argc, char **argv);

bool GuideMLConvertToDirectory(const char *inputPath,
                               const char *outputDirectory,
                               char *errorBuffer,
                               size_t errorBufferLength)
{
    if (errorBuffer && errorBufferLength > 0) {
        errorBuffer[0] = '\0';
    }

    if (inputPath == NULL || outputDirectory == NULL) {
        if (errorBuffer && errorBufferLength > 0) {
            snprintf(errorBuffer, errorBufferLength, "Missing input or output path");
        }
        return false;
    }

    char *argv[] = {
        "guideml",
        (char *)inputPath,
        "TO",
        (char *)outputDirectory,
        "SINGLEFILE",
        "NOWARN",
        NULL
    };

    char cwd[PATH_MAX];
    if (getcwd(cwd, sizeof(cwd)) == NULL) {
        cwd[0] = '\0';
    }

    int savedOut = dup(STDOUT_FILENO);
    int savedErr = dup(STDERR_FILENO);
    int devNull = open("/dev/null", O_WRONLY);
    if (devNull >= 0) {
        dup2(devNull, STDOUT_FILENO);
        dup2(devNull, STDERR_FILENO);
        close(devNull);
    }

    pthread_mutex_lock(&guideml_mutex);
    argv_save = argv;
    guideml_main(6, argv);
    pthread_mutex_unlock(&guideml_mutex);

    if (savedOut >= 0) {
        dup2(savedOut, STDOUT_FILENO);
        close(savedOut);
    }
    if (savedErr >= 0) {
        dup2(savedErr, STDERR_FILENO);
        close(savedErr);
    }
    if (cwd[0] != '\0') {
        chdir(cwd);
    }

    return true;
}
