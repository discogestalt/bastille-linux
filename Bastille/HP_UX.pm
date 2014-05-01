# Copyright 2001,2002, 2008 Hewlett-Packard Development Company, L.P.
# Licensed under the GNU General Public License, version 2
# $Id: HP_UX.pm,v 1.78 2009/09/10 05:50:58 michael_louie Exp $

package Bastille::HP_UX;

use Bastille::API;
use Bastille::API::HPSpecific;
use Bastille::API::FileContent;
use Bastille::API::AccountPermission;



@ENV="";
$ENV{PATH}="";
$ENV{CDPATH}=".";
$ENV{BASH_ENV}="";

#######################################################################
##                   HP-UX specific hardening steps                  ##
#######################################################################

&StackNoExecute;
&RestrictSwacls;
&Ndd;
&NddTcpIsn;
&Netstat;
&ScreensaverTimeout;
&WarningBannerForGUI;
&OtherTools;
&MailConfig;


######################################################################
#  StackNoExecute:  This subroutine uses kmtune and mk_kernel
#                   in order to un-set the executable stack kernel
#                   parameter and then recompile the kernel with
#                   the parameter value.
######################################################################

sub StackNoExecute {

  if (&getGlobalConfig("HP_UX","stack_execute") eq "Y") {
       &B_log("ACTION","# sub Stack Execute \n");
       # get binaries to be used...
       my $chmod = &getGlobal('BIN',"chmod");
       my $exportpath = &getGlobal('BIN',"umask")." 077; export PATH=/usr/bin;";
       my $kmtune = &getGlobal('BIN', "kmtune");       #kmtune's path
       my $kctune = &getGlobal('BIN', "kctune");       #kctune's path
       my $mk_kernel = &getGlobal('BIN', "mk_kernel"); #mk_kernel's path

       if (-x $kctune) {
          my @current=`$kctune -q executable_stack -P current`;

          # get the second column (1) on the first line (0)
          my $curval=(split /\s+/, $current[0])[1];

          #Note -K will be deprecated post-11.31 in favor of "-b no"
          &B_System("$kctune -K executable_stack=0",
                    "$kctune -K executable_stack=$curval");
       } else {
         # get the current kernel parameter information...

         # get current pending kernel parameters
         my @kmdiff = `$exportpath $kmtune -d`;
         # get executable stack query information
         my @kmq = `$exportpath $kmtune -q executable_stack`;
         my @kmexecq = split /\s+/, $kmq[2];

         if(($kmexecq[1] ne 0) || ($kmexecq[3] ne 0)){     #executable stack protection is not set
	   if($#kmdiff == 1){ #system tunable parameters are current
	       # going ahead and seting executable_stack param to 0
	       if(&B_System("$exportpath $kmtune -s executable_stack=0","$exportpath $kmtune -s executable_stack=$kmexecq[3]\n")){
		   #changed param successfully
		   &B_log("ACTION","Planned value of executable_stack tunable parameter is set to secure.\n");

		   if(&B_System("$exportpath $mk_kernel -o /stand/vmunix",
			     "$exportpath $kmtune -s executable_stack=$kmexecq[3]; $mk_kernel -o /stand/vmunix\n")){
		       # Kernel Build Successful
		       my $kernelbuilddir=&getGlobal('DIR',"dlkm_kernel_build");
		       if ( -e $kernelbuilddir ) {
                          # Just to make sure; this change should never be reverted
		          &B_System("$chmod og-w " .$kernelbuilddir,"");
                       }
		       &B_log("ACTION","Kernel Build Successful: Reboot for changes to take affect\n");
		       &B_TODO("\n\n---------------------------------\nStack Execute Permissions:\n" .
			       "---------------------------------\n" .
			       "Please reboot your system to enable stack execution protection.\n\n",
                               "HP_UX.stack_execute");
		   }
		   else{
		       &B_log("ERROR","The kernel build failed. Could not compile kernel.\n");
		   }
	       }
	       else{
		   &B_log("ERROR","kmtune could not set tunable parameter.\n");
	       }
	   }
	   else{
	       &B_log("ERROR","Kernel tuning not performed.  Tunable parameters are in an unstable\n".
                         "         state.  (Perhaps you forgot to reboot?)  Resolve the issue shown\n".
                         "         by the command $kmtune -d\n");
	   }
         }else{
	   &B_log("ACTION","System already has kernel level stack execution protection. No changes made.\n");
         }
       }
   }
}

