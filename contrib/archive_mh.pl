#!/bin/perl

# archive: A hack to use mh to handle the archives
#
# You may redistribute this file, or inlcude it into the offical majordomo
#   package
#
# $Source: /sources/cvsrepos/majordomo/contrib/archive_mh.pl,v $
# $Revision: 1.4 $
# $Date: 1997/03/10 15:40:41 $
# $Author: cwilson $
# $State: Exp $
#
# $Locker:  $

# set our path explicitly
$ENV{'PATH'} = "/bin:/usr/bin:/usr/ucb";

# Read and execute the .cf file
$cf = $ENV{"MAJORDOMO_CF"} || "/tools/majordomo-1.56/majordomo.cf";
if ($ARGV[0] eq "-C") {
    $cf = $ARGV[1];
    shift(@ARGV); 
    shift(@ARGV); 
}
if (! -r $cf) {
    die("$cf not readable; stopped");
}
require "$cf"; 

# Go to the home directory specified by the .cf file
chdir("$homedir");

exec("/tools/mh-6.8/lib/mh/rcvstore +$filedir/$ARGV[0] -nocreate\n");
