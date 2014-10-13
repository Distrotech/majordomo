#!/usr/local/gnu/bin/perl
#
# md-sub.cgi
#
# Author: John Orthoefer <jco@direwolf.com>
# Date: 17 Jan 1996
# 
# Introduction
#   This cgi allows people web surfing to subscribe to mailing list.
#   It presents the person with a form when called with out options.
#   when called with options it will send a mail message to the 
#   mailing list.
#
# Installing
#   To install this software:
#     o put the script in the cgi-bin directory
#     o set the following varables up for your site
#         cgiloc   - url of this script as refered to via the web
#         listsdb  - where the database of lists is going to live
#         logfile  - where the log for script activity should go
#         sendmail - the sending e-mail program, it should have the
#                    option to read the incoming stream for the To
#                    address set, '-t' on sendmail.
#     o initialize the database
#       + list all your mailing lists and contact addresses in a file
#         one per line as in
#            firewalls          majordomo@greatcircle.com
#            warhammerfb        majordomo@direwolf.com
#            majordomo-workers  majordomo@greatcircle.com
#            default            warhammerfb
#            help               webmaster@here.org
#
#         note: there are 3 special names
#            default  -- This is the mailing list that will be 
#                        selected when the form is first
#                        presented to the user.
#            help     -- This is the address for people to send 
#                        help to.
#            info     -- This is used to specify a URL for information about
#                        a mailing list.
#                        the format is:
#                           info listname url
#                        where: listname matches a list that is specifed 
#                                   elsewhere in the file.
#                               url is some url on the web.
#       + then run the the script with the '-C filename' option 
#         to construct the database.  The create option will only 
#         add to the database.  If you want to clear the database, 
#         you need to 'rm $listsdb*' (there will be two file a 
#         .dir and .pag file.)
#    o add a link to the scripts URL in your web pages.
#       + if you want to make different default mailing lists based on
#         which pages you came from you can do this by passing the param
#            default=listname 
#         as part of the URL.
#         ie:   <href url="http://mypage.domain.org/md-sub.cgi?default=mylist">
#         This will cause mylist to be the default selected one instead of 
#         the database default.
#
# Misc
#   This script needs two perl libs cgi-lib.pl (included in this 
#   distrubution.) and getopts.pl (which should be included with 
#   your perl distrubution.)
#
# Scalars that need to be changed
#
$cgiloc   = "http://stout/~jco/md-sub.cgi";
$listsdb  = "/usr/jco/.md-subrc";
$logfile  = "/usr/jco/md-sub.log";
#$sendmail = "|/usr/lib/sendmail -t";
$sendmail = "|/usr/bin/cat - > /tmp/test.out"; # This one is for 
				#  testing...

# !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
#             NOTHING BELOW HERE SHOULD NEED TO BE CHANGED
# !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

#
# Required file
require 'cgi-lib.pl';
require 'getopts.pl';

#
# Version number
$version = "1.0";

#
# Info
$info = "jco\@direwolf.com";

#
# Call Getopts
&Getopts( 'C:v');

#
# Check to see if we are creating a DB
if ($opt_C) {
    &create_lists( $opt_C);
    exit 0;
}

#
# Check to see if the version is being intergated.
if ($opt_v) {
    print "Version: $version\n";
    exit 0;
}

#
# Read the list DB
&load_lists;

#
# Figure out if we have a filled in form or we need to send a form
if (&ReadParse && !defined( $in{ 'default'})) {
    if (defined $in{ 'infopage'} ) {
       &infopage;
    } else {
       $in{ 'mailing_list'} =~ s/\*$//;  # drop the * at the end of the name.
       &sendmessage;
    }
} else {
    &form;
}

#
# Birthday party, cheesecake, jelly bean, boom!
#             R.E.M.
exit 0;

#
# create_lists
#   Create the DBM file.
sub create_lists {
    local( $file) = @_;

    open( LISTS, $file);
    dbmopen( %MLRC, $listsdb, 0644);

    while( <LISTS>) {
	chop;
	($name, $address) = /(\S*)\s*(.*)/;
	if ($name =~ /info/i) {
	   ($name, $address) = $address =~/(\S*)\s*(.*)/;
           $MLRC{ "LISTINFO-$name"} = $address;
	   @info = (@info, $name);
	} else {
	   @ml = (@ml, $name);
	   $MLRC{ "LISTNAME-$name"} = $address;
	}
    }

    $MLRC{ 'mailing-lists'} = join( ";", @ml);
    $MLRC{ 'mailing-info'} = join( ";", @info);
    dbmclose( MLRC);
}

#
# load_lists
#   read in the DBM file.
sub load_lists {
    if (!dbmopen( %MLRC, $listsdb, undef)) {
	&log( "Can't open $listsdb");
	exit 1;
    }

    foreach $i (split(/;/, $MLRC{'mailing-lists'})) {
	$ml{$i} = $MLRC{ "LISTNAME-$i"};
    }

    foreach $i (split(/;/, $MLRC{'mailing-info'})) {
	$mi{$i} = $MLRC{ "LISTINFO-$i"};
    }

    dbmclose( MLRC);
}

