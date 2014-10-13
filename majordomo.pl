# General subroutines for Majordomo

# $Source: /sources/cvsrepos/majordomo/majordomo.pl,v $
# $Revision: 1.58 $
# $Date: 2000/01/07 12:32:04 $
# $Author: cwilson $
# $State: Exp $
# 
# $Header: /sources/cvsrepos/majordomo/majordomo.pl,v 1.58 2000/01/07 12:32:04 cwilson Exp $
# 

# The exit codes for abort.  Look in /usr/include/sysexits.h.
#
$EX_DATAERR = 65;
$EX_TEMPFAIL = 75;
$EX_NOUSER = 67;

package Majordomo;

$DEBUG = $main'DEBUG;

#  Mail header hacking routines for Majordomo
#
#  Derived from:
#  Routines to parse out an RFC 822 mailheader
#     E. H. Spafford,  last mod: 11/91
#  
#  ParseMailHeader breaks out the header into an % array
#    indexed by a lower-cased keyword, e.g.
#       &ParseMailHeader(STDIN, *Array);
#	use $Array{'subject'}
#
#    Note that some duplicate lines (like "Received:") will get joined
#     into a single entry in %Array; use @Array if you want them separate
#    $Array will contain the unprocessed header, with embedded
#     newlines
#    @Array will contain the header, one line per entry
#
#  RetMailAddr tries to pull out the "preferred" return address
#    based on the presence or absence of various return-reply fields


#  Call as &ParseMailHeader(FileHandle, *array)

sub main'ParseMailHeader  ## Public
{
    local($save1) = ($/);
    local($FH, *array) =  @_;
    local ($keyw, $val);

    %array = ();

    # force unqualified filehandles into callers' package
    local($package) = caller;
    $FH =~ s/^[^':]+$/$package'$&/;

    $/ = '';
    $array = $_ = <$FH>;
    s/\n\s+/ /gms;

    @array = split('\n');
    foreach $_ (@array)
    {
	($keyw, $val) = m/^([^:]+):\s*(.*\S)\s*$/gms;
	$keyw =~ y/A-Z/a-z/;
	if (defined($array{$keyw})) {
	    $array{$keyw} .= ", $val";
	} else {
	    $array{$keyw} = $val;
	}
    }
    $/ = $save1;
}


#  Call as $addr = &RetMailAddr(*array)
#    This assumes that the header is in RFC 822 format
# We used to strip the raw address from the header here, but the address is
# stripped again before it gets to the mailer and we may want to use the
# whole thing when we do a subscription.
sub main'RetMailAddr  ## Public
{
    local(*array) = @_;

    local($ReplyTo) = defined($array{'reply-to'}) ?
		$array{'reply-to'} : $array{'from'};

    $ReplyTo = $array{'apparently-from'} unless $ReplyTo;

    $ReplyTo;
}

# @addrs = &ParseAddrs($addr_list)
sub main'ParseAddrs {
    local($_) = shift;
    1 while s/\([^\(\)]*\)//g; 		# strip comments
    1 while s/"[^"]*"\s//g;		# strip comments"
    split(/,/);				# split into parts
    foreach (@_) {
	1 while s/.*<(.*)>.*/$1/;
	s/^\s+//;
	s/\s+$//;
    }

    @_;
}

# Check to see if a list is valid.  If it is, return the validated list
# name; if it's not, return ""
sub main'valid_list {
    local($listdir) = shift;
    # start with a space-separated list of the rest of the arguments
    local($taint_list) = join(" ", @_);
    # strip harmless matched leading and trailing angle brackets off the list
    1 while $taint_list =~ s/^<(.*)>$/$1/;
    # strip harmless trailing "@.*" off the list
    $taint_list =~ s/\@.*$//;
    # anything else funny with $taint_list probably isn't harmless; let's check
    # start with $clean_list the same as $taint_list
    local($clean_list) = $taint_list;
    # clean up $clean_list
    $clean_list =~ s/[^-_0-9a-zA-Z]*//g;
    # if $clean_list no longer equals $taint_list, something's wrong
    if ($clean_list ne $taint_list) {
	return ""; 
    } 
    # convert to all-lower-case
    $clean_list =~ tr/A-Z/a-z/;
    # check to see that $listdir/$clean_list exists
    if (! -e "$listdir/$clean_list") {
	return "";
    }
    return $clean_list;
}

