#!/bin/perl
#
# Print various statistics about the Log file
#
# Todo: summarize admin commands
#
# Paul Close, April 1994
#

while (<>) {
    if (($mon,$day,$time,$who,$cmd) =
	/([A-Za-z]+) (\d+) ([\d:]+)\s+.*majordomo\[\d+\]\s+{(.*)} (.*)/)
    {
	@f = split(' ',$cmd);
	$cmd = $f[0];
	$f[1] =~ s/[<>]//g;
	$f[2] =~ s/[<>]//g;
	$count{$cmd}++;

	# help
	# lists
	# which [address]
	# approve PASSWD ...
	if ($cmd eq "approve" ||
	    $cmd eq "help" ||
	    $cmd eq "lists" ||
	    $cmd eq "which")
	{
	    ${$cmd}++;
	}

	# index list
	# info list
	# who list
	elsif ($cmd eq "index" ||
	       $cmd eq "info" ||
	       $cmd eq "who")
	{
	    if ($#f == 1) {
		$lists{$f[1]}++;
		$f[1] =~ s/-//g;
		${$f[1]}{$cmd}++;
	    } else {
		$bad{$cmd}++;
	    }
	}

	# get list file
	# newinfo list passwd
	elsif ($cmd eq "get" ||
	       $cmd eq "newinfo")
	{
	    if ($#f == 2) {
		$lists{$f[1]}++;
		$f[1] =~ s/-//g;
		${$f[1]}{$cmd}++;
		if ($cmd eq "get") {
		    $req = &ParseAddrs($who);
		    $long{$req} = $who;
		    $getcount{$req}++;
		}
	    } else {
		$bad{$cmd}++;
	    }
	}

	# subscribe list [address]
	# unsubscribe list [address]
	elsif ($cmd eq "subscribe" ||
	       $cmd eq "unsubscribe")
	{
	    if ($#f >= 1) {
		$lists{$f[1]}++;
		$f[1] =~ s/-//g;
		${$f[1]}{$cmd}++;
	    } else {
		$bad{$cmd}++;
	    }
	}

	# request cmd list subscribe (for approval)
	elsif ($cmd eq "request") {
	    if ($#f >= 2) {
		$lists{$f[2]}++;
		$f[2] =~ s/-//g;
		${$f[2]}{$cmd}++;
	    } else {
		$bad{$cmd}++;
	    }
	}

	else {
	    $unrecognized{$cmd}++;
	}
    } else {
	warn "line $. didn't match!\n" if !/^$/;
    }
}

#print "Command summary:\n";
#foreach $cmd (sort keys %count) {
#    printf "    %-20s %4d\n", $cmd, $count{$cmd};
#}

print "Global commands:\n";
printf("    %-15s %4d\n", "help", $help) if defined($help);
printf("    %-15s %4d\n", "lists", $lists) if defined($lists);
printf("    %-15s %4d\n", "which", $which) if defined($which);
print "\n";

#print "Unrecognized commands:\n";
#foreach $cmd (sort keys %unrecognized) {
#    printf "    %-15s %4d\n", $cmd, $unrecognized{$cmd};
#}
#print "\n";

if (defined(%bad)) {
    print "Incomplete commands:\n";
    foreach $cmd (sort keys %bad) {
	printf "    %-15s %4d\n", $cmd, $bad{$cmd};
    }
    print "\n";
}

# skip request and newinfo
print "List                 subscr  unsub  index    get   info    who config approve\n";
foreach $list (sort keys %lists) {
    printf "%-20s", substr($list,0,20);
    $list =~ s/-//g;
    %l = %{$list};
    printf " %6d %6d %6d %6d %6d %6d %6d %6d\n", $l{subscribe}, $l{unsubscribe},
       $l{index}, $l{get}, $l{info}, $l{who}, $l{config}, $l{approve};
}
print "\n";

@reqs = sort {$getcount{$b}<=>$getcount{$a};} keys %getcount;
if ($#reqs >= 0) {
    print "Top requestors (get command):\n";
    for ($i=0; $i < 5; $i++) {
	printf "    %5d  %s\n", $getcount{$reqs[$i]}, $long{$reqs[$i]};
	last if ($i == $#reqs);
    }
}

# from majordomo.pl, modified to work on a single address
# $addrs = &ParseAddrs($addr_list)
sub ParseAddrs {
    local($_) = shift;
    1 while s/\([^\(\)]*\)//g; 		# strip comments
    1 while s/"[^"]*"//g;		# strip comments
    1 while s/.*<(.*)>.*/\1/;
    s/^\s+//;
    s/\s+$//;
    $_;
}