sub RestrictSwacls {
    if (&getGlobalConfig("HP_UX","restrict_swacls") eq "Y") {
	&B_log("ACTION","# sub Restrict SWACLS\n");


	my $swagentd = &getGlobal('BIN',"swagentd");
	my $ps = &getGlobal('BIN',"ps");

	# is swagentd running
	my $isRunning=0;
	# process table.
	my @psTable = `$ps -elf`;
	foreach my $process (@psTable) {
	    if($process =~ $swagentd) {
		$isRunning = 1;
	    }
	}

	if($isRunning) {
          &B_log("ACTION","Making swacl changes after verifying that swagent is running.");

	    # get the current permissions to store for revert later
	    my $swacl = &getGlobal('BIN','swacl');

	    # Get the current swacl's for revert.

	    # if no value is set for current permissions add any_other:-
	    # which is effectively the same as removing it all together.
	    my $hostperms="-";
	    my @host_swacl = `$swacl -l host`;
	    foreach my $definition (@host_swacl){
		# look for at least one non-'-'
		chomp $definition; #otherwise, \n matches as "non-dash"
		if($definition =~ /^any_other:(.*[^-]+.*)$/) {
		    $hostperms=$1;
		}
	    }

	    my $rootperms = "-";
	    my @root_swacl = `$swacl -l root`;
	    foreach my $definition (@root_swacl){
		chomp $definition; #otherwise, \n matches as "non-dash"
		# look for at least one non-'-'
		if($definition =~ /^any_other:(.*[^-]+.*)$/) {
		    $rootperms=$1;
		}
	    }

	    # Make the change.

	    # edit host permissions  NO one off of host
	    &B_System(&getGlobal('BIN','swacl') . " -l host -D any_other",
		      &getGlobal('BIN','swacl') . " -l host -M any_other:$hostperms");
	    # edit user permissions NO one except root
	    &B_System(&getGlobal('BIN','swacl') . " -l root -D any_other",
		      &getGlobal('BIN','swacl') . " -l root -M any_other:$rootperms");
	}
	else {
          &B_log("ACTION","Adding swacl todo to check swacl status");
	  &B_TODO("---------------------------------\n" .
		    "SD Access Control Lists:\n" .
		    "---------------------------------\n" .
		    "Bastille was unable to make changes to the SD access control lists or \n" .
                    "determine their state.  This was because the swagentd was not running.  \n".
		    "In the case of an Install-Time Security(ITS) application, the ITS scripts will \n".
                    "configure SD later in the boot, though the Bastille basline will indicate \"N\" for swacls at \n".
                    "this time.  If you would like to update the baseline, you may use the bastille_drift(1m) \n".
                    "command.  If the swacl question does not change to \"Y\", then ensure swagentd is \n" .
		    "running and then run \"bastille -b\" to allow Bastille to the make SD access \n" .
		    "control list changes. \n\n","HP_UX.restrict_swacls");
	}
    }
}
   
