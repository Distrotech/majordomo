
#$Modified: Tue Jan 18 14:58:24 2000 by cwilson $
#
# $Source: /sources/cvsrepos/majordomo/Makefile,v $
# $Revision: 1.64 $
# $Date: 2000/01/18 14:01:17 $
# $Header: /sources/cvsrepos/majordomo/Makefile,v 1.64 2000/01/18 14:01:17 cwilson Exp $
# 

#  This is the Makefile for Majordomo.  
# 
#-------------  Configure these items ----------------# 
#
 
# Put the location of your Perl binary here:
PERL = /usr/bin/perl

# What do you call your C compiler?
CC = cc
 
# Where do you want Majordomo to be installed?  This CANNOT be the
# current directory (where you unpacked the distribution)
W_HOME = /opt/majordomo
 
# Where do you want man pages to be installed?
MAN = $(W_HOME)/man
 
# You need to have or create a user and group which majordomo will run as.
# Enter the numeric UID and GID (not their names!) here:
W_USER = 123
W_GROUP = 45

# These set the permissions for all installed files and executables (except
# the wrapper), respectively.  Some sites may wish to make these more
# lenient, or more restrictive.
FILE_MODE = 644
EXEC_MODE = 755
HOME_MODE = 751

# If your system is POSIX (e.g. Sun Solaris, SGI Irix 5 and 6, Dec Ultrix MIPS,
# BSDI or other 4.4-based BSD, Linux) use the following four lines.  Do not
# change these values!
WRAPPER_OWNER = root
WRAPPER_GROUP = $(W_GROUP)
WRAPPER_MODE = 4755
POSIX = -DPOSIX_UID=$(W_USER) -DPOSIX_GID=$(W_GROUP)
# Otherwise, if your system is NOT POSIX (e.g. SunOS 4.x, SGI Irix 4,
# HP DomainOS) then comment out the above four lines and uncomment
# the following four lines.
# WRAPPER_OWNER = $(W_USER)
# WRAPPER_GROUP = $(W_GROUP)
# WRAPPER_MODE = 6755
# POSIX = 

# Define this if the majordomo programs should *also* be run in the same
# group as your MTA, usually sendmail.  This is rarely needed, but some
# MTAs require certain group memberships before allowing the message sender
# to be set arbitrarily.
# MAIL_GID = 	numeric_gid_of_MTA

# This is the environment that (along with LOGNAME and USER inherited from the
# parent process, and without the leading "W_" in the variable names) gets
# passed to processes run by "wrapper"
W_SHELL = /bin/sh
W_PATH = /bin:/usr/bin:/usr/ucb
W_MAJORDOMO_CF = $(W_HOME)/majordomo.cf

# A directory for temp files..
TMPDIR = /tmp

#--------YOU SHOULDN'T HAVE TO CHANGE ANYTHING BELOW THIS LINE.-------------

VERSION =	1.94.5

# For those stupid machines that try to use csh. Doh!
SHELL = /bin/sh

WRAPPER_FLAGS = -DBIN=\"$(W_HOME)\" -DPATH=\"PATH=$(W_PATH)\" \
	-DHOME=\"HOME=$(W_HOME)\" -DSHELL=\"SHELL=$(W_SHELL)\" \
	-DMAJORDOMO_CF=\"MAJORDOMO_CF=$(W_MAJORDOMO_CF)\"      \
	$(POSIX)

INSTALL = ./install.sh

TMP = $(TMPDIR)/mj-install-$(VERSION)

TOOLS =		archive.pl archive_mh.pl \
		digest.send makeindex.pl \
		logsummary.pl new-list sequencer 

BINBIN =	approve bounce medit

BIN = 		bounce-remind config_parse.pl majordomo majordomo.pl \
		majordomo_version.pl request-answer resend \
		shlock.pl config-test archive2.pl digest

INSTALL_FLAGS = -O $(W_USER) -g $(W_GROUP)

default: 
	@echo "make what?"
	@echo "    install: installs everything."
	@echo "    install-wrapper: only install wrapper."
	@echo "    install-scripts: only install the scripts."
	@echo "    wrapper: only make wrapper."

install: wrapper install-scripts install-cf install-man
	@echo ""
	@echo "To finish the installation, 'su' to root and type:"
	@echo ""
	@echo "	    make install-wrapper"
	@echo ""
	@echo "If not installing the wrapper, type"
	@echo ""
	@echo "	    cd $(W_HOME); ./wrapper config-test"
	@echo ""
	@echo "(no 'su' necessary) to verify the installation."


install-wrapper: wrapper
	$(INSTALL) -o $(WRAPPER_OWNER) -g $(WRAPPER_GROUP) \
		-m $(WRAPPER_MODE) wrapper $(W_HOME)/wrapper
	@echo ""
	@echo "To verify that all the permissions and etc are correct,"
	@echo "run the command"
	@echo ""
	@echo "	     cd $(W_HOME); ./wrapper config-test"

