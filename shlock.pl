# PERL implementation of Erik E. Fair's 'shlock' (from the NNTP distribution)
# Ported by Brent Chapman <Brent@GreatCircle.COM>

# Taken from shlock.pl and majordomo.pl in Majordomo distribution
# Merged into package by Bill Houle <Bill.Houle@SanDiegoCA.NCR.COM>

package shlock;
require 'majordomo.pl'; # For bitch() and abort()

# These can be predefined elsewhere, e.g. majordomo.cf
$waittime     = 600 unless $waittime;
$shlock_debug = 0   unless $shlock_debug;
$warncount    = 20  unless $warncount;

sub alert {
    &main'bitch(@_);
    &main'abort("shlock: too many warnings") unless --$warncount;
}

$EPERM = 1;
$ESRCH = 3;
$EEXIST = 17;

# Lock a process via lockfile.
#
sub main'shlock {
    local($file) = shift;
    local($tmp);
    local($retcode) = 0;

    print STDERR "trying lock '$file' for pid $$\n" if $shlock_debug;
    return(undef) unless ($tmp = &extant_file($file));

    { # redo-controlled loop
	unless (link($tmp, $file)) {
	    if ($! == $EEXIST) {
		print STDERR "lock '$file' already exists\n" if $shlock_debug;
		if (&check_lock($file)) {
		    print STDERR "extant lock is valid\n" if $shlock_debug;
		} else {
		    print STDERR "lock is invalid; removing\n" if $shlock_debug;
	            unlink($file); # no message because it might be gone by now
		    redo;
		}
	    } else {
		&alert("shlock: link('$tmp', '$file'): $!");
	    }
	} else {
	    print STDERR "got lock '$file'\n" if $shlock_debug;
	    $retcode = 1;
	}
    }

    unlink($tmp) || &alert("shlock: unlink('$file'): $!");
    return($retcode);
}

# Create a lock file (with retry).
#
sub main'set_lock {
    local($lockfile) = @_;
    local($slept) = 0;

    while ($slept < $waittime) {
	return 1 if &main'shlock("$lockfile");

	# didn't get the lock; wait 1-10 seconds and try again.
	$slept += sleep(int(rand(9) + 1));
    }
    # if we got this far, we ran out of tries on the lock.
    return undef;
}

sub main'free_lock {
    unlink $_[0];
}

# open a file locked for exclusive access; we remember the name of the lock
# file, so that we can delete it when we close the file
#
sub main'lopen {
    local($FH) = shift;
    local($mode) = shift;
    local($file) = shift;
    # $fm is what will actually get passed to open()
    local($fm) = "$mode$file";
    local($status);

    # create name for lock file
    local($lockfile) = $file;
    $lockfile =~ s,([^/]*)$,L.$1,;

    # force unqualified filehandles into callers' package
    local($package) = caller;
    $FH =~ s/^[^':]+$/$package'$&/; 

    return undef unless &main'set_lock("$lockfile");

    # Got the lock; now try to open the file
    if ($status = open($FH, $fm)) {
	# File successfully opened; remember the lock file for deletion
	$lock_files[fileno($FH)] = "$lockfile";
    } else {
	# File wasn't successfully opened; delete the lock
	       &main'free_lock($lockfile);
     }
    # return the success or failure of the open
    return $status;
}

# reopen a file already opened and locked (probably to change read/write mode).
# We remember the name of the lock file, so that we can delete it when
# we close the file
#
sub main'lreopen {
    local($FH) = shift;
    local($mode) = shift;
    local($file) = shift;
    # $fm is what will actually get passed to open()
    local($fm) = "$mode$file";

    # create name for lock file
    local($lockfile) = $file;
    $lockfile =~ s,([^/]*)$,L.$1,;

    # force unqualified filehandles into callers' package
    local($package) = caller;
    $FH =~ s/^[^':]+$/$package'$&/;

    # close the old file handle, and delete the lock reference
    if ($lock_files[fileno($FH)]) {
	undef($lock_files[fileno($FH)]);
	close($FH);
    } else {
	# the file wasn't already locked
	# unlink("$lockfile");		### Do we really want to do this?
	return(undef);
    }

    # We've already got the lock; now try to open the file
    $status = open($FH, $fm);
    if (defined($status)) {
	# File successfully opened; remember the lock file for deletion
	$lock_files[fileno($FH)] = "$lockfile";
    } else {
	# File wasn't successfully opened; delete the lock
	unlink("$lockfile");
    }
    # return the success or failure of the open
    return($status);
}