sub Ndd {

   # key is           NDD_NAME
   # array element[0] TRANSPORT_NAME
   # array element[1] NDD_VALUE (new)
     my %blankHash=();

   if (&getGlobalConfig("HP_UX","ndd") eq "Y") {
       &B_log("ACTION","# sub Ndd\n");
       # get all current values (-A) starting with any of the given names
       my $ch_rc = &getGlobal('BIN','ch_rc');
       my $ndd_conf = &getGlobal('FILE', 'nddconf');
       my %inFileParms = &readNddConf;
       my %inMemParms = &readNddFromMem;

      # if there are any parameters already set in nddconf(that Bastille hadn't
      # added, then we need to have some manual intervention, because any
      # merge will probably mess things up

      if ((not(&NddHashesMatch(\%inFileParms,\%newNDD))) and
         (not(&NddHashesMatch(\%inFileParms,\%priorBastilleNDD))) and
         (not(&NddHashesMatch(\%inFileParms,\%blankHash))) ) {
         
          my $nddVariables = "";
          my $nddVar;
          foreach $nddVar (keys(%newNDD)) {
               $nddVariables .= "   $nddVar  -> " . $newNDD{$nddVar}[1] . "\n";
          }
          
          my $nddconf = &getGlobal('FILE', 'nddconf') ; 
          my $ndd_text =
           "This version of Bastille cannot resolve the ndd configuration\n" .
           "changes that were selected.  The following are the parameters\n" .
           "and the suggested values.\n" .
           "\n" . $nddVariables .
           "You will need to merge your current ndd settings in \n" .
           "$nddconf with these manually.\n\n" .
           "For more information on each of these parameters, run\n" .
           "\n" .
           "ndd -h\n\n";
	&B_TODO("\n---------------------------------\nNdd Parameters:\n" .
		"---------------------------------\n" .
		$ndd_text);
        &B_TODOFlags('set','HP_UX.ndd');
     #Or else we need to wipe the prior entries, and replace with the new stuff.
      } elsif ((&NddHashesMatch(\%inFileParms,\%priorBastilleNDD)) or
               (&NddHashesMatch(\%inFileParms,\%blankHash))) {
          &B_blank_file($ndd_conf);
	   # setting bastille backend values of nddconf
	   my $index = 0;
	   # this string will allow bastille to revert the changes made to
	   # the ndd settings.
	   my $revertString ="";

	   # This for generates the configuration file for ndd and it generates
	   # the revertString which will put the system back to its initial state
	   # when bastille -r is run.
	   for my $newNDDKey (keys %newNDD){
	       # string to be added to the configuration file
	       my $paramstring =
		   " -p TRANSPORT_NAME[${index}]=" . $newNDD{$newNDDKey}[0] .
		   " -p NDD_NAME[${index}]=" . $newNDDKey .
		   " -p NDD_VALUE[${index}]=" . $newNDD{$newNDDKey}[1];

	       # string that receives the current value of the newNDDKey
	       my $ndd_call = &getGlobal('BIN','ndd');
	       my $nddGetValue = &B_Backtick("$ndd_call -get /dev/$newNDD{$newNDDKey}[0] $newNDDKey");
	       chomp $nddGetValue;
	       # string that is generated to put ndd back to its pre-Bastilled state
	       $revertString .= "$ndd_call -set /dev/" . $newNDD{$newNDDKey}[0] .
		   " " . $newNDDKey . " " . $nddGetValue . "\n";


	       &B_System (&getGlobal('BIN','ch_rc') . " -a $paramstring " .
                          $ndd_conf,
			  &getGlobal('BIN','ch_rc') . " -r $paramstring");

	       $index++;
	   }
	   # re-read config file after setting new parameters (at run time)
	   &B_System (&getGlobal('BIN',"ndd") . " -c","$revertString");

       }
   }
}

sub NddHashesMatch($$) {
     my $firstHashRef=$_[0];
     my $secondHashRef=$_[1];
     my %nddFirstHash = %$firstHashRef;
     my %nddSecondHash = %$secondHashRef;
     
     my $firstContainsAllSecond=1;
     my $secondContainsAllFirst=1;
     my %cursor ;
     
     foreach $cursor (keys(%nddFirstHash)) {
          if (($nddFirstHash{$cursor}[0] ne $nddSecondHash{$cursor}[0]) and
              ($nddFirstHash{$cursor}[1] ne $nddSecondHash{$cursor}[1])){
               $firstContainsAllSecond = 0;
               last;
          }
     }
     foreach $cursor (keys(%nddSecondHash)) {
          if (($nddSecondHash{$cursor}[0] ne $nddFirstHash{$cursor}[0]) and
              ($nddSecondHash{$cursor}[1] ne $nddFirstHash{$cursor}[1])){
               $secondContainsAllFirst = 0;
               last;
          }
     }
     
     if ($firstContainsAllSecond and $secondContainsAllFirst){
          return 1;
     } else {
          return 0;
     }
}
sub readNddFromMem {
     my %nddPerms = ();
     my $ndd_call = &getGlobal('BIN','ndd');

     foreach my $newNDDKey (keys %newNDD){
          $nddPerms{$newNDDKey}[0] =$newNDD{$newNDDKey}[0];
          $nddPerms{$newNDDKey}[1] = &B_Backtick("$ndd_call -get /dev/$newNDD{$newNDDKey}[0] $newNDDKey");
          chomp $inMemParms{$newNDDKey}[0];
          chomp $inMemParms{$newNDDKey}[1];
       }
     return %inMemParms;
}