# compare two email address to see if they "match" by converting  to all
# lower case, then stripping off comments and comparing what's left.  If
# a optional third argument is specified and it's not undefined, then
# partial matches (where the second argument is a substring of the first
# argument) should return true as well as exact matches.
#
# if optional third argument is 2, then compare the two addresses looking
# to see if the addresses are of the form user@dom.ain.com and user@ain.com
# if that is the format of the two addresses, then return true.
sub main'addr_match {
    local($a1) = &main'chop_nl(shift);
    local($a2) = &main'chop_nl(shift);
    local($partial) = shift;	# may be "undef"

    print STDERR "addr_match: enter\n" if $DEBUG;
    print STDERR "addr_match: comparing $a1 against $a2\n" if $DEBUG;

    if ($partial == 1) {
	$a1 =~ tr/A-Z/a-z/;
	$a2 =~ tr/A-Z/a-z/;
	if (index($a1, $a2) >= $[) {
	    return(1);
	} else {
	    return(undef);
	}
    }
	
    local(@a1, @a2);

    $a1 =~ tr/A-Z/a-z/;
    $a2 =~ tr/A-Z/a-z/;

    @a1 = &main'ParseAddrs($a1);
    @a2 = &main'ParseAddrs($a2);
    if (($#a1 != 0) || ($#a2 != 0)) {
	# Can't match, because at least one of them has either zero or
	# multiple addresses
	return(undef);
    }

    if ($partial == 2 && ($a1[0] ne $a2[0])) { # see if addresses are
                                               # foo@baz.bax.edu, foo@bax.edu
       local(@addr1,@addr2);
	  @addr1 = split(/\@/, $a1[0]);
	  @addr2 = split(/\@/, $a2[0]);
	  if ( $#addr1 == $#addr2 && $#addr1 == 1 && 
               $addr1[0] eq $addr2[0] && (index($addr1[1], $addr2[1]) >= $[))
	  {
	    return(1);
	  }
       }

    return($a1[0] eq $a2[0]);
}

# These are package globals referenced by &setabortaddr and &abort

$abort_addr = "owner-majordomo";

sub main'set_abort_addr {
    $abort_addr = shift unless ($#_ < $[);
}

# Abort the process, for the reason stated as the argument

local($log_disabled);
local($logging_abort, $mailing_abort);

sub main'abort { #'
    # first, tell the requestor that something bad happened.
    # XXX is this really meaningful for, say, resend?
    if (-e main'REPLY) {
	print main'REPLY <<END_MSG;
>>> Sorry, an error has occurred while processing your request
>>> The caretaker of Majordomo ( $abort_addr ) has been notified
>>> of the problem.
END_MSG
	close (main'REPLY);
    }

    # print the reason for the abort to stderr; maybe someone will see it
    print STDERR "$main'program_name: ABORT\n", join(" ",  @_), "\n";

    # log the reason for the abort, if possible.  We don't log if the
    # log is inaccessible, or if we're aborting trying to log that we're
    # aborting.
    unless ($log_disabled || $logging_abort) {
	$logging_abort = join(" ", @_);
	&main'log("ABORT", $logging_abort);
	$logging_abort = "";
    }
    else {
	# Use previous message if we recursed
	@_ = ($logging_abort) if $logging_abort;
    }

    # send a message to the Majordomo owner, if possible. We don't mail
    # if we're aborting trying to mail that we're aborting.
    if (! $mailing_abort &&
	defined($abort_addr) && defined($main'bounce_mailer)) {

	$mailing_abort = 1; # Break recursion loops

	# We must set the mailer correctly here just in case it was
	# originally set to the normal mailer; that probably won't get us
	# anywhere
	&main'set_mailer($main'bounce_mailer);
	&main'sendmail(ABORT, $abort_addr, "MAJORDOMO ABORT ($main'program_name)");#'
	print ABORT <<"EOM";

MAJORDOMO ABORT ($main'program_name)!!

@_

EOM
	close(ABORT);
    }

    exit $EX_DATAERR;
}

# bitch about a serious problem, but not fatal.

local($logging_warning, $mailing_warning);

sub main'bitch {
    # print the warning to stderr in case all else fails
    # maybe someone will see it
    print STDERR "$main'program_name: WARNING\n", join(" ", @_), "\n";

    # log the warning, if possible
    unless ($log_disabled || $logging_warning) {
	$logging_warning = 1;
	&main'log("WARNING ", join(" ", @_), "\n"); #';
	$logging_warning = 0;
    }

    # send a message to the Majordomo owner, if possible
    if (! $mailing_warning &&
	defined($abort_addr) && defined($main'bounce_mailer)) {

	$mailing_warning = 1; # Break recursion loops

	# We must set the mailer correctly here just in case it was
	# originally set to the normal mailer; that probably won't get us
	# anywhere
	&main'set_mailer($main'bounce_mailer);
	&main'sendmail(WARN, $abort_addr, "MAJORDOMO WARNING ($main'program_name)");#';
	print WARN <<"EOM";

MAJORDOMO WARNING ($main'program_name)!!

@_

EOM
	close(WARN);
	$mailing_warning = 0;
    }
}



# do a quick check of permissions.
#
sub main'check_permissions {
    local($err);
    if ( ! -w $log_file ) {
	if ( ! -e $log_file ) {			# log file may not exist, check dir perms.
	    local($dir);
	    ($dir) = $log_file =~ m@^(/\S+)/@;
	    if ( ! -w $dir ) {
		$err .= "Unable to create log file in $dir, check permissions.\n"; # 
	    }
	} else {
	    $err .= "Unable to write to log file, check permissions on $log_file\n";
	}
    }

    if ( ! -w $main'listdir ) {
	$err .= "Unable to write to list directory \$listdir, check permissions on $main'listdir\n";
    }

    if (length $err) {
	$err = "While running with an effective uid of $> and an effective gid of $), Majordomo\nran into the following problems:\n" .
	    $err;
	$log_disabled = 1;
	&main'abort($err);#';
    }
}

