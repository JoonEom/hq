/* hqrun — tiny launcher for HQ launchd jobs.
 * Runs "/bin/bash <script> [args]" as a child and stays alive as the job's
 * root process, so TCC attributes file access to THIS binary. Grant hqrun
 * Full Disk Access once and every HQ script (and its children) can read
 * iCloud Drive from launchd. */
#include <stdio.h>
#include <unistd.h>
#include <sys/wait.h>
int main(int argc, char **argv) {
    (void)argc;
    pid_t p = fork();
    if (p < 0) return 1;
    if (p == 0) { execv("/bin/bash", argv); perror("execv"); _exit(127); }
    int st = 0;
    waitpid(p, &st, 0);
    return WIFEXITED(st) ? WEXITSTATUS(st) : 128;
}
