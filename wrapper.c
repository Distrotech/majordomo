/*
 *  $Source: /sources/cvsrepos/majordomo/wrapper.c,v $
 *  $Revision: 1.8 $
 *  $Date: 1997/08/27 15:01:12 $
 *  $Author: cwilson $
 *  $State: Exp $
 *
 *  $Locker:  $
 *  
 */

#ifndef lint
static char rcs_header[] = "$Header: /sources/cvsrepos/majordomo/wrapper.c,v 1.8 1997/08/27 15:01:12 cwilson Exp $";
#endif

#include <stdio.h>
#include <sysexits.h>

#if defined(sun) && defined(sparc)
#include <stdlib.h>
#endif


#ifndef STRCHR
#  include <string.h>
#  define STRCHR(s,c) strchr(s,c)
#endif

#ifndef BIN
#  define BIN "/usr/local/mail/majordomo"
#endif

#ifndef PATH
#  define PATH "PATH=/bin:/usr/bin:/usr/ucb"
#endif

#ifndef HOME
#  define HOME "HOME=/usr/local/mail/majordomo"
#endif

#ifndef SHELL
#  define SHELL "SHELL=/bin/sh"
#endif

char * new_env[] = {
    HOME,		/* 0 */
    PATH,		/* 1 */
    SHELL,		/* 2 */
#ifdef MAJORDOMO_CF
    MAJORDOMO_CF,	/* 3 */
#endif
    0,		/* possibly for USER or LOGNAME */
    0,		/* possible for LOGNAME */
    0,          /* possibly for timezone */
    0
};
    
int new_env_size = 7;				/* to prevent overflow problems */

main(argc, argv, env)
    int argc;
    char * argv[];
    char * env[];

{
    char * prog;
    int e, i;

    if (argc < 2) {
	fprintf(stderr, "USAGE: %s program [<arg> ...]\n", argv[0]);
	exit(EX_USAGE);
    }

    /* if the command contains a /, then don't allow it */
    if (STRCHR(argv[1], '/') != (char *) NULL) {
	/* this error message is intentionally cryptic */
	fprintf(stderr, "%s: error: insecure usage\n", argv[0]);
	exit(EX_NOPERM);
    }

    if ((prog = (char *) malloc(strlen(BIN) + strlen(argv[1]) + 2)) == NULL) {
	fprintf(stderr, "%s: error: malloc failed\n", argv[0]);
	exit(EX_OSERR);
    }

    sprintf(prog, "%s/%s", BIN, argv[1]);

    /*  copy the "USER=" and "LOGNAME=" envariables into the new environment,
     *  if they exist.
     */

#ifdef MAJORDOMO_CF
    e = 4; /* the first unused slot in new_env[] */
#else
    e = 3; /* the first unused slot in new_env[] */
#endif

    for (i = 0 ; env[i] != NULL && e <= new_env_size; i++) {
	if ((strncmp(env[i], "USER=", 5) == 0) ||
	    (strncmp(env[i], "TZ=", 3) == 0) ||
	    (strncmp(env[i], "LOGNAME=", 8) == 0)) {
	    new_env[e++] = env[i];
	}
    }


#if defined(SETGROUP)
/* renounce any previous group memberships if we are running as root */
    if (geteuid() == 0) { /* Should I exit if this test fails? */
    char *setgroups_used = "setgroups_was_included"; /* give strings a hint */
#if defined(MAIL_GID)
    int groups[] =  { POSIX_GID, MAIL_GID, 0 };
    if (setgroups(2, groups) == -1) {
#else
    int groups[] =  { POSIX_GID, 0 };
    if (setgroups(1, groups) == -1) {
#endif
	extern int errno;

	fprintf(stderr, "%s: error setgroups failed errno %d", argv[0],
		errno);
	}
}
#endif
	  

#ifdef POSIX_GID
    setgid(POSIX_GID);
#else
    setgid(getegid());
#endif

#ifdef POSIX_UID
    setuid(POSIX_UID);
#else
    setuid(geteuid());
#endif

    if ((getuid() != geteuid()) || (getgid() != getegid())) {
	fprintf(stderr, "%s: error: Not running with proper UID and GID.\n", argv[0]);
	fprintf(stderr, "    Make certain that wrapper is installed setuid, and if so,\n");
	fprintf(stderr, "    recompile with POSIX flags.\n");
	exit(EX_SOFTWARE);
    }

    execve(prog, argv+1, new_env);

    /* the exec should never return */
    fprintf(stderr, "wrapper: Trying to exec %s failed: ", prog);
    perror(NULL);
    fprintf(stderr, "    Did you define PERL correctly in the Makefile?\n");
    fprintf(stderr, "    HOME is %s,\n", HOME);
    fprintf(stderr, "    PATH is %s,\n", PATH);
    fprintf(stderr, "    SHELL is %s,\n", SHELL);
    fprintf(stderr, "    MAJORDOMO_CF is %s\n", MAJORDOMO_CF);
    exit(EX_OSERR);
}