#
# form
#   Present the form to the user to fill out
sub form {

# Form header
    print <<EOF;
Content-type: text/html

<html>
<title>Mailing List Subscription</title>
<body>
<font size=5>
<center><b>Mailing List Subscription Form</b></center>
</font>
<br>

To subscribe to any of these mailing lists all you need to do is fill
out the form compeletly.  And submit it.  The form will then be
processed and you should be added to the mailing list shortly.<p>

EOF

if (defined %mi) {
 print <<EOF;

If a mailing list has a star (*) after it.  That means there is online info
about that list.  To access the descriptions for those lists click 
<a href=\"$cgiloc?infopage\">here</a>.<p>

EOF
}

print <<EOF;
<hr>
<form action="$cgiloc" method="post">
Mailing List:
EOF

# Generate the list of mailing lists
    print "<select name=\"mailing_list\">\n";
    foreach $i (keys %ml) {
	next if ($i eq 'default');
	next if ($i eq 'help');
	if ( $i eq $in{ 'default'}) {
	   print "<option selected>$i";
	} elsif ( $i eq $ml{ 'default'} && !defined( $in{ 'default'})) {
	    print "<option selected>$i";
	} else {
	    print "<option>$i";
	}
	print "*" if (defined $mi{ $i});
        print "\n";
    }
    print "</select>\n";

# form trailer
print <<EOF
<br>
Real name: <input type="text" name="rname" size=30> <br>
E-mail Address: <input type="text" name="email" size=30> <br>
<br>
What action would you like to take?
<blockquote>
<input checked type=radio name="function" value="subscribe">Subscribe 
to the list<br>
<input type=radio name="function" value="unsubscribe">Unsubscribe from 
the list<br>
<input type=radio name="function" value="who">Have a list of who is on the list
mailed to you<br>
<input type=radio name="function" value="info">Get a detailed description 
of the list mailed to you<br>
</blockquote>
<input type="submit" value="Send request"> 
<input type="reset" value="Reset">

</form>
<hr>
<address>
<a href="mailto:$ml{ 'help'}">Webmaster</a> / 
<a href="mailto:$info>md-sub.cgi</a> /
$version
</address>
</body>
</html>
EOF
}

#
# infopage
#    This sends the page with all the info lists on it.

sub infopage {

print <<EOF;
Content-type: text/html

<html>
<title>Mailing List Information</title>
<body>
<font size=5>
<center><b>Mailing List Information</b></center>
</font>
<br>
<hr>
EOF
    print "<ul>\n";
    foreach $i (keys %mi) {
	    print "<li><a href=\"$mi{ $i}\">$i</a>\n";
    }
    print "</ul>\n";

print <<EOF;
<hr>
<address>
<a href="mailto:$ml{ 'help'}">Webmaster</a> / 
<a href="mailto:$info>md-sub.cgi</a> /
$version
</address>
</body>
</html>
EOF
}

#
# log
#    This routine is called to print data out to the log file it should
#    be trival to make it use syslog if you are so inclined.
sub log {
    local( $msg) = @_;


    open( LOG, ">>$logfile");

    print LOG &DTG;
    print LOG " - $msg\n";

    close( LOG);
    
}

#
# DTG
#    Date Time Group, This is a military thing.  Express time in GMT (aka 
#    Zulu) it this kinda funky format (ddhhmmZ MON YY).  I used it because 
#    it's a canned routine I have. 
sub DTG {
    local( $time) = @_;
    local( @months) = ( 'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 
		       'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC');

    $time = time if ($time);
    sprintf( "%2.2d%2.2d%2.2dZ %s %2.2d", 
	    (gmtime( $time))[3],
	    (gmtime( $time))[2], 
	    (gmtime( $time))[1], 
	    @months[(gmtime( $time))[4]],
	    (gmtime( $time))[5]);
}

#
# sendmessage
#    This is the worker routine.  Sends a nice HTML message to the user and 
#    sends a nice e-mail to the mailing list admin.
# 
sub sendmessage {
    local( $i);

    if ($in{ 'email'} eq "") {
	print <<EOF;
Content-type: text/html

<html>
<font size=6>
<center><b>SORRY</b></center><br>
</font>
I'm sorry but you must fill in your e-mail address.
Press "back" and try again.
</html>
EOF

exit 0;
}
    $in{ 'email'} = "$in{ 'email'}@$ENV{'REMOTE_HOST'}" 
	if ( !( $in{ 'email'} =~ /\S*@\S*/));

    &log( "<$in{ 'email'}> \"$in{ 'rname'}\" ".
          "$in{ 'function'} $in{ 'mailing_list'}");

    open( SM, "$sendmail");
    print SM <<EOF;
To: $ml{$in {'mailing_list'}}
From: "$in{ 'rname'}" <$in{'email'}>
Reply-To: "$in{ 'rname'}" <$in{'email'}>

$in{ 'function'} $in{'mailing_list'}
EOF
    close( SM);

print <<EOF;
Content-type: text/html


<HTML>
<TITLE>Thank You</TITLE>
<BODY>
<FONT SIZE=5>
<CENTER><B>THANK YOU</B></CENTER>
</FONT><br>
Your request has been forwarded to the list owner for processing.  
You should be added soon. 
<br>

If the list owner has any questions about adding you they should be in
touch with you shortly.
<br>
<br>
The following information will be sent for you:
<br>
<br>
<TT>
EOF

    print "To: $ml{$in {'mailing_list'}}<br>\n";
    print "From: \"$in{ 'rname'}\" &lt;$in{'email'}&gt;<br><br>\n";

    print "$in{ 'function'} $in{'mailing_list'} <br>\n";

    print <<EOF;

</TT>
</BODY>
</HTML>
EOF

}