# Close a locked file, deleting the corresponding .lock file.
#
sub main'lclose {
    local($FH) = shift;

    # force unqualified filehandles into callers' package
    local($package) = caller;
    $FH =~ s/^[^':]+$/$package'$&/;

    local($lock) = $lock_files[fileno($FH)];
    close($FH);
    unlink($lock);
}

# Open a temp file. Ensure it is temporary by checking for other links, etc.
#
sub main'open_temp {
    local($FH_name, $filename) = @_;
    local($inode1, $inode2, $dev1, $dev2) = ();

    # force unqualified filehandles into callers' package
    local($package) = caller;
    $FH_name =~ s/^[^':]+$/$package'$&/;

    if ( -e $filename ) {
	&alert("Failed to open temp file '$filename', it exists");
	return(undef);
    }

    unless (open($FH_name, ">> $filename")) {
	local($tempdir) = ($filename =~ m|(.*)/|) ? $1 : ".";
	if (! -e $tempdir) {
	    &main'abort("shlock: '$tempdir' does not exist");
	}
	elsif (! -d _) {
	    &main'abort("shlock: '$tempdir' is not a directory\n");
	}
	elsif (! -w _) {
	    &main'abort("shlock: '$tempdir' is not writable by UID $> GID",
		(split(" ", $) ))[0], "\n");
	}
	else {
	    &alert("open of temp file '$filename' failed: $!");
	}
	return(undef);
    }

    if ( -l $filename ) {
	&alert("Temp file '$filename' is a symbolic link after opening");
	return(undef);
    }

    if ( (stat(_))[3] != 1 ) {
	&alert("'$filename' has more than one link after opening");
	return(undef);
    }

    ($dev1, $inode1) = (lstat(_))[0..1];
    local(*FH) = $FH_name;
    ($dev2, $inode2) = (stat(FH))[0..1];

    if ($inode1 != $inode2) {
	&alert("Inode for filename does not match filehandle! Inode1=$inode1 Inode2=$inode2");
	return(undef);
    }

    if ($dev1 != $dev2) {
	&alert("Device for filename does not match filehandle! Dev1=$dev1 Dev2=$dev2");
	return(undef);
    }

    if ( (stat(_))[3] != 1 ) {
	&alert("filehandle has more than one link after opening");
	return(undef);
    }
    return(1);
}

sub is_process {
    local($pid) = shift;

    print STDERR "process $pid is " if $shlock_debug;
    if ($pid <= 0) {
	print STDERR "invalid\n" if $shlock_debug;
	return(0);
    }
    if (kill(0, $pid) <= 0) {
	if ($! == $ESRCH)
	    { print STDERR "dead\n" if $shlock_debug; return 0; }
	elsif ($! == $EPERM)
	    { print STDERR "alive\n" if $shlock_debug; return 1; }
	else
	    { print STDERR "state unknown: $!\n" if $shlock_debug; return 1; }
    }
    print "alive\n" if $shlock_debug;
    return 1;
}

sub check_lock {
    local($file) = shift;
    local(*FILE, $pid, $buf);

    print STDERR "checking extant lock '$file'\n" if $shlock_debug;
    unless (open(FILE, "$file")) {
	&alert("shlock: open('$file'): $!") if $shlock_debug;
	return 1;
    }

    $pid = int($buf = <FILE>);

    if ($pid <= 0) {
	close(FILE);
	print STDERR "lock file format error\n" if $shlock_debug;
	return 0;
    }
    close(FILE);
    return(&is_process($pid));
}

sub extant_file {
    local($file) = shift;
    local(*FILE);
    local($tempname);

    $tempname = $file;
    if ($tempname =~ /\//) {
	$tempname =~ s,/[^\/]*$,/,;
	$tempname .= "shlock.$$";
    } else {
	$tempname = "shlock.$$";
    }
    print STDERR "temporary filename '$tempname'\n" if $shlock_debug;

    { # redo-controlled loop
	if ( -e $tempname ) {
	    print STDERR "file '$tempname' exists\n" if $shlock_debug;
	    unlink($tempname); # no message because it might be gone by now.
	    redo;
	}
	elsif (! &main'open_temp(FILE, $tempname)) {
	    print STDERR "can't create temporary file '$tempname': $!"
		if $shlock_debug;
	    return(undef);
	}
    }

    unless (print FILE "$$\n") {
	&alert("shlock failed: write('$tempname', '$$'): $!");
	close(FILE);
	unlink($tempname) || &alert("shlock: unlink('$tempname'): $!");
	return(undef);
    }
    close(FILE);

    sleep(15) if $shlock_debug; # give me a chance to look at the lock file
    return($tempname);
}

1;
