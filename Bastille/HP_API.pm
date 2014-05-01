# Copyright 2001-2003 Hewlett-Packard Company, L.P.
# This file contains all of the HP-unique subroutines
# Licensed under the GNU General Public License, version 2

# $Id: HP_API.pm,v 1.135 2010/02/06 21:58:42 jay Exp $

####################################################################
#
#  This module makes up the HP-UX specific API routines.
#
####################################################################
#
#  Subroutine Listing:
#     &HP_ConfigureForDistro: adds all used file names to global
#                             hashes and generates a global IPD
#                             hash for SD modification lookup.
#
#     &getGlobalSwlist($):    Takes a fully qualified file name
#                             and returns product:filset info
#                             for that file.  returns undef if
#                             the file is not present in the IPD
#
#     &B_check_system:        Runs a series of system queries to
#                             determine if Bastille can be safely
#                             ran on the current system.
#
#     &B_swmodify($):         Takes a file name and runs the
#                             swmodify command on it so that the
#                             IPD is updated after changes
#
#     &B_System($$):          Takes a system command and the system
#                             command that should be used to revert
#                             whatever was done. Returns 1 on
#                             success and 0 on failure
#
#     &B_Backtick($)          Takes a command to run and returns its stdout
#                             to be used in place of the prior prevelent use
#                             of un-error-handled backticks
#
#     &B_load_ipf_rules($):   Loads a set of ipfrules into ipf, storing
#                             current rules for later reversion.
#
#     &B_Schedule($$):        Takes a pattern and a crontab line.
#                             Adds or replaces the crontab line to
#                             the crontab file, depending on if a
#                             line matches the pattern
#
#     &B_ch_rc($$):           Takes a the rc.config.d flag name and
#                             new value as well as the init script
#                             location. This will stop a services
#                             and set the service so that it will
#                             not be restarted.
#
#     &B_set_value($$$):      Takes a param, value, and a filename
#                             and sets the given value in the file.
#                             Uses ch_rc, but could be rewritten using
#                             Bastille API calls to make it work on Linux
#
#     &B_TODO($):             Appends the give string to the TODO.txt
#                             file.
#
#     &B_chperm($$$$):        Takes new perm owner and group of given
#                             file.  TO BE DEPRECATED!!!
#
#     &B_install_jail($$):    Takes the jail name and the jail config
#                             script location for a give jail...
#                             These scripts can be found in the main
#                             directory e.g. jail.bind.hpux
#
#####################################################################

##############################################################################
#
#                     HP-UX Bastille directory structure
#
##############################################################################
#
#  /opt/sec_mgmt/bastille/bin/   -- location of Bastille binaries
#  /opt/sec_mgmt/bastille/lib/   -- location of Bastille modules
#  /opt/sec_mgmt/bastille/doc/   -- location of Bastille doc files
#
#  /etc/opt/sec_mgmt/bastille/   -- location of Bastille config files
#
#  /var/opt/sec_mgmt/bastille/log         -- location of Bastille log files
#  /var/opt/sec_mgmt/bastille/revert        -- directory holding all Bastille-
#                                            created revert scripts
#  /var/opt/sec_mgmt/bastille/revert/backup -- directory holding the original
#                                            files that Bastille modifies,
#                                            with permissions intact
#
##############################################################################

sub getIPFLocation () { # Temporary until we get defined search space support
    my $ipf=&getGlobal('BIN','ipf_new');
    my $ipfstat=&getGlobal('BIN','ipfstat_new');
    if (not(-e $ipf)) { # Detect if the binaries moved
        $ipf = &getGlobal('BIN','ipf');
        $ipfstat=&getGlobal('BIN','ipfstat');
    }
    return ($ipf, $ipfstat);
}

####################################################################
# &getGlobalSwlist ($file);
#   This function returns the product and fileset information for
#   a given file or directory if it exists in the IPD otherwise
#   it returns undefined "undef"
#
#   uses $GLOBAL_SWLIST{"$FILE"}
####################################################################
sub getGlobalSwlist($){

    my $file = $_[0];


    if(! defined %GLOBAL_SWLIST) {
	# Generating swlist database for swmodify changes that will be required
	# The database will be a hash of fully qualified file names that reference
	# the files product name and fileset.  These values are required to use
	# swmodify...
	# temp variable to keep swlist command /usr/sbin/swlist
	my $swlist = &getGlobal('BIN',"swlist");
	# listing of each directory and file that was installed by SD on the target machine
	my @fileList = `$swlist -l file`;
	# listing of each patch and the patches that supersede each.
	# hash which is indexed by patch.fileset on the system
	my %patchSuperseded;

	my @patchList = `${swlist} -l fileset -a superseded_by *.*,c=patch 2>&1`;
	# check to see if any patches are present on the system
	if(($? >> 8) == 0) {

	    # determining patch suppression for swmodify.
	    foreach my $patchState (@patchList) {
		# removing empty lines and commented lines.
		if($patchState !~ /^\s*\#/ && $patchState !~ /^\s*$/) {

		    # removing leading white space
		    $patchState =~ s/^\s+//;
		    my @patches = split /\s+/, $patchState;
		    if($#patches == 0){
			# patch is not superseded
			$patchSuperseded{$patches[0]} = 0;
		    }
		    else {
			# patch is superseded
			$patchSuperseded{$patches[0]} = 1;
		    }
		}
	    }
	}
	else {
	    &B_log("DEBUG","No patches found on the system.\n");
	}

	if($#fileList >= 0){
	    # foreach line of swlist output
	    foreach my $fileEntry ( @fileList ){
		#filter out commented portions
		if( $fileEntry !~ /^\s*\#/ ){
		    chomp $fileEntry;
		    # split the output into two fields filename and product.fileset
		    my ($productInfo,$file) = split /: /, $fileEntry;
		    $productInfo =~ s/\s+//;
		    $file =~ s/\s+//;
		    # if the product is a patch
		    if($productInfo =~ /PH(CO|KL|NE|SS)/){
			# if the patch is not superseded by another patch
			if($patchSuperseded{$productInfo} == 0){
			    # add the patch to the list of owner for this file
			    push @{$GLOBAL_SWLIST{"$file"}}, $productInfo;
			}
		    }
		    # not a patch.
		    else {
			# add the product to the list of owners for this file
			push @{$GLOBAL_SWLIST{"$file"}}, $productInfo;
		    }

		}
	    }
	}
	else{
	    # defining GLOBAL_SWLIST in error state.
	    $GLOBAL_SWLIST{"ERROR"} = "ERROR";
	    &B_log("ERROR","Could not execute swlist.  Swmodifys will not be attempted");
	}
    }

    if(exists $GLOBAL_SWLIST{"$file"}){
	return $GLOBAL_SWLIST{"$file"};
    }
    else {
	return undef;
    }
}