# fix where perl lives.
# Create a tmp directory to stuff all the files in, so we 
# don't go blithly changing the master copies of stuff.  
#
config-scripts:
	@echo "Testing for perl ($(PERL))..."
	@test -f $(PERL) -a -x $(PERL) || \
		{ echo "You didn't correctly tell me where Perl is."; exit 1; } 
	@rm -rf $(TMP); mkdir $(TMP)
	@echo "Configuring scripts..."
	@for file in $(TOOLS); do \
		cp contrib/$$file $(TMP) ; \
	done
	@cp $(BINBIN) $(BIN) $(TMP)
	@cd $(TMP);	$(PERL) -p -i -e 's@^#!\S+perl.*@#!$(PERL)@' $(TOOLS) $(BINBIN) $(BIN) 


install-scripts: config-scripts
	$(INSTALL) -m $(HOME_MODE) $(INSTALL_FLAGS) . $(W_HOME)
	$(INSTALL) -m $(EXEC_MODE) $(INSTALL_FLAGS) . $(W_HOME)/bin

	@echo "Copying tools to $(W_HOME)/bin"

	@for file in $(BINBIN); do \
		$(INSTALL) -m $(EXEC_MODE) $(INSTALL_FLAGS) \
			$(TMP)/$$file $(W_HOME)/bin/$$file; \
	done

	@echo "Copying Majordomo files to $(W_HOME)"

	@for file in $(BIN); do \
		$(INSTALL) -m $(EXEC_MODE) $(INSTALL_FLAGS) \
			$(TMP)/$$file $(W_HOME)/$$file; \
	done

	@echo "Copying archiving and other tools to $(W_HOME)/Tools"

	$(INSTALL) -m $(EXEC_MODE) $(INSTALL_FLAGS) . $(W_HOME)/Tools

	@for file in $(TOOLS); do \
		$(INSTALL) -m $(EXEC_MODE) $(INSTALL_FLAGS) \
			$(TMP)/$$file $(W_HOME)/Tools/$$file; \
	done

	@rm -rf $(TMP)	

# the install.cf target will install the sample config file in the proper
# place unless a majordomo.cf file exists, in which case the majordomo.cf
# file will be used. It won't overwrite an existing majordomo.cf file.  In
# all cases, the sample.cf file must be installed so that config-test will
# be able to check for new variables.
install-cf:
	@if [ ! -f $(W_HOME)/majordomo.cf ]; \
	  then \
	    if [ -f majordomo.cf ]; \
	      then \
		echo "Using majordomo.cf"; \
	  	$(INSTALL) -m $(FILE_MODE) $(INSTALL_FLAGS) \
			majordomo.cf $(W_HOME)/majordomo.cf; \
	      else \
		echo "Using sample.cf"; \
		$(INSTALL) -m $(FILE_MODE) $(INSTALL_FLAGS) \
			sample.cf $(W_HOME)/majordomo.cf; \
	    fi; \
	else \
	   echo "Using installed majordomo.cf"; \
	fi;
	@$(INSTALL) -m $(FILE_MODE) $(INSTALL_FLAGS) \
		sample.cf $(W_HOME)

install-man:
	@echo "Installing manual pages in $(MAN)"
	@$(INSTALL) -m $(EXEC_MODE) $(INSTALL_FLAGS) \
		. $(MAN)
	@$(INSTALL) -m $(EXEC_MODE) $(INSTALL_FLAGS) \
		. $(MAN)/man1
	@$(INSTALL) -m $(EXEC_MODE) $(INSTALL_FLAGS) \
		. $(MAN)/man8
	@$(INSTALL) -m $(FILE_MODE) $(INSTALL_FLAGS) \
		Doc/man/approve.1 $(MAN)/man1/approve.1
	@$(INSTALL) -m $(FILE_MODE) $(INSTALL_FLAGS) \
		Doc/man/digest.1 $(MAN)/man1/digest.1
	@$(INSTALL) -m $(FILE_MODE) $(INSTALL_FLAGS) \
		Doc/man/bounce.1 $(MAN)/man1/bounce.1
	@$(INSTALL) -m $(FILE_MODE) $(INSTALL_FLAGS) \
		Doc/man/bounce-remind.1 $(MAN)/man1/bounce-remind.1
	@$(INSTALL) -m $(FILE_MODE) $(INSTALL_FLAGS) \
		Doc/man/resend.1 $(MAN)/man1/resend.1
	@$(INSTALL) -m $(FILE_MODE) $(INSTALL_FLAGS) \
		Doc/man/majordomo.8 $(MAN)/man8/majordomo.8
	@$(INSTALL) -m $(FILE_MODE) $(INSTALL_FLAGS) \
		Doc/man/resend.1 $(MAN)/man1/resend.1

wrapper: wrapper.c
	$(CC)  $(WRAPPER_FLAGS) -o wrapper wrapper.c

clean:
	rm -f  wrapper *~

dist-clean: clean
	rm -f majordomo.cf .cvsignore todo.local .dcl archive
	rm -rf regress Doc/samples Tools

distribution: dist-clean
	mkdir majordomo-$(VERSION)
	mv * .??* majordomo-$(VERSION) || exit 0
	rm -rf majordomo-$(VERSION)/CVS majordomo-$(VERSION)/*/CVS \
		majordomo-$(VERSION)/*/*/CVS
	tar -cvf majordomo-$(VERSION).tar.Z\
		  majordomo-$(VERSION)
