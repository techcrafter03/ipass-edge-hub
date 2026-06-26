#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <dirent.h>      /* opendir, readdir, closedir */
#include <sys/stat.h>    /* stat(), struct stat         */

#define LOG_DIR "/var/log"
#define MAX_PATH 512

/* Convert raw bytes into a human-readable string: KB or MB */
void human_readable(long bytes, char *buf, int buf_size) {
    if (bytes >= 1048576)
        snprintf(buf, buf_size, "%.2f MB", (double)bytes / 1048576);
    else if (bytes >= 1024)
        snprintf(buf, buf_size, "%.2f KB", (double)bytes / 1024);
    else
        snprintf(buf, buf_size, "%ld B", bytes);
}

int main(void) {
    DIR           *dir;       /* pointer to the open directory       */
    struct dirent *entry;     /* one directory entry (file/folder)   */
    struct stat    file_stat; /* holds metadata for a single file    */
    char           full_path[MAX_PATH];
    char           readable_size[32];

    /* --- Open /var/log --- */
    dir = opendir(LOG_DIR);
    if (dir == NULL) {
        perror("ERROR: Cannot open " LOG_DIR);
        return EXIT_FAILURE;
    }

    printf("============================================\n");
    printf("  iPaaS Edge Hub — Log File Size Report\n");
    printf("============================================\n");
    printf("%-40s %12s\n", "FILE", "SIZE");
    printf("--------------------------------------------\n");

    /* --- Loop through every entry in the directory --- */
    while ((entry = readdir(dir)) != NULL) {

        /* Skip hidden entries like "." and ".." */
        if (entry->d_name[0] == '.')
            continue;

        /* Build the full path: /var/log/syslog etc. */
        snprintf(full_path, sizeof(full_path),
                 "%s/%s", LOG_DIR, entry->d_name);

        /* stat() fills file_stat with size, permissions, timestamps */
        if (stat(full_path, &file_stat) == -1)
            continue;   /* skip if we can't read it, don't crash */

        /* Only report regular files, skip sub-directories */
        if (!S_ISREG(file_stat.st_mode))
            continue;

        human_readable(file_stat.st_size, readable_size, sizeof(readable_size));
        printf("%-40s %12s\n", entry->d_name, readable_size);
    }

    printf("============================================\n");
    closedir(dir);
    return EXIT_SUCCESS;
}