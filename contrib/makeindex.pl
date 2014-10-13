#!/bin/perl
#
# Given an archive directory, create a table of contents file and a topics
# file.  The table of contents file simply lists each subject that appears
# in each archive file, while the topics file is a list of each unique
# subject and the files that subject appears in.
#
# I run this from cron every night....
#
# Paul Close, April 1994
#

if ($#ARGV != -1) {
    $dir = $ARGV[0];
    shift;
}
else {
    die "usage: $0 archive_directory\n";
}

opendir(FILES, $dir) || die "Can't open directory $dir: $!\n";
@files = readdir(FILES);	# get all files in archive directory
closedir(FILES);

open(INDEX,">$dir/CONTENTS") || die "Can't open $dir/CONTENTS: $!\n";
open(TOPICS,">$dir/TOPICS") || die "Can't open $dir/TOPICS: $!\n";

foreach $basename (@files) {
    next if $basename eq '.';
    next if $basename eq '..';
    next if $basename eq "CONTENTS";
    next if $basename eq "TOPICS";
    print INDEX "\n$basename:\n";
    open(FILE, "$dir/$basename") || next;
    while (<FILE>) {
	if (/^Subject:\s+(.*)/i) {
	    ($subj = $1) =~ s/\s*$//;
	    next if $subj eq "";
	    #
	    # for index file, just print the subject
	    #
	    print INDEX "    $subj\n";
	    #
	    # for topics file, strip Re:'s, remove digest postings,
	    # and trim the length to 40 chars for pretty-printing.
	    #
	    1 while ($subj =~ s/^Re(\[\d+\]|2?):\s*//i);  # trim all Re:'s
	    next if $subj eq "";
	    next if $subj =~ /[A-Za-z]+ Digest, Volume \d+,/i;
	    next if $subj =~ /[A-Za-z]+ Digest V\d+ #\d+/i;
	    if (length($subj) > 40) {
		$subj = substr($subj, 0, 37) . "...";
	    }
	    #
	    # Make a key that's all lower case, and no whitespace to
	    # reduce duplicate topics that differ only by those.  This
	    # also results in a list of topics sorted case-independent.
	    #
	    ($key = $subj) =~ tr/A-Z/a-z/;
	    $key =~ s/\s+//g;
	    $subjlist{$key} .= "$basename,";
	    if (!defined($realsubj{$key})) {
		$realsubj{$key} = $subj;
	    }
	}
    }
    close(FILE);
}
close(INDEX);

foreach $subj (sort keys %subjlist) {
    #
    # for each subject, record each file it was found in
    #
    undef %found;
    undef @names;
    for (split(",", $subjlist{$subj})) {
	$found{$_} = 1;
    }
    #
    # make list of 'found' names and wrap at 80 columns
    #
    $names = join(", ", sort keys %found);
    undef @namelist;
    while (length($names) > 40) {
	$index = 40;
	$index-- until (substr($names, $index, 1) eq " " || $index < 0);
	push(@namelist,substr($names,0,$index));
	$names = substr($names,$index+1);
    }
    push(@namelist,$names);
    printf TOPICS "%-40s %s\n", $realsubj{$subj}, $namelist[0];
    for ($i=1; $i <= $#namelist; $i++) {
	print TOPICS " " x 41, $namelist[$i], "\n";
    }
}
close(TOPICS);