###################################################################
#  &B_check_system;
#    This subroutine is called to validate that bastille may be
#    safely run on the current system.  It will check to insure
#    that there is enough file system space, mounts are rw, nfs
#    mounts are not mounted noroot, and swinstall, swremove and
#    swmodify are not running
#
#    uses ErrorLog
#
##################################################################
sub B_check_system {
    # exitFlag is one if a conflict with the successful execution
    # of bastille is found.
    my $exitFlag = 0;

    my $ignoreCheck = &getGlobal("BDIR","config") . "/.no_system_check";
    if( -e $ignoreCheck ) {
	return $exitFlag;
    }

    # first check for swinstall, swmodify, or swremove processes
    my $ps = &getGlobal('BIN',"ps") . " -el";
    my @processTable = `$ps`;
    foreach my $process (@processTable) {
	if($process =~ /swinstall/ ) {
	    &B_log("ERROR","Bastille cannot run while a swinstall is in progress.\n" .
		      "Complete the swinstall operation and then run Bastille.\n\n");
	    $exitFlag = 1;
	}

	if($process =~ /swremove/ ) {
	    &B_log("ERROR","Bastille cannot run while a swremove is in progress.\n" .
		      "Complete the swremove operation and then run Bastille.\n\n");
	    $exitFlag = 1;
	}

	if($process =~ /swmodify/ ) {
	    &B_log("ERROR","Bastille cannot run while a swmodify is in progress.\n" .
		      "Complete the swmodify operation and then run Bastille.\n\n");
	    $exitFlag = 1;
	}

    }

    # check for root read only mounts for /var /etc /stand /
    # Bastille is required to make changes to these file systems.
    my $mount = &getGlobal('BIN',"mount");
    my $rm = &getGlobal('BIN',"rm");
    my $touch = &getGlobal('BIN',"touch");

    my @mnttab = `$mount`;

    if(($? >> 8) != 0) {
	&B_log("WARNING","Unable to use $mount to determine if needed partitions\n" .
		  "are root writable, based on disk mount options.\n" .
		  "Bastille will continue but note that disk\n" .
		  "mount checks were skipped.\n\n");
    }
    else {
	foreach my $record (@mnttab) {
	    my @fields = split /\s+/, $record;
	    if ((defined $fields[0]) && (defined $fields[2]) && (defined $fields[3])) {
		my $mountPoint = $fields[0];
		my $mountType =  $fields[2];
		my $mountOptions = $fields[3];
		if($mountPoint =~ /^\/$|^\/etc|^\/stand|^\/var/) {

		    if($mountOptions =~ /^ro,|,ro,|,ro$/) {
			&B_log("ERROR","$mountPoint is mounted read-only.  Bastille needs to make\n" .
				  "modifications to this file system.  Please remount\n" .
				  "$mountPoint read-write and then run Bastille again.\n\n");
			$exitFlag = 1;
		    }
		    # looking for an nfs mounted file system
		    if($mountType =~/.+:\//){
			my $fileExists=0;
			if(-e "$mountPoint/.bastille") {
			    $fileExisted=1;
			}

			`$touch $mountPoint/.bastille 1>/dev/null 2>&1`;

			if( (! -e "$mountPoint/.bastille") || (($? >> 8) != 0) ) {
			    &B_log("ERROR","$mountPoint is an nfs mounted file system that does\n" .
				   "not allow root to write to.  Bastille needs to make\n" .
				   "modifications to this file system.  Please remount\n" .
				   "$mountPoint giving root access and then run Bastille\n" .
				   "again.\n\n");

			    $exitFlag = 1;
			}
			# if the file did not exist befor the touch then remove the generated file
			if(! $fileExisted) {
			    `$rm -f $mountPoint/.bastille 1>/dev/null 2>&1`;
			}
		    }
		}
	    }
	    else {
		&B_log("WARNING","Unable to use $mount to determine if needed partitions\n" .
			  "are root writable, based on disk mount options.\n" .
			  "Bastille will continue but note that disk\n" .
			  "mount checks were skipped.\n\n");
	    }
	}

    }

    # checks for enough disk space in directories that Bastille writes to.
    my $bdf = &getGlobal('BIN',"bdf");
    #directories that Bastille writes to => required space in kilobytes.
    my %bastilleDirs = ( "/etc/opt/sec_mgmt/bastille" => "4", "/var/opt/sec_mgmt/bastille"=> "1000");
    for my $directory (sort keys %bastilleDirs) {
	my @diskUsage = `$bdf $directory`;

	if(($? >> 8) != 0) {
	    &B_log("WARNING","Unable to use $bdf to determine disk usage for\n" .
		   "$directory\n" .
		   "Bastille will continue but note that disk\n" .
		   "usage checks were skipped.\n\n");

	}
	else {
	    # removing bdf header line from usage information.
	    shift @diskUsage;
	    my $usageString= "";

	    foreach my $usageRecord (@diskUsage) {
		chomp $usageRecord;
	        $usageString .= $usageRecord;
	    }

	    $usageString =~ s/^\s+//;

	    my @fields = split /\s+/, $usageString;
	    if($#fields != 5) {
		&B_log("WARNING","Unable to use $bdf to determine disk usage for\n" .
		       "$directory\n" .
		       "Bastille will continue but note that disk\n" .
		       "usage checks were skipped.\n\n");
	    }
	    else {

		my $mountPoint = $fields[5];
		my $diskAvail = $fields[3];

		if($diskAvail <= $bastilleDirs{"$directory"}) {
		    &B_log("ERROR","$mountPoint does not contain enough available space\n" .
			      "for Bastille to run properly.  $directory needs\n" .
			      "at least $bastilleDirs{$directory} kilobytes of space.\n" .
			      "Please clear at least that amount of space from\n" .
			      "$mountPoint and run Bastille again.\n" .
			      "Current Free Space available = ${diskAvail} k\n\n");
 		    $exitFlag = 1;
		}
	    }
	}
    }

    # check to make sure that we are in at least run level 2 before we attempt to run
    my $who = &getGlobal('BIN', "who") . " -r";
    my $levelInfo = `$who`;
    if(($? >> 8) != 0 ) {
	&B_log("WARNING","Unable to use \"$who\" to determine system run.\n" .
		  "level Bastille will continue but note that the run\n" .
		  "level check was skipped.\n\n");
    }
    else {
	chomp $levelInfo;
	@runlevel = split /\s+/, $levelInfo;
	if ((! defined $runlevel[3]) or ($runlevel[3] < 2)) {
	    &B_log("WARNING","Bastille requires a run-level of 2 or more to run properly.\n" .
		      "Please move your system to a higher run level and then\n" .
		      "run 'bastille -b'.\n\n");
	    if(defined $runlevel[3]) {
		&B_log("ERROR","Current run-level is '$runlevel[3]'.\n\n");
		$exitFlag=1;
	    }
	    else {
		&B_log("WARNING","Unable to use \"$who\" to determine system run.\n" .
			  "level Bastille will continue but note that the run\n" .
			  "level check was skipped.\n\n");
	    }
	}
	else {
	    &B_log("DEBUG","System run-level is $runlevel[3]\n");
	}
    }

    if($exitFlag) {
	exit(1);
    }

}