# These are package globals referenced by &setlogfile and &log
$log_file = "/tmp/log.$$";
$log_host = "UNKNOWN";
$log_program = "UNKNOWN";
$log_session = "UNKNOWN";

# set the log file
sub main'set_log {
    $log_file = shift unless ($#_ < $[);
    $log_host = shift unless ($#_ < $[);
    $log_program = shift unless ($#_ < $[);
    $log_session = shift unless ($#_ < $[);

}

# Log a message to the log
sub main'log {

    print STDERR "$0:  main'log()\n" if $DEBUG;

    local($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime;
    local(*MAILMSG);

    print STDERR "$0:  main'log(): opening logfile $log_file\n" if $DEBUG;

    if (&main'lopen(LOG, ">>", $log_file)) { #';
	# if the log is open, write to the log
	printf LOG "%s %02d %02d:%02d:%02d %s %s[%d] {%s} ",
	    $ctime'MoY[$mon], $mday, $hour, $min, $sec,
	    $log_host, $log_program, $$, $log_session;
	print LOG join(" ", @_), "\n";
	&main'lclose(LOG);
    } else {
	
	print STDERR "$0:  main'log(): log not open, writing to STDERR and attempting to mail.\n" if $DEBUG;

	# otherwise, write to stderr
	printf STDERR "%s[%d] {%s} ", $log_program, $$, $log_session;
	print STDERR join(" ", @_), "\n";

        # send a message to the Majordomo owner, if possible
        if (defined($abort_addr)) {
	    &main'sendmail(MAILMSG, $abort_addr, # '(
						     "MAJORDOMO NOTICE: Can't open log");
	    printf MAILMSG "%s[%d] {%s} ", $log_program, $$, $log_session;
   	    print MAILMSG join(" ", @_), "\n";
	}
    }
    print STDERR "$0:  main'log(): done\n" if $DEBUG;

}

# Globals referenced by &set_mail* and &sendmail
$mail_prog = "$sendmail_command -f\$sender -t";
$mail_from = $whoami;
$mail_sender = $whoami_owner;

# set the mailer
sub main'set_mailer {
     $mail_prog = shift;
}

# set the default from address
sub main'set_mail_from {
    $mail_from = shift;
}

# set the default sender address
sub main'set_mail_sender {
    $mail_sender = shift;
}

