#!/bin/perl

# Copyright 1993, D. Brent Chapman.  All Rights Reserved.  For use by
# permission only.
#
# $Source: /sources/cvsrepos/majordomo/archive2.pl,v $
# $Revision: 1.11 $
# $Date: 2000/01/07 11:00:49 $
# $Author: cwilson $
# $State: Exp $
#
# $Locker:  $
#
# archive -f <archive> {-u|-a} [-d|-m|-y] [file ...]
# 	-f <archive> REQUIRED; specifies base file name for archive
# 	-u	Input is a UNIX archive (separated by "From " lines) to split
# 	-a	Input is a message to append to archive
# 	-d	Archive file is <archive>.YYMMDD
# 	-D	Archive file is <archive>.YYYYMMDD
# 	-m	Archive file is <archive>.YYMM
# 	-M	Archive file is <archive>.YYYYMM
# 	-y	Archive file is <archive>.YY
# 	-Y	Archive file is <archive>.YYYY
# Exactly one of "-u" or "-a" must be specified.
# At most one of "-d", "-D", "-m", "-M", "-y", or "-Y" may be specified;
# if none is specified, archive name is simply <archive>
# 
# An example of using "archive" to split an existing UNIX-style archive
# named "my-list.archive" into by-day archive files named "my-list.YYMMDD":
# 
# 	archive -f my-list -d -u my-list.archive
# 
# A sample /etc/aliases file entry to use "archive" add each incoming message
# to a "my-list.YYMM" file in the "/usr/local/mail/lists/my-list.archive"
# directory:
# 
# 	my-list-archive: "|/usr/local/mail/majordomo/wrapper archive
# 		-f /usr/local/mail/lists/my-list.archive/my-list
# 		-m -a"

# set our path explicitly
# PATH it is set in the wrapper, so there is no need to set it here.
#$ENV{'PATH'} = "/bin:/usr/bin:/usr/ucb";

($program_name = $0) =~ s|.*/||;

# Change directory to our home
chdir($ENV{'HOME'}) if $ENV{'HOME'};
 
# Read and execute the .cf file
$cf = $ENV{"MAJORDOMO_CF"} || "/etc/majordomo.cf";
if ($ARGV[0] eq "-C") {
    $cf = $ARGV[1];
    shift(@ARGV); 
    shift(@ARGV); 
}
if (! -r $cf) {
    die("$cf not readable; stopped");
}
require "$cf";

# All these should be in the standard PERL library
unshift(@INC, $homedir);
require "ctime.pl";		# To get MoY definitions for month abbrevs
require "majordomo_version.pl";	# What version of Majordomo is this?
require "majordomo.pl";		# all sorts of general-purpose Majordomo subs
require "shlock.pl";		# NNTP-style file locking

$hostname = &chop_nl(`hostname`);
&set_abort_addr($whoami_owner);
&set_log($log, $hostname, $program_name, "UNKNOWN");

# Here's where the fun begins...

require "getopts.pl";

$m = 1;
foreach (@ctime'MoY) {
    $MoY{$_} = $m++;
}

$usage = "Usage: $0 -f <file> {-u|-a} [-d|-D|-m|-M|-y|-Y] [file ...]";

&Getopts("f:uadDmMyY") || die("$usage\nStopped");

if (!defined($opt_f)) {
    print STDERR "'-f <list>' required\n$usage\n";
    exit 1;
}

$sendmail_command = $sendmail_command || "/usr/lib/sendmail";
$bounce_mailer = $bounce_mailer || "$sendmail_command -f\$sender -t";
&set_abort_addr($whoami_owner);
&set_mail_from($whoami);
&set_mail_sender($whoami_owner);
&set_mailer($bounce_mailer);
&set_log($log, $hostname, $program_name, $opt_f);

if (defined($opt_a)) { $mutex++; }
if (defined($opt_u)) { $mutex++; }
if ($mutex != 1) {
    print STDERR "Either '-a' or '-u' required\n$usage\n";
    exit 2;
}

$mutex = 0;

if (defined($opt_d)) { $mutex++; }
if (defined($opt_D)) { $mutex++; }
if (defined($opt_m)) { $mutex++; }
if (defined($opt_M)) { $mutex++; }
if (defined($opt_y)) { $mutex++; }
if (defined($opt_Y)) { $mutex++; }
if ($mutex > 1) {
    print STDERR "Only one of '-d', '-D', '-m', '-M', -y', or '-Y' allowed\n$usage\n";
    exit 3;
}

if (defined($opt_a)) {
    ($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst) = 
	localtime(time);
    &open_archive(FILE, $year, $mon + 1, $mday);
}
    
while (<>) {
    # remove Approved header (Doh!) if present and still in the header.
    next if /^Approved:/ && $. < 30;
    if (/^From\s/) {
	if (/^From\s+\S+\s+(Sun|Mon|Tue|Wed|Thu|Fri|Sat)\s+(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\s+\d\d?\s+\d\d?:\d\d:\d\d\s+\d{2,4}\s*$/i) {
	    if (defined($opt_u)) {
		if (defined($is_open)) {
		    print FILE "\n";
		    &lclose(FILE);
		}
		&open_archive_unix(FILE, $_);
	    }
	    print FILE "$_";
	} else {
	    print FILE ">$_";
	}
    } else {
	print FILE $_;
    }
}

print FILE "\n";
&lclose(FILE);

sub open_archive_unix {
    local($FH) = shift;
    local($from) = shift;
    local($junk, $addr, $dow, $moy, $dom, $time, $year, @rest);

    ($junk, $addr, $dow, $moy, $dom, $time, $year, @rest) = split(/\s+/,$from);
    &open_archive($FH, $year % 100, $MoY{$moy}, $dom);
}

sub open_archive {
    local($FH) = shift;
    local($year) = shift;
    local($mon) = shift;
    local($mday) = shift;
    local($suffix);

    if (defined($opt_y)) {
	$suffix = sprintf(".%02d", $year % 100);
    }
    if (defined($opt_Y)) {
	$suffix = sprintf(".%04d", $year + 1900);
    }
    if (defined($opt_m)) {
	$suffix = sprintf(".%02d%02d", $year % 100, $mon);
    }
    if (defined($opt_M)) {
	$suffix = sprintf(".%04d%02d", $year + 1900, $mon);
    }
    if (defined($opt_d)) {
	$suffix = sprintf(".%02d%02d%02d", $year % 100, $mon, $mday);
    }
    if (defined($opt_D)) {
	$suffix = sprintf(".%04d%02d%02d", $year + 1900, $mon, $mday);
    }

    &lopen($FH, ">>", "$opt_f$suffix") || 
	die("Can't append to $opt_f$suffix: $!");
    $is_open = 1;
    chmod 0664, "$opt_f$suffix";
}