sub readNddConf {
     
     my $index = 0;
     my $more_stuff = 1;
     my %nddConfSettings = ();
      
     while ($more_stuff) {
          my $transport = &B_get_rc("TRANSPORT_NAME[" . $index . "] "); 
          my $ndd_name =  &B_get_rc("NDD_NAME[" .       $index . "] ");
          my $ndd_value = &B_get_rc("NDD_VALUE[" .      $index . "] ");
          
          if ($transport  &&  $ndd_name &&  $ndd_value ) {
               if (exists($nddConfSettings{"$ndd_name"})) {
                    &B_log("WARNING", "nddconf contains duplicate entry for $ndd_name ".
                           ", using numerically last entry, which may not be correct." .
                           "Please correct nddconf format to ensure correct subsequent Bastille runs.");
               }
               $nddConfSettings{"$ndd_name"} = ["$transport", "$ndd_value"];
          } elsif (($transport =~ "\n") or
                   ($ndd_name  =~ "\n") or
                   ($ndd_value =~ "\n")) {
               &B_log("WARNING", "nddconf contains missing/duplicate entry for $ndd_name".
                      ". Using last entry in file, which may not be correct." .
                      "Please correct nddconf format to ensure correct subsequent Bastille runs.");
               $transport =~ s/^.*\n(.*)$/$1/; # Use last entry with Bastille warning as stated above
               $ndd_name  =~ s/^.*\n(.*)$/$1/;
               $ndd_value =~ s/^.*\n(.*)$/$1/;
          } else {
               $more_stuff = 0;
               if (($ndd_name ne "") and
                    (($transport ne "") or ($ndd_value ne "")) ) {
                    &B_log("WARNING", "nddconf entry for $ndd_value has missing ".
                           "data, not using entry")
               }
          }
          $index++;
     }
     return %nddConfSettings;
}

#
# CIS implemenation tcp_isn
#
#------------------------------------------------------
# RFC 1948 compliant TCP ISN
#------------------------------------------------------
#1) Bastille check for tcp_isn_passphrase in ndd.conf... if present, delete the line.
#2) Bastille use ndd -get to see if the passphrase is set.
#	a) If not, and Bastille is running in rc2.d/S339... then run <"ndd set script" below> to set a passphrase
#	b) If not, and Bastille is not run as in "a" then:
#		i) change permissions of ndd.conf to 600
#		ii) add a tcp_isn_passphrase line using data from /dev/urandom (cat-ted through uuencode)
#		iii) use ndd -c to read the new passphrase (and avoid command line exposure)
#		iv) delete the tcp_isn_passphrase line
#		v) restore ndd.conf file permissions
# 3) Create, or if present, blank /sbin/rc2.d/S339tcpisn and/or the file it links to (backing it up first)
# 4) Add the "ndd set script" below to the file.

sub CreateBootSriptForTcpIsn {
     
     # add a rc script for setting passphrase
     my $bootscript = &getGlobal("bin", "S339tcpisn");
     if ( -e $bootscript ) {
          &B_blank_file($bootscript, '@#$%^&*');
     }
     else {
          &B_create_file($bootscript);
     }
          
     my $script_upper =<<'SCRIPT_UPPER';
#! /sbin/sh

export PATH=/sbin:/usr/sbin:/usr/bin:/bin:${PATH}

SCRIPT_UPPER

# uuencode has no -m option in HPUX11.23, so wee need to differentiate it
          my $script_mid_1123 =<<'SCRIPT_MID_1123';
set_passphrase() {
     passphrase=$(dd if=/dev/urandom bs=1 count=24 2>/dev/null | uuencode  - | sed -n '2 p'  | sed -e 's|"|A|g' -e "s|'|B|g" -e 's|\\|C|g' -e 's|`|D|' -e 's|#|E|g')
     ndd -set /dev/tcp tcp_isn_passphrase $passphrase
}
SCRIPT_MID_1123

     my $script_mid_1131 =<<'SCRIPT_MID_1131';
set_passphrase() {
     passphrase=$(dd if=/dev/urandom bs=1 count=24 2>/dev/null | uuencode -m - | sed -n '2 p')
     ndd -set /dev/tcp tcp_isn_passphrase $passphrase
}
SCRIPT_MID_1131

          my $script_lower =<<'SCRPT_LOWER';
# Script begins
trap 'cleanup' 2 6
trap '' 1

case $1 in
start_msg)
echo "Set TCP ISN passphrase"
;;
stop_msg)
;;
start)
set_passphrase;
;;
esac
SCRPT_LOWER
          
     my $script;
     if (&GetDistro =~ "^HP-UX11.(.*)" and $1<=23 )  {
          $script = $script_upper . $script_mid_1123 . $script_lower;
     }
     else {
          $script = $script_upper . $script_mid_1131 . $script_lower;
     }
     # boot script
     if ( open(*BOOT, "> $bootscript") ) {
          print  BOOT  $script;
          close(BOOT);
     }
      my $chmod = &getGlobal("BIN", "chmod");
     &B_System("$chmod 555 $bootscript");
          
}