# Exec a mailer process
sub main'do_exec_sendmail {
    &main'abort("do_exec_sendmail, number of args <= 1 unsafe to exec")
      if scalar(@_) <= 1;
    # It makes sense to check to see that the mailer is valid here, but the
    # abort routine must make certain that recursion doesn't develop,
    # because abort calls this routine.
    &main'abort("$main'program_name: do_exec_sendmail, mailer $_[0] not executable")
      unless (-x $_[0]);
    exec(@_);
    die("Failed to exec mailer \"@_\": $!");
}

# Open a mailer on the far end of a filehandle
sub main'sendmail { #''
    local($MAIL) = shift;
    local($to) = shift;
    local($subject) = shift;
    local($from) = $mail_from;
    local($sender) = $mail_sender;
    # The following eval expands embedded variables like $sender
    local($mail_cmd) = eval qq/"$mail_prog"/;
    local($isParent);
    if ($#_ >= $[) { $from = shift; }
    if ($#_ >= $[) { $sender = shift; }

    # force unqualified filehandles into caller's package
    local($package) = caller;
    $MAIL =~ s/^[^':]+$/$package'$&/;

    # clean up the addresses, for use on the mailer command line
    local(@to) = &main'ParseAddrs($to);
    for (@to) {
	$_ = join(", ", &main'ParseAddrs($_));
    }
    $to = join(", ", @to);  #';

print STDERR "$0: main'sendmail:  To $to, Subject $subject, From $from\n" 
    if $DEBUG;
print STDERR "$0: main'sendmail:  Sender $sender, mail_cmd = $mail_cmd\n"
    if $DEBUG;

    # open the process
    if (defined($isParent = open($MAIL, "|-"))) {
 	&main'do_exec_sendmail(split(' ', $mail_cmd))
 	    unless ($isParent);
     } else {
 	&main'abort("Failed to fork prior to mailer exec");
     }

    # Generate the header.  Note the line beginning with "-"; this keeps
    # this message from being reprocessed by Majordomo if some misbegotten
    # mailer out there bounces it back.
    print $MAIL 
"To: $to
From: $from
Subject: $subject
Reply-To: $from

--

";
    
    return;
}

# check the password for a list
sub main'valid_passwd {
    local($listdir, $list, $passwd) = @_;

    # is it a valid list?
    local($clean_list) = &main'valid_list($listdir, $list);
    if ($clean_list ne "") {
	# it's a valid list check config passwd first 
        if (defined($main'config_opts{$clean_list,"admin_passwd"}) &&
            $passwd eq $main'config_opts{$clean_list,"admin_passwd"} ) 
	      {	return 1; }

	# read the password from the file in any case
	if (&main'lopen(PASSWD, "", "$listdir/$clean_list.passwd")) {
	    local($file_passwd) = <PASSWD>;
	    &main'lclose(PASSWD);
	    $file_passwd = &main'chop_nl($file_passwd);
	    # got the password; now compare it to what the user sent
	    if ($passwd eq $file_passwd) {
		return 1;
	    } else {
		return 0;
	    }
	} else {
	    return 0;
	}
    } else {
	return 0;
    }
}

# Check to see that this is a valid address. 
# A valid address is a single address with 
# no "|" in the address part. It may not start with a - either.
# If it has a / in it, we use some heuristics to find out if the address
# may be a file. Some other heuristics attempt to look for a valid X.400
# address. This is not infalible.
sub main'valid_addr {
    local($addr, $list) = @_;
    local(@addrs, $temp);

    # Parse the address out into parts
    @addrs = &main'ParseAddrs($addr);

    # if there's not exactly 1 part, it's no good
    # XXX Should inform the poor user of this fact.
    if ($#addrs != 0) {
	return undef;
    }

    local($_) = $addrs[0];

    # Deal with unbalanced brackets or parenthesis in an address.
    $temp = $_;

    # Nuke anything within quotes.
    1 while $temp =~ s/(^|([^\\\"]|\\.)+)\"(([^\\\"]|\\.)*|$)\"?/$1/g;

    # Remove nested parentheses " <- placate emacs' highlighting
    1 while $temp =~ s/\([^\(\)]*\)//g;

    # Remove nested angle brackets
    1 while $temp =~ s/\<[^\<\>]*\>//g;

    # remove nested square brackets
    1 while $temp =~ s/\[[^\[\]]*\]//g;

    # If any parentheses of brackets remain, they are unbalanced and the
    # address is illegal.
    if ($temp =~ /[\(\)\<\>\[\]]/) {
	if (-e main'REPLY) {
	    print main'REPLY <<"EOM"
**** The address you supplied, $_
**** Does not seem to be a legal Internet address.  It seems to have an
**** uneven number of parentheses or brackets.
	
EOM

	}
	&main'log("WARNING", "Unbalanced address: $_");
	return undef;
    }

    if ($temp =~ /[,;:]/) {
        if (-e main'REPLY) {
            print main'REPLY <<"EOM"
**** The address you supplied, $_
**** Does not seem to be a legal Internet address.  It seems to have
**** unquoted colons, commas, or semicolons.

EOM

        }
        &main'log("WARNING", "Illegal chars in address: $_");
        return undef;
    }


    # Deal with legal spaces in a stripped address, then check and reject
    # any remaining space.  Note that as I write this, the comment stripper
    # ParseAddrs does not handle things like a quoted local part but I've
    # included the correct routines just in case it ever does.
    $temp = $_;

    # We assume that the comment stripper will have eaten leading and
    # trailing space.

    # This mess turns "jason ti bb i tt s"@hpc.uh.edu into
    # "jasontibbitts"@hpc.uh.edu
    1 while $temp =~ s/\"(.*)\s(.*)\"/\"$1$2\"/g;

    # This compresses space before dots or `@'s. " <- placate emacs' highlighting
    1 while $temp =~ s/\s(\.|@)/$1/g;

    # This compresses space after dots or `@'s.
    1 while $temp =~ s/(\.|@)\s/$1/g;

    # We've taken out all legitimate space from the address (yes, RFC822
    # permits that kind of bogosity), so if the address has spaces, we have
    # a problem.
    if ($temp =~ /\s/) {
	if (-e main'REPLY) {
	    print main'REPLY <<"EOM";
**** The address you supplied, $_
**** does not seem to be a legal Internet address.  You may have supplied
**** your full name instead of your address, or you may have included your
**** name along with your address in a manner that does not comply with
**** Internet standards for addresses.
**** It is also possible that you are using a mailer that wraps long lines
**** and the end of your request ended up on the following line.  If the
**** latter is true, try using backslashes to split long lines.  (Split the
**** line between words, then put a backslash at the end of all but the
**** last line.)

EOM
	}
	&main'log("WARNING", "Illegal space in address: $_");
	return undef;
    }

    # Addresses must have both an @ and a .
    if (!(/\@/ && /\./)) {
	if (-e main'REPLY) {
	    print main'REPLY <<"EOM";
**** The address you supplied, $_
**** is not a complete address.  When providing an address, you must give
**** the full name of the machine including the domain part (like
**** host.corp.com), not just your user name or your name and the short
**** name of the machine (just user or user\@host is not legal).

EOM
	}
	&main'log("WARNING", "Non-domained address: $_");
	return undef;
    }

    
    # o  if there's a "|" in it, it's hostile
    # o  if there is a - sign at the front of the address, it may be an attempt
    #    to pass a flag to the MTA
    # o  bail if they're attempting to subscribe the list to itself
    # 

    print STDERR "$0: valid_addr: comparing '$addr' to '$list'\n" if $DEBUG;

    # XXX Should at least tell the user that there was a problem.
    if ( /\|/ || /^-/ ) {
	&main'abort("HOSTILE ADDRESS (invalid first char or |) $addr"); #'
	return undef;
    }

    # Some sendmails are dumb enough to do bad things with this
    if (/\:include\:/) {
        &main'abort("HOSTILE ADDRESS (tried to use :include: syntax) $addr"); #'
        return undef;
    }

    if ( $addr eq $list ) {
	&main'abort("HOSTILE ADDRESS (tried to subscribe list) $addr"); # '
	return undef;
    }

    # if the is a / in it, it may be an attempt to write to a file.
    # or it may be an X.400, HP Openmail or some other dain bramaged
    # address 8-(. We check this by breaking the address on '/'s
    # and checking to see if the first component of the address
    # exists. If it does we bounce it as a hostile address.

    # XXX Again, we shouldn't be aborting without telling the user
    if ( m#/# ) {
	local(@components) = ($_ =~ /([\/\@]?[^\/\@]+)/g);

	&main'abort("HOSTILE ADDRESS (path exists to /file) $addr")
                if (-e "/$components[0]"); #'
	&main'abort("HOSTILE ADDRESS (path exists to file) $addr")
                if (-e "$components[0]"); #'

       # then as an extra check that can be turned off in the majordomo.cf
       # file we make sure that the last component of the address has an
       # @ sign on it for an X.400->smtp gateway translation.

        if (!$main'no_x400at) {
	    &main'abort("HOSTILE ADDRESS (no x400 \@) $addr") if (
                    "$components[$#components]" !~ /\@/);  #'
	}

        # check to see that the c= and a[dm]= parts exist
	if (!$main'no_true_x400) {
            &main'abort("HOSTILE ADDRESS (no x400 c=) $addr")
                    if ($_ !~ m#/c=#); #'
            &main'abort("HOSTILE ADDRESS (no x400 a[dm]=) $addr")
                    if ($_ !~ m#/a[dm]=#); #'
       }
   }

print STDERR "$0: valid_addr: exit\n" if $DEBUG;

   return $_;
}

# is this a valid filename?
sub main'valid_filename {
    local($directory) = shift;
    local($list) = shift;
    local($suffix) = shift;
    local($taint_filename) = shift;
    local($clean_filename);

    # Safety check the filename.
    if ($taint_filename =~ /^[\/.]|\.\.|[^-_0-9a-zA-Z.\/] /) {
	return undef;
    } else {
	$clean_filename = $taint_filename;
    }
    if (! -f "$directory/$list$suffix/$clean_filename") {
	return undef;
    }
    return "$directory/$list$suffix/$clean_filename";
}

# Chop any trailing newlines off of a string, and return the string
sub main'chop_nl {
    if ($#_ >= $[) {
	local($x) = shift;
	$x =~ s/\n+$//;
	return($x);
    } else {
	return(undef);
    }
}

# Perform simple filename globbing, so we don't have to use the <...> glib
# syntax which has caused problems.
sub main'fileglob {
    local($dir) = shift;
    local($pat) = shift;
    local(@files) = ();

    opendir(DIR, $dir) || return undef;
    @files = grep(/$pat/, readdir(DIR));
    grep($_ = "$dir/$_", @files);  # perl4 doesn't have map!

    closedir(DIR);

    return @files;
}

sub main'is_list_member {
    local($subscriber, $listdir, $clean_list, $file) = @_;
    local($matches) = 0;
    local(*LIST);
    local($_);

    print STDERR "is_list_member: enter\n" if $DEBUG;

    $file = "$listdir/$file" if defined $file && $file !~ m|^/|;
    $file = "$listdir/$clean_list" unless defined $file;
    print STDERR "is_list_member: checking $file for $subscriber\n"
	if $DEBUG; 
    if (open(LIST, $file)) {
	while (<LIST>) {
	    if (&main'addr_match($subscriber, $_, 
	       (&main'cf_ck_bool($clean_list,"mungedomain") ? 2 : undef))) {
		$matches++;
		last;
	    }
	}
	close(LIST);
    }
    else {
	&main'bitch("Can't read $file: $!"); #'"";
    }

    print STDERR "is_list_member: exit $matches\n" if $DEBUG;

    return($matches);
}

# From: pdc@lunch.engr.sgi.com (Paul Close)
# > Shouldn't list and list-digest  be equivalent for things like
# > retrieval of files? As it stands now, if I subscribe to
# > foo-list-digest and I want to retrieve a file for foo-list or list the
# > members of foo-list, and foo-list is a private list for these
# > purposes, then I'm out of luck.
# 
# I agree.  The approach I took for solving this was to add a function called
# private_okay() to use instead of list_member() in cases where you wanted to
# restrict function to members of the list or list-digest.
# 
# If restrict_post is defined, private_okay searches those lists, otherwise
# it searches list and list-digest.  Anywhere majordomo consults a private_*
# variable, I use private_okay instead of list_member.  Works quite nicely.
#
# Added in access checking mechanisms as well to replace
# private_XYZ with some flexability.  This will be exanded to be
# more flexible than the current [open|list|closed] capability.
#  --Chan 96/04/23
#
sub main'access_check {
    local($cmd, $subscriber,$listdir,$clean_list) = @_;
    local(@lists,$list,$altlist,$total);

    print STDERR "access_check: enter\n" if $DEBUG;

    # bail right away if the command is disabled.
    # 
    if ($main'config_opts{$clean_list, "${cmd}_access"} =~ /closed/) {#'
	print STDERR "access_check: ${cmd}_access is closed.\n" if $DEBUG;
	return 0 ;
    }

    # bail right away if the command is wide open
    #
    if ($main'config_opts{$clean_list, "${cmd}_access"} =~ /open/) {#'
	print STDERR "access_check: ${cmd}_access is open.\n" if $DEBUG;
	return 1;
    }
    
    # now check a little deeper.
    #
    if ( length($main'config_opts{$clean_list,'restrict_post'} )) {
        @lists = split(/[:\s]+/,
                     $main'config_opts{$clean_list,'restrict_post'});
    } else {
        if ($clean_list =~ /(.*)-digest/) {
            $altlist = $1;
        } else {
            $altlist = "$clean_list-digest";
        }
        @lists = ($clean_list);
	push(@lists, $altlist) if -e "$listdir/$altlist";
    }

    print STDERR "access_check: checking lists " , join(', ', @lists), "\n" 
	if $DEBUG;

    $total = 0;
    foreach $list (@lists) {
	$total += &main'is_list_member($subscriber, $listdir, $clean_list, $list);
    }
    print STDERR "access_check: exit\n" if $DEBUG;
    return $total;
}

1;