###################################################################
#  &B_swmodify($file);
#    This subroutine is called after a file is modified.  It will
#    redefine the file in the IPD with it's new properties.  If
#    the file is not in the IPD it does nothing.
#
#    uses B_System to make the swmodifications.
##################################################################
sub B_swmodify($){
    my $file = $_[0];
    if(defined &getGlobalSwlist($file)){
	my $swmodify = &getGlobal('BIN',"swmodify");
	my @productsInfo = @{&getGlobalSwlist($file)};
	# running swmodify on files that were altered by this function but
	# were created and maintained by SD
	foreach my $productInfo (@productsInfo) {
	    &B_System("$swmodify -x files='$file' $productInfo",
		      "$swmodify -x files='$file' $productInfo");
	}
    }
}


#############################################
# Use this **only** for commands used that are
# intended to test system state and
# not make any system change.  Use this in place of the
# prior use of "backticks throughout Bastille
# Handles basic output redirection, but not for stdin
# Input: Command
# Output: Results
#############################################

sub B_Backtick($) {
    my $command=$_[0];
    my $combineOutput=0;
    my $stdoutRedir = "";
    my $stderrRedir = "";
    my $echo = &getGlobal('BIN','echo');

    if (($command =~ s/2>&1//) or
        (s/>&2//)){
        $combineOutput=1;
    }
    if ($command =~ s/>\s*([^>\s])+// ) {
        $stdoutRedir = $1;
    }
    if ($command =~ s/2>\s*([^>\s])+// ) {
        $stderrRedir = $1;
    }

    my ($ranFine, $stdout, $stderr) = &systemCall($command);
    if ($ranFine) {
        &B_log("DEBUG","Command: $command succeeded for test with output: $stdout , ".
               "and stderr: $stderr");
    } else {
        &B_log("DEBUG","Command: $command failed for test with output: $stdout , ".
               "and stderr: $stderr");
    }
    if ($combineOutput) {
        $stdout .= $stderr;
        $stderr = $stdout; #these should be the same
    }
    if ($stdoutRedir ne "") {
        system("$echo \'$stdout\' > $stdoutRedir");
    }
    if ($stderrRedir ne "") {
        system("$echo \'$stderr\' > $stderrRedir");
    }
    return $stdout;
}

####################################################################
#  &B_System($command,$revertcommand);
#    This function executes a command, then places the associated
#    revert command in revert file. It takes two parameters, the
#    command and the command that reverts that command.
#
#   uses ActionLog and ErrorLog for logging purposes.
###################################################################
sub B_System ($$) {
    my ($command,$revertcmd)=@_;

    my ($ranFine, $stdout, $stderr) = &systemCall($command);
    if ($ranFine) {
        &B_revert_log ("$revertcmd \n");
        if ($stderr ne '' ) {
                &B_log("ACTION",$command . "suceeded with STDERR: " .
                       $stderr . "\n");
        }
        return 1;
    } else {
        my $warningString = "Command Failed: " . $command . "\n" .
                            "Command Output: " . $stdout . "\n";
        if ($stderr ne '') {
            $warningString .= "Error message: " . $stderr;
        }
        &B_log("WARNING", $warningString);
        return 0;
    }
}

################################################################
# &systemCall
#Function used by exported methods B_Backtick and B_system
#to handle the mechanics of system calls.
# This function also manages error handling.
# Input: a system call
# Output: a list containing the status, sstdout and stderr
# of the the system call
#
################################################################
sub systemCall ($){
    local $command=$_[0];  # changed scoping so eval below can read it

    local $SIG{'ALRM'} = sub {  die "timeout" }; # This subroutine exits the "eval" below.  The program
    # can then move on to the next operation.  Used "local"
    # to avoid name space collision with disclaim alarm.
    local $WAIT_TIME=120; # Wait X seconds for system commands
    local $commandOutput = '';
    my $errOutput = '';
    eval{
        $errorFile = &getGlobal('BFILE','stderrfile');
        unlink($errorFile); #To make sure we don't mix output
	alarm($WAIT_TIME); # start a time-out for command to complete.  Some commands hang, and we want to
	                   # fail gracefully.  When we call "die" it exits this eval statement
	                   # with a value we use below
	$commandOutput = `$command 2> $errorFile`; # run the command and gather its output
	my $commandRetVal = ($? >> 8);  # find the commands return value
	if ($commandRetVal == 0) {
	    &B_log("ACTION","Executed Command: " . $command . "\n");
	    &B_log("ACTION","Command Output: " . $commandOutput . "\n");
	    die "success";
	} else {
	    die "failure";
	};
    };

    my $exitcode=$@;
    alarm(0);  # End of the timed operation

    my $cat = &getGlobal("BIN","cat");
    if ( -e $errorFile ) {
        $errOutput = `$cat $errorFile`;
    }

    if ($exitcode) {  # The eval command above will exit with one of the 3 values below
	if ($exitcode =~ /timeout/) {
	    &B_log("WARNING","No response received from $command after $WAIT_TIME seconds.\n" .
		   "Command Output: " . $commandOutput . "\n");
	    return (0,'','');
	} elsif ($exitcode =~ /success/) {
	    return (1,$commandOutput,$errOutput);
	} elsif ($exitcode =~ /failure/) {
	    return (0,$commandOutput,$errOutput);
	} else {
	    &B_log("FATAL","Unexpected return state from command execution: $command\n" .
		   "Command Output: " . $commandOutput . "\n");
	}
    }
}

####################################################################
#  &B_load_ipf_rules($ipfruleset);
#    This function enables an ipfruleset.  It's a little more
#    specific than most API functions, but necessary because
#    ipf doesn't return correct exit codes (syntax error results
#    in a 0 exit code)
#
#   uses ActionLog and ErrorLog to log
#   calls crontab directly (to list and to read in new jobs)
###################################################################
sub B_load_ipf_rules ($) {
   my $ipfruleset=$_[0];

   &B_log("DEBUG","# sub B_load_ipf_rules");

   # TODO: grab ipf.conf dynamically from the rc.config.d files
   my $ipfconf = &getGlobal('FILE','ipf.conf');

   # file system changes - these are straightforward, and the API
   # will take care of the revert
   &B_create_file($ipfconf);
   &B_blank_file($ipfconf, 'a$b');
   &B_append_line($ipfconf, 'a$b', $ipfruleset);

   # runtime changes

   # define binaries
   my $grep = &getGlobal('BIN', 'grep');
   my ($ipf, $ipfstat) = &getIPFLocation;
   # create backup rules
   # This will exit with a non-zero exit code because of the grep
   my @oldrules = `$ipfstat -io 2>&1 | $grep -v empty`;

   my @errors=`$ipf -I -Fa -f $ipfconf 2>&1`;

   if(($? >> 8) == 0) {

      &B_set_rc("IPF_START","1");
      &B_set_rc("IPF_CONF","$ipfconf");

      # swap the rules in
      &B_System("$ipf -s","$ipf -s");

      # now create a "here" document with the previous version of
      # the rules and put it into the revert-actions script
      &B_revert_log("$ipf -I -Fa -f - <<EOF\n@{oldrules}EOF");

      if (@errors) {
        &B_log("ERROR","ipfilter produced the following errors when\n" .
                  "        loading $ipfconf.  You probably had an invalid\n" .
                  "        rule in ". &getGlobal('FILE','customipfrules') ."\n".
                  "@errors\n");
      }

   } else {
     &B_log("ERROR","Unable to run $ipf\n");
   }

}



####################################################################
#  &B_Schedule($pattern,$cronjob);
#    This function schedules a cronjob.  If $pattern exists in the
#    crontab file, that job will be replaced.  Otherwise, the job
#    will be appended.
#
#   uses ActionLog and ErrorLog to log
#   calls crontab directly (to list and to read in new jobs)
###################################################################
sub B_Schedule ($$) {
   my ($pattern,$cronjob)=@_;
   $cronjob .= "\n";

   &B_log("DEBUG","# sub B_Schedule");
   my $crontab = &getGlobal('BIN','crontab');

   my @oldjobs = `$crontab -l 2>/dev/null`;
   my @newjobs;
   my $patternfound=0;

   foreach my $oldjob (@oldjobs) {
       if (($oldjob =~ m/$pattern/ ) and (not($patternfound))) {
	   push @newjobs, $cronjob;
	   $patternfound=1;
	   &B_log("ACTION","changing existing cron job which matches $pattern with\n" .
		  "$cronjob");
       } elsif ($oldjob !~ m/$pattern/ ) {
       	&B_log("ACTION","keeping existing cron job $oldjob");
      	push @newjobs, $oldjob;
       } #implied: else if pattern matches, but we've
          #already replaced one, then toss the others.
   }

   unless ($patternfound) {
     &B_log("ACTION","adding cron job\n$cronjob\n");
     push @newjobs, $cronjob;
   }

   if(open(CRONTAB, "|$crontab - 2> /dev/null")) {
     print CRONTAB @newjobs;

     # now create a "here" document with the previous version of
     # the crontab file and put it into the revert-actions script
     &B_revert_log("$crontab <<EOF\n" . "@oldjobs" . "EOF");
     close CRONTAB;
   }

   # Now check to make sure it happened, since cron will exit happily
   # (retval 0) with no changes if there are any syntax errors
   my @editedjobs = `$crontab -l 2>/dev/null`;

   if (@editedjobs ne @newjobs) {
     &B_log("ERROR","failed to add cron job:\n$cronjob\n" .
               "         You probably had an invalid crontab file to start with.");
   }

}


#This function turns off a service.  The first parameter is the parameter that
#controls the operation of the service, the second parameter is the script that
#turns on and off the service at boot-time.
sub B_ch_rc($$) {

    my ($ch_rc_parameter, $startup_script)=@_;

    if (&GetDistro != "^HP-UX") {
       &B_log("ERROR","Tried to call ch_rc $ch_rc_parameter on a non-HP-UX\n".
                 "         system!  Internal Bastille error.");
       return undef;
    }
    my $configfile="";
    my $command = &getGlobal('BIN', 'ch_rc');
    my $orig_value = &B_get_rc($ch_rc_parameter);

    if ( $orig_value !~ "1" ) { #If param is not already 1, the "stop" script won't work
	&B_System (&getGlobal('BIN',"ch_rc") . " -a -p $ch_rc_parameter=1"," ");
    }elsif ($orig_value eq "" ) { #If param is not initialized in a file, this section looks for file(s)
	                          #that mentions that parameter (like a comment), it then explicitly tells
	                          #ch_rc to use those files by setting the configfile variable
	                          #We could have just grabbed the first one, but that could lead to a false
	                          #sense of security if we got the wrong one.  Other files will ignore addition
	my $filecommand=&getGlobal('BIN','grep')." -l $ch_rc_parameter ".&getGlobal('DIR','rc.config.d')."/*";
	$configfile=`$filecommand`;
 	chomp $configfile;
	$configfile =~ s/\n/ /g; #grep returns \n's, but ch_rc expects files to be separated with spaces
    }
    &B_System ($startup_script  . " stop", #stop service, then restart if the user runs bastille -r
	       $startup_script . " start");

    # set parameter, so that service will stay off after reboots
    &B_System (&getGlobal('BIN',"ch_rc") . " -a -p $ch_rc_parameter=0 $configfile" ,
	       &getGlobal('BIN',"ch_rc") . " -a -p $ch_rc_parameter=$orig_value");
}


# This routine sets a value in a given file
sub B_set_value($$$) {
    my ($param, $value, $file)=@_;

    &B_log("DEBUG","B_set_value: $param, $value, $file");
    if (! -e $file ) {
	&B_create_file("$file");
    }

    # If a value is already set to something other than $value then reset it.
    #Note that though this tests for "$value ="the whole line gets replaced, so
    #any pre-existing values are also replaced.
    &B_replace_line($file,"^$param\\s*=\\s*","$param=$value\n");
    # If the value is not already set to something then set it.
    &B_append_line($file,"^$param\\s*=\\s*$value","$param=$value\n");

}

###############################################################
# This function adds something to the To Do List.
# Arguments:
# 1) The string you want to add to the To Do List.
# 2) Optional: Question whose TODOFlag should be set to indicate
#    A pending manual action in subsequent reports.  Only skip this
#    If there's no security-audit relevant action you need the user to
#    accomplish
# Ex:
# &B_TODO("------\nInstalling IPFilter\n----\nGo get Ipfilter","IPFilter.install_ipfilter");
#
#
# Returns:
# 0 - If error condition
# True, if sucess, specifically:
#   "appended" if the append operation was successful
#   "exists" if no change was made since the entry was already present
###############################################################
sub B_TODO ($;$) {
    my $text = $_[0];
    my $FlaggedQuestion = $_[1];
    my $multilineString = "";

    # trim off any leading and trailing new lines, regexes separated for "clarity"
    $text =~ s/^\n+(.*)/$1/;
    $text =~ s/(.*)\n+$/$1/;

    if ( ! -e &getGlobal('BFILE',"TODO") ) {
	# Make the TODO list file for HP-UX Distro
	&B_create_file(&getGlobal('BFILE', "TODO"));
	&B_append_line(&getGlobal('BFILE', "TODO"),'a$b',
          "Please take the steps below to make your system more secure,\n".
          "then delete the item from this file and record what you did along\n".
          "with the date and time in your system administration log.  You\n".
          "will need that information in case you ever need to revert your\n".
          "changes.\n\n");
    }


    if (open(TODO,"<" . &getGlobal('BFILE', "TODO"))) {
	while (my $line = <TODO>) {
	    # getting rid of all meta characters.
	    $line =~ s/(\\|\||\(|\)|\[|\]|\{|\}|\^|\$|\*|\+|\?|\.)//g;
	    $multilineString .= $line;
	}
	chomp $multilineString;
        $multilineString .= "\n";

	close(TODO);
    }
    else {
	&B_log("ERROR","Unable to read TODO.txt file.\n" .
		  "The following text could not be appended to the TODO list:\n" .
		  $text .
		  "End of TODO text\n");
        return 0; #False
    }

    my $textPattern = $text;

    # getting rid of all meta characters.
    $textPattern =~ s/(\\|\||\(|\)|\[|\]|\{|\}|\^|\$|\*|\+|\?|\.)//g;

    if( $multilineString !~  "$textPattern") {
	my $datestamp = "{" . localtime() . "}";
	unless ( &B_append_line(&getGlobal('BFILE', "TODO"), "", $datestamp . "\n" . $text . "\n\n\n") ) {
	    &B_log("ERROR","TODO Failed for text: " . $text );
	}
        #Note that we only set the flag on the *initial* entry in the TODO File
        #Not on subsequent detection.  This is to avoid the case where Bastille
        #complains on a subsequent Bastille run of an already-performed manual
        #action that the user neglected to delete from the TODO file.
        # It does, however lead to a report of "nonsecure" when the user
        #asked for the TODO item, performed it, Bastille detected that and cleared the
        # Item, and then the user unperformed the action.  I think this is proper behavior.
        # rwf 06/06

        if (defined($FlaggedQuestion)) {
            &B_TODOFlags("set",$FlaggedQuestion);
        }
        return "appended"; #evals to true, and also notes what happened
    } else {
        return "exists"; #evals to true, and also
    }

}

##################################################################################
# &B_chperm($owner,$group,$mode,$filename(s))
#   This function changes ownership and mode of a list of files. Takes four
#   arguments first the owner next the group and third the new mode in oct and
#   last a list of files that the permissions changes should take affect on.
#
#   uses: &swmodify and &B_revert_log
##################################################################################
sub B_chperm($$$$) {
    my ($newown, $newgrp, $newmode, $file_expr) = @_;
    my @files = glob($file_expr);

    my $return = 1;

    foreach my $file (@files){
	my @filestat = stat $file;
	my $oldmode = (($filestat[2]/512) % 8) .
	    (($filestat[2]/64) % 8) .
		(($filestat[2]/8) % 8) .
		    (($filestat[2]) % 8);

	if((chown $newown, $newgrp, $file) != 1 ){
	    &B_log("ERROR","Could not change ownership of $file to $newown:$newgrp\n");
	    $return = 0;
	}
	else{
	    &B_log("ACTION","Changed ownership of $file to $newown:$newgrp\n");
	    # swmodifying file if possible...
	    &B_swmodify($file);
	    &B_revert_log(&getGlobal('BIN',"chown") . " $filestat[4]:$filestat[5] $file\n");
	}

        $newmode_formatted=sprintf "%5lo",$newmode;

	if((chmod $newmode, $file) != 1){
	    &B_log("ERROR","Could not change mode of $file to $newmode_formatted\n");
	    $return = 0;
	}
	else{
	    &B_log("ACTION","Changed mode of $file to $newmode_formatted\n");
	    &B_revert_log(&getGlobal('BIN',"chmod") . " $oldmode $file\n");
	}


    }
    return $return;
}

############################################################################
# &B_install_jail($jailname, $jailconfigfile);
# This function takes two arguments ( jail_name, jail_config )
# It's purpose is to take read in config files that define a
# chroot jail and then generate it bases on that specification
############################################################################
sub B_install_jail($$) {

    my $jailName = $_[0];  # Name of the jail e.g bind
    my $jailConfig = $_[1]; # Name of the jails configuration file
    # create the root directory of the jail if it does not exist
    &B_create_dir( &getGlobal('BDIR','jail'));
    &B_chperm(0,0,0555,&getGlobal('BDIR','jail'));

    # create the Jail dir if it does not exist
    &B_create_dir( &getGlobal('BDIR','jail') . "/" . $jailName);
    &B_chperm(0,0,0555,&getGlobal('BDIR','jail') . "/". $jailName);


    my $jailPath = &getGlobal('BDIR','jail') . "/" . $jailName;
    my @lines; # used to store no commented no empty config file lines
    # open configuration file for desired jail and parse in commands
    if(open(JAILCONFIG,"< $jailConfig")) {
	while(my $line=<JAILCONFIG>){
	    if($line !~ /^\s*\#|^\s*$/){
		chomp $line;
		push(@lines,$line);
	    }
	}
        close JAILCONFIG;
    }
    else{
	&B_log("ERROR","Open Failed on filename: $jailConfig\n");
	return 0;
    }
    # read through commands and execute
    foreach my $line (@lines){
        &B_log("ACTION","Install jail: $line\n");
	my @confCmd = split /\s+/,$line;
	if($confCmd[0] =~ /dir/){ # if the command say to add a directory
	    if($#confCmd == 4) { # checking dir Cmd form
		if(! (-d  $jailPath . "/" . $confCmd[1])){
		    #add a directory and change its permissions according
                    #to the conf file
		    &B_create_dir( $jailPath . "/" . $confCmd[1]);
                    &B_chperm((getpwnam($confCmd[3]))[2],
                              (getgrnam($confCmd[4]))[2],
                               oct($confCmd[2]),
                               $jailPath . "/" . $confCmd[1]);
		}
	    }
	    else {
		&B_log("ERROR","Badly Formed Configuration Line:\n$line\n\n");
	    }
	}
	elsif($confCmd[0] =~ /file/) {
	    if($#confCmd == 5) { # checking file cmd form
		if(&B_cp($confCmd[1],$jailPath . "/" . $confCmd[2])){
		    # for copy command cp file and change perms
		    &B_chperm($confCmd[4],$confCmd[5],oct($confCmd[3]),$jailPath . "/" . $confCmd[2]);
		}
		else {
		    &B_log("ERROR","Could not complete copy on specified files:\n" .
			   "$line\n");
		}
	    }
	    else {
		&B_log("ERROR","Badly Formed Configuration Line:\n" .
		       "$line\n\n");
	    }
	}
	elsif($confCmd[0] =~ /slink/) {
	    if($#confCmd == 2) { # checking file cmd form
		if(!(-e $jailPath . "/" . $confCmd[2])){
		    #for symlink command create the symlink
		    &B_symlink($jailPath . "/" . $confCmd[1], $confCmd[2]);
		}
	    }
	    else {
		&B_log("ERROR","Badly Formed Configuration Line:\n" .
		       "$line\n\n");
	    }
	}
	else {
	    &B_log("ERROR","Unrecognized Configuration Line:\n" .
		   "$line\n\n");
	}
    }
    return 1;
}



###########################################################################
#  &B_list_processes($service)                                            #
#                                                                         #
#  This subroutine uses the GLOBAL_PROCESS hash to determine if a         #
#  service's corresponding processes are running on the system.           #
#  If any of the processes are found to be running then the process       #
#  name(s) is/are returned by this subroutine in the form of an list      #
#  If none of the processes that correspond to the service are running    #
#  then an empty list is returned.                                        #
###########################################################################
sub B_list_processes($) {

    # service name
    my $service = $_[0];
    # list of processes related to the service
    my @processes=@{ &getGlobal('PROCESS',$service)};

    # current systems process information
    my $ps = &getGlobal('BIN',"ps");
    my $psTable = `$ps -elf`;

    # the list to be returned from the function
    my @running_processes;

    # for every process associated with the service
    foreach my $process (@processes) {
	# if the process is in the process table then
	if($psTable =~ m/$process/) {
	    # add the process to the list, which will be returned
	    push @running_processes, $process;
	}

    }

    # return the list of running processes
    return @running_processes;

}

#############################################################################
#  &B_list_full_processes($service)                                         #
#                                                                           #
#  This subroutine simply grep through the process table for those matching #
#  the input argument  TODO: Allow B_list process to levereage this code    #
#  ... Not done this cycle to avoid release risk (late in cycle)            #
#############################################################################
sub B_list_full_processes($) {

    # service name
    my $procName = $_[0];
    my $ps = &getGlobal('BIN',"ps");
    my @psTable = split(/\n/,`$ps -elf`);

    # for every process associated with the service
    my @runningProcessLines = grep(/$procName/ , @psTable);
    # return the list of running processes
    return @runningProcessLines;
}

################################################################################
#  &B_deactivate_inetd_service($service);                                      #
#                                                                              #
#  This subroutine will disable all inetd services associated with the input   #
#  service name.  Service name must be a reference to the following hashes     #
#  GLOBAL_SERVICE GLOBAL_SERVTYPE and GLOBAL_PROCESSES.  If processes are left #
#  running it will note these services in the TODO list as well as instruct the#
#  user in how they remaining processes can be disabled.                       #
################################################################################
sub B_deactivate_inetd_service($) {
    my $service = $_[0];
    my $servtype = &getGlobal('SERVTYPE',"$service");
    my $inetd_conf = &getGlobal('FILE',"inetd.conf");

    # check the service type to ensure that it can be configured by this subroutine.
    if($servtype ne 'inet') {
	&B_log("ACTION","The service \"$service\" is not an inet service so it cannot be\n" .
		   "configured by this subroutine\n");
	return 0;
    }

    # check for the inetd configuration files existence so it may be configured by
    # this subroutine.
    if(! -e $inetd_conf ) {
	&B_log("ACTION","The file \"$inetd_conf\" cannot be located.\n" .
		   "Unable to configure inetd\n");
	return 0;
    }

    # list of service identifiers present in inetd.conf file.
    my @inetd_entries = @{ &getGlobal('SERVICE',"$service") };

    foreach my $inetd_entry (@inetd_entries) {
	&B_hash_comment_line($inetd_conf, "^\\s*$inetd_entry");
    }

    # list of processes associated with this service which are still running
    # on the system
    my @running_processes = &B_list_processes($service);

    if($#running_processes >= 0) {
        my $todoString = "\n" .
	                 "---------------------------------------\n" .
	                 "Deactivating Inetd Service: $service\n" .
			 "---------------------------------------\n" .
			 "The following process(es) are associated with the inetd service \"$service\".\n" .
			 "They are most likely associated with a session which was initiated prior to\n" .
			 "running Bastille.  To disable a process see \"kill(1)\" man pages or reboot\n" .
			 "the system\n" .
			 "Active Processes:\n" .
			 "###################################\n";
	foreach my $running_process (@running_processes) {
	    $todoString .= "\t$running_process\n";
	}
	$todoString .= 	 "###################################\n";

	&B_TODO($todoString);
    }

}


################################################################################
# B_get_rc($key);                                                              #
#                                                                              #
#  This subroutine will use the ch_rc binary to get rc.config.d variables      #
#  values properly escaped and quoted.                                         #
################################################################################
sub B_get_rc($) {
    my $key=$_[0];
    my $ch_rc = &getGlobal('BIN',"ch_rc");

    # get the current value of the given parameter.
    my $currentValue=`$ch_rc -l -p $key`;
    chomp $currentValue;

    if(($? >> 8) == 0 ) {
	# escape all meta characters.
	$currentValue =~ s/([\"\`\$\\])/\\$1/g;
	$currentValue = '"' . $currentValue . '"';

    }
    else {
	return undef;
    }

    return $currentValue;
}



################################################################################
# B_set_rc($key,$value);                                                       #
#                                                                              #
#  This subroutine will use the ch_rc binary to set rc.config.d variables.  As #
#  well as setting the variable this subroutine will set revert strings.       #
#                                                                              #
################################################################################
sub B_set_rc($$) {

    my ($key,$value)=@_;
    my $ch_rc = &getGlobal('BIN',"ch_rc");

    # get the current value of the given parameter.
    my $currentValue=&B_get_rc($key);

    if(defined $currentValue ) {

	if ( &B_System("$ch_rc -a -p $key=$value",
		       "$ch_rc -a -p $key=$currentValue") ) {
	    #ch_rc success
	    return 1;
	}
	else {
	    #ch_rc failure.
	    return 0;
	}
    }
    else {
	&B_log("ERROR","ch_rc was unable to lookup $key\n");
	return 0;
    }

}


################################################################################
#  &ChrootHPApache($chrootScript,$httpd_conf,$httpd_bin,
#                  $apachectl,$apacheJailDir,$serverString);
#
#     This subroutine given an chroot script, supplied by the vendor, a
#     httpd.conf file, the binary location of httpd, the control script,
#     the jail directory, and the servers identification string, descriptive
#     string for TODO etc.  It makes modifications to httpd.conf so that when
#     Apache starts it will chroot itself into the jail that the above
#     mentions script creates.
#
#     uses B_replace_line B_create_dir B_System B_TODO
#
###############################################################################
sub B_chrootHPapache($$$$$$) {

    my ($chrootScript,$httpd_conf,$httpd_bin,$apachectl,$apacheJailDir,$serverString)= @_;

    my $exportpath = "export PATH=/usr/bin;";
    my $ps = &getGlobal('BIN',"ps");
    my $isRunning = 0;
    my $todo_header = 0;

    # checking for a 2.0 version of the apache chroot script.
    if(-e $chrootScript ) {

	if(open HTTPD, $httpd_conf) {
	    while (my $line = <HTTPD>){
		if($line =~ /^\s*Chroot/) {
		    &B_log("DEBUG","Apache is already running in a chroot as specified by the following line:\n$line\n" .
			   "which appears in the httpd.conf file.  No Apache Chroot action was taken.\n");
		    return;
		}
	    }
	    close(HTTPD);
	}

	if(`$ps -ef` =~ $httpd_bin ) {
	    $isRunning=1;
	    &B_System("$exportpath " . $apachectl . " stop","$exportpath " . $apachectl . " start");
	}
	&B_replace_line($httpd_conf, '^\s*#\s*Chroot' ,
			"Chroot " . $apacheJailDir);
	if(-d &getGlobal('BDIR',"jail")){
	    &B_log("DEBUG","Jail directory already exists. No action taken.\n");
	}
	else{
	    &B_log("ACTION","Jail directory was created.\n");
	    &B_create_dir( &getGlobal('BDIR','jail'));
	}

	if(-d $apacheJailDir){
	    &B_log("DEBUG","$serverString jail already exists. No action taken.\n");
	}
	else{
	    &B_System(&getGlobal('BIN',"umask") . " 022; $exportpath " . $chrootScript,
		      &getGlobal('BIN',"echo") . " \"Your $serverString is now running outside of it's\\n" .
		      "chroot jail.  You must manually migrate your web applications\\n" .
		      "back to your Apache server's httpd.conf defined location(s).\\n".
		      "After you have completed this, feel free to remove the jail directories\\n" .
		      "from your machine.  Your apache jail directory is located in\\n" .
		      &getGlobal('BDIR',"jail") . "\\n\" >> " . &getGlobal('BFILE',"TOREVERT"));

	}
	if($isRunning){
	    &B_System("$exportpath " . $apachectl . " start","$exportpath " . $apachectl . " stop");
	    &B_log("ACTION","$serverString is now running in an chroot jail.\n");
	}

	&B_log("ACTION","The jail is located in " . $apacheJailDir . "\n");

	if ($todo_header !=1){
	    &B_TODO("\n---------------------------------\nApache Chroot:\n" .
		    "---------------------------------\n");
	}
	&B_TODO("$serverString Chroot Jail:\n" .
		"httpd.conf contains the Apache dependencies.  You should\n" .
		"review this file to ensure that the dependencies made it\n" .
		"into the jail.  Otherwise, you run a risk of your Apache server\n" .
		"not having access to all its modules and functionality.\n");


    }

}



1;