sub NddTcpIsn {
     if (&getGlobalConfig("HP_UX","tcp_isn") eq "Y") {
          &B_log("ACTION","# sub NddTcpIsn\n");
          my $nddconf = &getGlobal("FILE","nddconf");
          
          # if tcp_isn_passphrase is set in nddconf , delete the line.
          if (&B_match_line($nddconf, 'tcp_isn_passphrase=.*')) {
               &B_delete_line($nddconf, 'tcp_isn_passphrase=.*');
          }
          
          my $ndd = &getGlobal("BIN","ndd");
          my $passphrase = `$ndd -get  /dev/tcp tcp_isn_passphrase`;
          
          # if the passphrase is not set
### FIX 1 ###
          if ($passphrase == 0) {
               # set the passphrase in nddconf. and ndd -c to make the nddconf takes effect
               open(*URANDOM, "/dev/urandom");
               my $random_data;
               read URANDOM, $random_data, 24;
               use MIME::Base64;
               $passphrase = encode_base64($random_data);
               close URANDOM;
               
               &B_chmod(0600, $nddconf);
               
               if ( open(*NDDCONF, $nddconf) ) {
                    my $count = 0;
                    while( my $line = <NDDCONF>) {
                         if  ( $line =~ /^[^#]/ and $line =~  /TRANSPORT_NAME\[\d+\]=/ ) {
                              $count++;
                         }
                    }
                    close NDDCONF;
                    
                    &B_append_line($nddconf, "", "TRANSPORT_NAME[$count]=tcp\n");
                    &B_append_line($nddconf, "", "NDD_NAME[$count]=tcp_isn_passphrase\n");
                    &B_append_line($nddconf, "", "NDD_VALUE[$count]=$passphrase\n");
                    
                    # make the configuration take effect
                    &B_System("$ndd -c");
                    
                    # delete the line we just added before
                    my $retval = &B_replace_lines($nddconf,
                                     [
                                        [ '^NDD_VALUE\['                .    "$count"     .    '\]=.*$',     ""],
                                        [ '^NDD_NAME\['                 .    "$count"     .    '\]=.*$',     ""],
                                        [ '^TRANSPORT_NAME\['      .    "$count"     .    '\]=.*$',     ""]
                                     ]);
                    
                    # restore the permissions
                    &B_chmod(0444,$nddconf);
                    close(NDDCONF);
               }
          }
          &CreateBootSriptForTcpIsn;
     
          # warn against  that
          # Bastille has configured another boot script to do this
          # Adding a second definition will result in an error
          my $warning_msg = <<WARNING_MSG;
# Bastille has configured another boot script to set tcp_isn_passphrase
# Adding a second definition for it in /etc/rc.config.d/nddconf will result in an error
WARNING_MSG
               
          &B_append_line($nddconf, "", $warning_msg);
     }
}

# The purpose of this subroutine is to add to the TODO.txt list some information
# about how the user should determine which ports are world listening
sub Netstat {
    if (&getGlobalConfig("HP_UX","scan_ports") eq "Y") {
	&B_log("ACTION","# sub Netstat\n");
	my $netstat_text =
	    "Run a port scan to see what processes are still listening:\n" .
            "We recommend that you download the \"lsof\" tool from\n" .
            "  ftp://vic.cc.purdue.edu/pub/tools/unix/lsof/\n" .
            "and then run\n" .
            "  /path/to/lsof -i\n" .
	    "However you may also use the built-in tool \"netstat\" like:\n" .
	    "  /usr/bin/netstat -an\n" .
            "for a comprehensive listing of processes which are listening on\n" .
            "external ports.  More information is in the netstat man page and\n" .
            "the lsof documentation.\n\n";
	&B_TODO("\n---------------------------------\nPort Scan:\n" .
		"---------------------------------\n" .
		$netstat_text, "HP_UX.scan_ports");
    }
}

#
# CIS implemenation screensaver_timeout
#
# notes:
#---------------------------------------------------------------------------------------------
# The default timeout is between 10 and 30 minutes of keyboard/mouse
# inactivity before a password-protected screen saver is invoked by the
# CDE session manager depending on the OS release and the locale.
# The above Action uniformly reduces this default timeout value to 10 minutes,
# though this setting can still be overridden by individual users in their own environment.
#
sub ScreensaverTimeout {
      if (&getGlobalConfig("HP_UX","screensaver_timeout") eq "Y") {
          my $timeout = 10;
          &B_log("ACTION","# sub ScreensaverTimeout\n");
          my @files = glob("/usr/dt/config/*/sys.resources");
          use File::Basename;
          foreach my $file (@files) {
               chomp $file;
               my $dir = dirname($file);
               $dir =~ s|^/usr/|/etc/|;
               my $filename = $dir . "/sys.resources";
               if ( ! -d $dir ) {
                    &B_create_dir($dir);
               }
               if ( ! -e $filename ) {
                    &B_cp($file, $filename);
               }
               
               if ( &B_match_line($filename, '^\s*dtsession\*saverTimeout:') ) {
                    &B_replace_lines($filename,
                    [
                       [ '^\s*(dtsession\*saverTimeout: )(.*)$', '$1 ' .  $timeout ]
                    ]
                    );
               }
               else {
                    &B_append_line($filename, 'a$b', "dtsession*saverTimeout: " . $timeout . "\n");
               }
               
               if ( &B_match_line($filename,  '^\s*dtsession\*lockTimeout:') ) {
                    &B_replace_lines($filename,
                         [
                              [ '^\s*(dtsession\*lockTimeout: )(.*)$', '$1 ' .  $timeout ]
                         ]
                    );
               }
               else {
                    &B_append_line($filename, 'a$b', "dtsession*lockTimeout: " . $timeout . "\n");
               }
          }
     }
}

#
# CIS implementation gui_banner
#
# notes:
#-----------------------------------------------------------------------------------------
# The standard graphical login program for HP-UX requires the user
# to enter their username in one dialog box and their password in a
# second separate dialog.  The commands above set the warning
# message on both to be the same message, but the site has the
# option of using different messages on each screen.
# The Dtlogin*greeting.labelString is the message for the first dialog
# where the user is prompted for their username, and .perslabelString
# is the message on the second dialog box. Note that system
# administrators may wish to consult with their site’s legal council
# about the specifics of any warning banners. 
#
#
sub WarningBannerForGUI {
     if (&getGlobalConfig("HP_UX","gui_banner") eq "Y") {
          &B_log("ACTION","# sub WarningBannerForGUI\n");
          my $banner="Authorized users only. All activity may be monitored and reported.";
          my @files = glob("/usr/dt/config/*/Xresources");
          use File::Basename;
          foreach my $file (@files) {
               chomp $file;
               my $dir = dirname($file);
               $dir =~ s|^/usr/|/etc/|;
               my $filename = $dir . "/Xresources";
               if ( ! -d $dir ) {
                    &B_create_dir($dir);
               }

               if ( ! -e $filename) {
                    &B_cp($file,$filename);
               }
               
               if ( &B_match_line($filename, '^\s*Dtlogin\*greeting\.labelString:') ) {
                    &B_replace_lines($filename,
                         [
                              [ '^\s*(Dtlogin\*greeting\.labelString:)(.*)$',          '$1 ' . $banner ]
                         ]
                    );
               }
               else {
                    &B_append_line($filename, 'a$b', "Dtlogin*greeting.labelString: $banner\n");
               }
               
                if ( &B_match_line($filename, '^Dtlogin\*greeting\.persLabelString:') ) {
                    &B_replace_lines($filename,
                         [
                              [ '^\s*(Dtlogin\*greeting\.persLabelString:)(.*)',       '$1 ' . $banner]
                         ]
                    );
               }
               else {
                    &B_append_line($filename, 'a$b', "Dtlogin*greeting.persLabelString: $banner\n");
               }
               &B_chown((getpwnam("root"))[2], $filename);
               &B_chgrp((getgrnam("sys"))[2], $filename);
               &B_chmod("0644", $filename);
          }
     }
}

# give pointers to other tools
sub OtherTools {

  if(&getGlobalConfig("HP_UX","other_tools") eq "Y"){

    my $toolinfo = "HP-UX Bastille can help you configure a lot of the security\n" .
                   "relevant parts of the HP-UX Operating System.  However, it\n" .
                   "is not a complete security solution.  HP provides many other\n" .
                   "tools which should be used in concert with your local security\n" .
                   "policies to ensure that you are adequately protected from attack.\n" .
                   "The following is a brief overview of some of the products and\n".
                   "services which are available, but not yet referenced elsewhere\n".
                   "within Bastille:\n\n";

                   # This can eventually be replaced by a more granular selection of types of
                   # tools the user might be interested in by putting if's around sections of
                   # text.
                   #------------ proper spacing point of reference-----------------------------

    $toolinfo .= "  - Authentication and other directory services:\n";
    $toolinfo .= "    * The hp-ux AAA server provides authentication, authorization\n" .
                 "      and accounting services using the RADIUS protocol\n";
    $toolinfo .= "    * The hp-ux Kerberos server provides key distribution and strong \n" .
                 "      authentication for client/server applications by using secret-key\n".
                 "      cryptography\n";
    $toolinfo .= "    * ldap-ux allows hp-ux to use LDAP based directory servers,\n" .
                 "      allowing a single repository for user, group and other\n" .
                 "      organizational data, integrating user authentication\n" .
                 "      among many different organizational tools and HP-UX.\n\n";

    $toolinfo .= "  - VPN\n";
    $toolinfo .= "    * hp-ux IPSec/9000 provides secure and private communication\n".
                 "      over the Internet and within the enterprise-without modifying\n".
                 "      existing applications\n";

    $toolinfo .= "  - Intrusion Detection Software\n";
    $toolinfo .= "    * IDS/9000 enhances host-level security with near real-time\n".
                 "      automatic monitoring of each configured host for signs of\n".
                 "      potentially damaging intrusions\n".
                 "    * Tripwire is a tool for ensuring the integrity of your data\n".
                 "      and detecting and analyzing intrusions after they have \n".
                 "      happened.  See\n".
                 "        http://www.tripwire.org\n" .
                 "      (Tripwire is not an HP supported product)\n\n";

    $toolinfo .= "  - Replacement for telnet, remsh, and ftp\n";
    $toolinfo .= "    * hp-ux secure shell provides a secure alternative for all\n".
                 "      your file transfer and remote shell needs.\n\n";

    $toolinfo .= "  - Special purpose security Operating System\n";
    $toolinfo .= "    * Virtual Vault is an HP-UX based operating system with root\n" .
                 "      containment features.  It is the only trusted and proven\n" .
                 "      Web-server platform on the market with no reported break-ins.\n\n";
    $toolinfo .= "  - Consulting\n";
    $toolinfo .= "    * HP consultants can help you with a variety of security needs,\n".
                 "      including penetration tests, custom security architectures,\n".
                 "      and creating custom Bastille configs to suit your\n".
                 "      unique needs.\n\n";

    $toolinfo .= "New tools and resources are being released all the time.  Check\n".
                 "  http://www.hp.com/security\n".
                 "for more resources and information.\n\n";

     &B_TODO("\n---------------------------------\nOther Tool Information:\n" .
	     "---------------------------------\n" .
	     $toolinfo);

  }
}

sub MailConfig {
    if(&getGlobalConfig("HP_UX","mail_config") eq "Y"){
	&B_log("ACTION","# sub MailConfig");
        my $config_email='bastille-configs@fc.hp.com';
        my $todo_email='bastille-todo@fc.hp.com';
        my $feedback_email='bastille-feedback@fc.hp.com';

        my $mailprogram = &getGlobal('BIN','mail');
        my $config = &getGlobal ("BFILE", "current_config");
	my $todo = &getGlobal('BFILE','TODO');
        my $echo = &getGlobal('BIN','echo');
        my $uname = &getGlobal('BIN','uname');

        &B_System("$mailprogram -s \"\$($uname -a)\" $config_email < $config",
                  "$echo \"REVERT\" | $mailprogram -s \"\$($uname -a)\" $config_email ");

	&B_TODO("\n---------------------------------\nConfiguration File Mailing:\n" .
		"---------------------------------\n" .
		"Your config file and TODO list have been mailed to\n".
		"$config_email and $todo_email respectively.\n" .
                "If you have other feedback or feature requests, please\n".
		"send it to $feedback_email.  We are especially interested in your\n" .
                "priorities in terms of TODO items you feel need automation and what\n".
		"features and lockdown steps you feel are missing entirely.\n".
		"Thank you.\n\n");

	&B_Backtick("$mailprogram -s \"\$($uname -a)\" $todo_email < $todo");

    }
}

1;









