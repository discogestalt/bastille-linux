# Copyright (C) 1999, 2000 Jay Beale
# Copyright (C) 2001-2003 Hewlett Packard Development Company, L.P.
# Licensed under the GNU General Public License, version 2

package Bastille::DNS;
use lib "/usr/lib";

use Bastille::API;
use Bastille::API::HPSpecific;
use Bastille::API::ServiceAdmin;
use Bastille::API::FileContent;
use Bastille::API::AccountPermission;
use File::Basename;
use File::Path;

@ENV="";
$ENV{PATH}="";
$ENV{CDPATH}=".";
$ENV{BASH_ENV}="";

#######################################################################
##                             DNS/BIND/NAMED                        ##
#######################################################################

&chrootHPBIND;
&chrootLINUXBIND;
&DeactivateNamed;

my $TODOText = "";

# The chroot bind functions are split up for easier line-coverage
# counting and because the routines are completely different for
# HP-UX and Linux (currently)
sub chrootHPBIND {
    my $todo_header=0;

    if ( &getGlobalConfig("DNS","chrootbind") eq "Y" ) {

	# Only chroot bind in this routine if we are running on a HP-UX
        # system and we haven't already chroot'ed it...
	if(&GetDistro =~ "^HP-UX"){
	    &B_log("ACTION","# sub chrootHPBIND\n");
	    my $user = "named";
	    my $what  = &getGlobal('BIN',"what");
	    my $named = &getGlobal('FILE',"named");
	    my $awk   = &getGlobal('BIN',"awk");
	    my $findversion="$what $named | $awk '\$1==\"named\" {print \$2}'";
	    my $bindversion=&B_Backtick("$findversion");
	    chomp $bindversion;
	    $bindversion =~ s/^(\d*)\..*$/$1/;

	    if ($bindversion < 8) {
	        $TODOText .= "\n---------------------------------\nChroot'ed Bind:\n" .
		    "---------------------------------\n".
		    "Bastille can only chroot Bind versions 8 or higher.\n" .
		    "Please install the latest version of Bind and rerun\n" .
		    "bastille -b.\n\n";
		$todo_header=1;
	    } elsif ($bindversion > 9) {
		&B_log("WARNING","Bastille has not been tested with Bind versions\n" .
			  "         later than 9. Attempting to continue anyway.");
	    }

	    if($bindversion >= 8) {
		# all checks complete attempting to install the jail
		&installJail($bindversion);
	    }
	    # finished chroot now writing out TODO information
            # NOTE: TODOText was modified by installJail
	    if($TODOText ne "") {
		&B_TODO($TODOText,"DNS.chrootbind");
	    }
	}

    }
}


sub chrootLINUXBIND {

    if ( &getGlobalConfig("DNS","chrootbind") eq "Y" ) {

	unless ( (&GetDistro =~ /^RH/) or (&GetDistro =~ /^MN/) or (&GetDistro =~ /^SE/) ) {
	    return 1;
	}

	&B_log("ACTION","# sub chrootLINUXBIND\n");

	my $distro = &GetDistro;

	if ($distro =~ /^RHEL/ or $distro =~ /^RHFC/ ) {
	    # Chrooting BIND is easy on RHEL -- just set the
	    # ROOTDIR variable in /etc/sysconfig/named.

	    &B_replace_line(&getGlobal('FILE','sysconfig_named'),'^ROOTDIR\s*=\s*$',"ROOTDIR=/var/named\n");
	    &B_append_line(&getGlobal('FILE','sysconfig_named'),'^ROOTDIR\s*=\s*[^\s]+\s*$',"ROOTDIR=/var/named\n");
	}
	elsif ($distro =~ /^SESLES/ or $distro =~ /^SE9/ ) {
	    # Chrooting BIND is easy on SLES and later SUSE versions -- just set the NAMED_RUN_CHROOTED to "yes" in
	    # /etc/sysconfig/named
	    &B_replace_line(&getGlobal('FILE','sysconfig_named'),'^\s*NAMED_RUN_CHROOTED=\s*$',"NAMED_RUN_CHROOTED=\"YES\"\n");
	    &B_append_line(&getGlobal('FILE','sysconfig_named'),'^\s*NAMED_RUN_CHROOTED=\s*yes\s*$',"NAMED_RUN_CHROOTED=\"YES\"\n");
	}

	#
	# The process below is for older systems running BIND 8, though
	# it also works for BIND 9.  Newer distributions use BIND 9,
	# which uses no dynamically-linked libraries and thus chroots
	# far, far more easily.
	#

	# Only chroot bind if we are running on a Red Hat / Mandrake
        # system and we haven't already chroot'ed it...
	elsif ( (&GetDistro =~ /^RH/) or (&GetDistro =~ /^MN/) ) {

	    #
	    # First figure out where the chroot prison would be setup, so that we can
	    # check for its existence.  If it already exists, we won't recreate it.
	    #

	    my $user ="";
	    my $group = "";
	    my $gid = "";

	    # Look for a DNS user already on the operating system
	    foreach $name ( 'dns','named' ) {
		if (getpwnam($name)) {
		    $user = $name;
		}
	    }
	    if ($user) {
		$home_dns = (getpwnam($user))[7];
	    }
	    else {
		$home_dns = '/home/dns';
	    }

	    # Continue only if we haven't already performed this chroot.

	    unless ( -e "${home_dns}/lib/libc.so.6" ) {

		# Make the dns chroot directory
		&B_create_dir ( $home_dns );

		    # Look for a DNS group already on the operating system
		foreach $name ( 'dns','named' ) {
		    if (getgrnam($name)) {
			$group = $name;
			$gid = getgrnam($name);
		    }
		}


		#
		# Create the dns user/group, if one doesn't yet exist
		#

		unless ($group) {
		    $gid = '53';
		    &B_append_line ("/etc/group",":53:","dns:x:53:\n");
		    $group = 'dns';
		}
		unless ($user) {
		    &B_append_line ("/etc/passwd",":$gid:","dns:x:53:$gid::$home_dns:/bin/false\n");
		    &B_append_line("/etc/shadow","^dns:","dns:*:11089:0:99999:7:::\n");
		    $user = 'dns';
		}

		# Populate the dns chroot directory
		&B_create_dir ("$home_dns");
		&B_create_dir ("$home_dns/etc");
		&B_chmod (0755,"$home_dns/etc");
		&B_create_dir ("$home_dns/lib");
		&B_chmod (0755,"$home_dns/lib");
		&B_create_dir ("$home_dns/dev");
		&B_chmod (0755,"$home_dns/dev");
		&B_create_dir ("$home_dns/usr");
		&B_chmod (0755,"$home_dns/usr");
		&B_create_dir ("$home_dns/usr/sbin");
		&B_chmod (0755,"$home_dns/usr/sbin");
		&B_create_dir ("$home_dns/var");
		&B_chmod (0755,"$home_dns/var");
		&B_create_dir ("$home_dns/var/named");
		&B_chmod (0755,"$home_dns/var/named");
		&B_create_dir ("$home_dns/var/run");
		&B_chmod (0755,"$home_dns/var/run");
		&B_create_dir ("$home_dns/var/run/named");
		&B_chmod (0755,"$home_dns/var/run/named");


		unless ($GLOBAL_LOGONLY) {
		    &B_mknod(" -m 666 ","$home_dns/dev/null"," c 1 3");

		    &B_cp("/etc/named.conf","$home_dns/etc/named.conf");

		    # Should we tell them to move their name logs over?

		    &B_cp("/var/named/named.ca","$home_dns/var/named/named.ca");
		    &B_cp("/var/named/named.local","$home_dns/var/named/named.local");

		    my $command=&getGlobal('BIN',"chown");
		    &B_Backtick("$command -R $user.$user $home_dns/var/named $home_dns/var/run $home_dns/var/run/named");
		    &B_cp("/usr/sbin/named","$home_dns/usr/sbin/named");
		    &B_chmod(0755,"$home_dns/usr/sbin/named");
		    # Don't delete named -- let it get loaded from /usr/sbin, but
		    # find data files in the chroot directory.  We'll still put
		    # a copy of the binary in the chroot directory so the named
		    # binary can be reloaded from there if necessary.
		    #
		    #&B_delete_file("/usr/sbin/named");
		    my $namedxfer = &getGlobal('BIN',"named-xfer");
		    if (-e $namedxfer ) {
			&B_cp($namedxfer,"$home_dns" . $namedxfer);
			&B_chmod(0755,"$home_dns" . $namedxfer);
		    }
		    &B_cp("/lib/libc.so.6","$home_dns/lib/libc.so.6");
		    &B_cp("/lib/ld-linux.so.2","$home_dns/lib/ld-linux.so.2");
		}

		# named communicates normally with syslog via the device /dev/log,
		# which isn't accessible from the chroot'd environment.  We set
		# syslog to create and listen to a specific device just for bind.

		&B_replace_line("/etc/rc.d/init.d/syslog",'daemon syslogd -m 0\s*\$',"daemon syslogd -m 0 -a $home_dns/dev/log\n");
		&B_replace_line("/etc/rc.d/init.d/syslog",'daemon syslogd $SYSLOGD_OPTIONS\s*\$',"daemon syslogd \$SYSLOGD_OPTIONS -a $home_dns/dev/log\n");


		# Modify named's init script to use the chroot environment

		my $bind8=1;
		if (&GetDistro =~ /MN(\d+\.\d+)/) {
		    if ($1 >= 8.0) {
			$bind8=0;
		    }
		}
		elsif (&GetDistro =~ /RH(\d+\.\d+)/) {
		    if ($1 >= 7.1) {
			$bind8=0;
		    }
		}

		if ( $bind8 ) {
		    &B_replace_line("/etc/rc.d/init.d/named",'^\s*daemon\s+named',"daemon named -u $user -g $group -t $home_dns\n");
		}
		else {
		    # Mandrake 8.0 and later, along with Red Hat 7.1 and later, use BIND 9, which deprecated the -g option.
		    # Nicely, all of these run as an alternate user already.

		    if (&GetDistro =~ /MN/) {
			if ( -e '/etc/sysconfig/named' ) {
			    &B_replace_line('/etc/sysconfig/named','^\s*ROOTDIR\s*=',"ROOTDIR=$home_dns\n");
			    &B_append_line('/etc/sysconfig/named','^\s*ROOTDIR\s*=\s*\/',"ROOTDIR=$home_dns\n");
			}
			else {
			    &B_replace_line("/etc/rc.d/init.d/named",'^\s*daemon\s+named',"daemon named -u $user -t $home_dns\n");
			}
		    }
		    elsif (&GetDistro =~ /RH/) {
			&B_replace_line('/etc/sysconfig/named','^\s*ROOTDIR\s*=',"ROOTDIR=$home_dns\n");
			&B_append_line('/etc/sysconfig/named','^\s*ROOTDIR\s*\=\s*',"ROOTDIR=$home_dns\n");
		    }
		}

	    }
	}
    }
}



sub DeactivateNamed {


    if (&getGlobalConfig("DNS","namedoff") eq "Y") {

	&B_log("ACTION","# sub DeactivateNamed\n");

	# Deactivate BIND unless it is being used.

	&B_chkconfig_off ("named");
    }

}



sub installJail($) {
    my $version=$_[0];

    # adding user for the named process
    my $jail = &getGlobal('BDIR',"jail");
    my $isJailed = 0;
    if(-e $jail . "/bind" ) {
	$isJailed = 1;
    }

    # add chroot user

    my $user = &addUser("named");
    if($user eq "0") {
	# error unable to add user
	&B_log("ERROR","Unable to add user.\n" .
                  "         CHROOT OF BIND UNSUCCESSFUL!\n" );
	return 0;
    }
    # install generic chroot tree
    if(&B_install_jail("bind",&getGlobal('BFILE',"jail.generic.hpux"))) {
	my $copyComplete=0;
	# add dev/null and dev/log to chroot tree
	&B_mknod("", "$jail/bind/dev/null","c 3 0x000002");
	&B_chmod(0666,"$jail/bind/dev/null");
	&B_System(&getGlobal('BIN','mkfifo') . " -p -m 0666 " . $jail . "/bind/dev/log",
		  &getGlobal('BIN','rm') . " -f " . $jail . "/bind/dev/log");

	if($version == 8){
	    # install bind 8 specific files and directories.
	    &B_log("ACTION","Bind 8 chroot directory setup\n");
	    if (&B_install_jail("bind", &getGlobal('BFILE',"jail.bind.hpux"))){
		$copyComplete=1;
	    }
	} else {
	    # install bind 9 specific files and directories.
	    &B_log("ACTION","Bind 9 chroot directory setup\n");
	    if(&B_install_jail("bind",&getGlobal('BFILE',"jail.bind9.hpux"))){
		$copyComplete=1;
	    }
        }

	if ($copyComplete && (! $isJailed)) {
	    # add group file
	    &B_cp(&getGlobal('FILE',"group"), "$jail/bind/etc/group");
	    &B_chmod(0444, "$jail/bind/etc/group");
	    &B_chown((getpwnam("bin"))[2], "$jail/bind/etc/group");
	    &B_chgrp((getgrnam("bin"))[2], "$jail/bind/etc/group");

	    my $pidfile = &getGlobal('FILE', "named.pid");

	    &B_chown((getpwnam("$user"))[2], "$jail/bind/var/run");
	    &B_chgrp((getgrnam("$user"))[2], "$jail/bind/var/run");
	    &B_chmod(0755, "$jail/bind/var/run");

	    my $initscript = &getGlobal('FILE',"chkconfig_named");
	    my $syslogd = &getGlobal('BIN',"syslogd");

	    my $ps =  &getGlobal('BIN',"ps");
	    my $namedIsRunning = 0;
	    my @psTable = `$ps -el`;
	    # seeing if the named process is running on the system
	    foreach my $process ( @psTable ) {
		if($process =~ /named/){
		    $namedIsRunning = 1;
		}
	    }

	    my $isSetToRun = &B_get_rc("NAMED");

	    my $named = &getGlobal('FILE',"named");
	    my $named_conf = &getGlobal('FILE',"named.conf");
	    my $dataDirectory = undef;
	    my @dbFiles;
	    my $todoChroot = 0;

	    if( -e $named_conf ) {
		if(open(NAMED_CONF,"<$named_conf")) {
		    while (my $line = <NAMED_CONF>) {
			if ($line =~ /file\s+\"(.+)\"/) {
			    push @dbFiles, $1;
			}
			elsif ($line =~ /directory\s+\"(.+)\"/) {
			    $dataDirectory = $1;
			}
		    }
		    close(NAMED_CONF);
		}
		else {
		    &B_log("ERROR","Unable to open $named_conf for read.\n$!\n");
		    $todoChroot = 1;
		}
	    }
	    else {
		&B_log("ACTION","The $named_conf file does not exist on this machine.\n" .
			   "Instructions on the chroot will be provided instead.\n");

		$todoChroot = 1;
	    }

	    if((defined $dataDirectory) && (! -d $dataDirectory) ) {
		$todoChroot = 1;
	    }

	    foreach my $dbFile ( @dbFiles ) {
		if(! -f "${dataDirectory}/${dbFile}" ) {
		    $todoChroot = 1;
		}
	    }

	    my $mv = &getGlobal('BIN',"mv");
	    my $ln = &getGlobal('BIN',"ln");
	    my $rm = &getGlobal('BIN',"rm");

	    if((! $todoChroot) && $isSetToRun) {

		# make a path to the data directory inside the jail
		# pruning last / off of the directory name
		$dataDirectory =~ s/(.*)\/$/$1/;
		$dataParent = dirname($dataDirectory);
		# making a path to the jailed data directory
		mkpath( $jail . "/bind" . $dataParent,0,0555 );

		# moving the data directory into the jail
		&B_System("$mv $dataDirectory $jail/bind$dataDirectory" ,
			  "$mv $jail/bind$dataDirectory $dataDirectory" );
		# linking the jailed data directory back to the original location
		&B_System("$ln -s $jail/bind$dataDirectory $dataDirectory" ,
			  "$rm $dataDirectory" );

		# ensuring that the new named user will be able to operate on the
		# bind files defined in named.conf
		foreach my $dbFile ( @dbFiles ) {
		    &B_chmod(0700,"${dataDirectory}/${dbFile}" );
		    &B_chown((getpwnam($user))[2], "${dataDirectory}/${dbFile}");
		    &B_chgrp((getgrnam($user))[2], "${dataDirectory}/${dbFile}");
		}

		# mv named inside the jail
		# ln named back to /etc/
		# moving the data directory into the jail
		&B_System("$mv $named_conf " . $jail . "/bind" . $named_conf ,
			  "$mv " . $jail . "/bind" . $named_conf . " $named_conf" );
		&B_System("$ln -s " . $jail . "/bind" . $named_conf . " $named_conf" ,
			  "$rm $named_conf" );

		&B_chmod(0444,"${jail}/bind${named_conf}" );

		if($namedIsRunning) {
		    &B_System("$initscript stop","$initscript start");
		}

		# setting named to run inside of the chrooted environment
                &B_set_rc("NAMED_ARGS",
			   "\'\"\`($rm $pidfile; $ln -s $jail/bind$pidfile $pidfile) 2>/dev/null\` " .
			   "-u $user -t $jail/bind\"\'");

		if(&B_System("$initscript start","$initscript stop")) {
                    sleep 5;
	            my $runningInJail = 0;
	            my @psTable = `$ps -ef`;
	            # seeing if the named process is running on the system
	            foreach my $process ( @psTable ) {
		        if($process =~ /named/ and $process =~ /jail/){
		            $runningInJail = 1;
		        }
	            }
                    if ($runningInJail) {
		       &B_log("ACTION","Bastille has successfully chrooted named on this system\n");
                    } else {
                       &B_log("ERROR","named chroot was UNSUCCESSFUL.  Check your syslog for clues\n".
                                 "         (usually /var/adm/syslog/syslog.log)  Also, you might check\n".
                                 "         the permissions of the directories/files in\n".
                                 "             $jail/bind\n");
                    }
		}
		else {
		    &B_log("ERROR","Bastille was unable to successfully chroot named.\n" .
			      "         Look at " . &getGlobal("BFILE","TODO") . "\n" .
			      "         for information to finish the chrooting process.\n");
		    $TODOText .= "\n---------------------------------\n" .
			    "Chroot'ed Bind:\n" .
			    "---------------------------------\n" .
			    "Bastille has created a simple \"named\" directory structure\n" .
			    "$jail/bind/\n\n" .
			    "Bastille has also moved the directories that are identified\n" .
				   "inside of the options section of your named.conf file which\n" .
			    "has also been moved into the jail.\n" .
			    "To resolve the issues that are currently keeping Bind from\n" .
			    "starting successfully inside of the jail structure that was\n" .
			    "constructed for it, you can review the \"named\" man page as\n" .
			    "well as the named.conf file that is present inside of your\n" .
			    "bind jail.\n\n";
		}
	    }
	    else {
		# give instructions of the finishing of the chroot
		$TODOText .= "\n---------------------------------\nChroot'ed Bind:\n" .
			"---------------------------------\n";
		$TODOText .= "Bastille has created a simple \"named\" directory structure in\n" .
			"$jail/bind/\n\n" .
			"You need to take the following steps to configure your name server\n" .
			"to run without root privileges in a chroot jail.  If you were not\n" .
			"running named before and do not plan to in the future, then you can\n" .
			"ignore these steps.\n\n";

		# create the finish-up script
		my $sh = &getGlobal('BIN',"sh");
		my $finishscript = &getGlobal('BFILE', "finish-named-chroot.sh");
		&B_create_file("$finishscript");
		&B_blank_file("$finishscript",'a$b This pattern does not match anything');

		&B_append_line("$finishscript","", "#!$sh\n");
		&B_append_line("$finishscript","", "$initscript stop\n");
		&B_append_line("$finishscript","",
			       "# Link the process id file into the jail and instruct the \"named\" init \n" .
			       "# script to chroot into the new environment and run as user \"named\".\n");
                my $ch_rc=&getGlobal('BIN','ch_rc');
		&B_append_line("$finishscript","",
			       "$ch_rc" . " -a -p NAMED_ARGS=" .
			       "\'\"\`(rm $pidfile; ln -s $jail/bind$pidfile $pidfile) 2>/dev/null\` " .
			       "-u named -t $jail/bind\"\'\n");
		&B_append_line("$finishscript","",
			       "$ch_rc -a -p NAMED=1 # to enable named, if not already\n");
		&B_append_line("$finishscript","", "$initscript start # start named using its init script\n\n");
		&B_append_line("$finishscript","", &getGlobal('BIN',"sleep") . " 5 # sleep for 5 seconds\n\n");
		&B_append_line("$finishscript","",
			       "if [ \"\$(ps -ef | " . &getGlobal("BIN","grep") .
                               " named | grep jail)\" = \"\" ]; then\n" .
			       "echo named chroot was UNSUCCESSFUL.\n" .
			       "echo \"Check your syslog for clues.  (usually /var/adm/syslog/syslog.log)\"\n" .
			       "echo Also, you might check the permissions of the directories/files in\n" .
			       "echo $jail/bind\n" .
			       "else\n" .
			       "echo named appears to be running inside of the chroot jail\n" .
			       "echo \n" .
			       "fi\n");

		$TODOText .= "1: Stop the currently running \"named\" process using the system\'s\n" .
			"   init script for \"named\" \n\n" .

			"   type_this> $initscript stop\n\n" .

			"   and remove all \"/var/run/named.*\" files if they exist.\n\n" .

			"   type_this> rm -r /var/run/named.*\n\n" .

			       "2: Next, move all of the configuration files that the current \n" .
			"   \"named\" implementation requires from their current locations into\n" .
			       "   the equivalent place in the jail structure.  This is at least a\n" .
			"   \"named.conf\" file.  If there is a directory path specified in the\n" .
			"   options section of the \"named.conf,\" that path must be made as well\n" .
			"   as all of the files that are referenced from that directory.  Hint: \n" .
			"   If you create links like: \"ln -s <in_jail_location> <out_of_jail_location>,\"\n" .
			       "   then you can unchroot named without breaking anything.  Remember, however,\n" .
			"   that any files owned by the named user can be modified if an attacker\n" .
			"   breaks into bind as the \"named\" user.  By creating links, an attacker\n" .
			"   could make changes which affect files outside of the jail too.\n\n" .

			"   NOTE: all bind database files need to be readable by the user \"named.\"\n\n" .

			"3: Run the finish-named-chroot.sh script that Bastille has created for you.\n\n" .

			"   type_this> $finishscript\n\n" ;

	    }


	}
	else {
	    if(! $copyComplete) {
		&B_log("ERROR","Copy of necessary files was unsuccessful while\n" .
                          "          trying to install the chroot bind jail.\n");
	    }
	    else {
		&B_log("ACTION","Chroot binaries were recopied into the jail.\n");
	    }
	}

    }

    return 1;
} #End InstallJail


sub addUser {

    my $user = $_[0];
    &B_log("ACTION","adding user $user\n");
    # adding user for the named process
    my $success = 0;
    my $inc = 0;
    my $jail = &getGlobal('BDIR',"jail");
    while(! $success) {
	my ($name,$passwd,$uid,$gid,$quota,$comment,$gcos,$dir,$shell) = getpwnam($user);  # seeing if the user name $user is already used by the system
	$gid = getgrnam($user);
	# if the user name $user that was generated has already been used
	# in either the password or group files then
	if( $uid =~ /\d+/ && $gid =~ /\d+/ ) {
	    $home_dir = &getGlobal('BDIR',"jail") . "/bind/tmp";
	    # if this user was added by Bastille then reuse it.
	    if($dir =~ "$home_dir") {
		# returning user.
		return "$user";
	    }
	    # if all 1000 permutations of the user name are used then
	    if($inc >= 999) {  # Note this limit is based on the 8 character *nix username
		# Fail the chroot and return
		&B_log("ERROR","Unable to find an unused user name for the named chroot.\n" .
			  "         Please rerun Bastille after removing the the system user\n" .
			  "         and group \"named\" from the password and group files.\n" .
			  "         The chroot of bind failed.\n");
		return 0;
	    }
	    else { # otherwise define an new user name from the incremented counter
		$user = "named" . $inc;
		$inc++;
	    }
	}
	elsif( $uid =~ /\d+/ || $gid =~ /\d+/ ) {
	    # one or the other is used so we will continue to look
	    $user = "named" . $inc;
	    $inc++;
	}
	else { # the user name specified is unused and can safely be added.
	    #
	    # create non-privileged user and group named
	    my $groupadd = 'PATH="/usr/bin"; ' . &getGlobal('BIN',"groupadd") . " $user";
	    my $groupdel = 'PATH="/usr/bin"; ' . &getGlobal('BIN',"groupdel") . " $user";
	    my $useradd = 'PATH="/usr/bin"; ' . &getGlobal('BIN',"useradd") .
		" -g $user -d $jail/bind/tmp -s /usr/bin/false $user";
	    my $userdel = 'PATH="/usr/bin"; ' . &getGlobal('BIN',"userdel") . " $user";

	    # if the group is added successfully then
	    if ( &B_System($groupadd,$groupdel)) {
		# if the username is added successfully
		if ( &B_System($useradd, $userdel)) {
		    &B_log("ACTION","user: $user and group: $user have been added to the system.\n");
		    $success = 1;
		}
		else {
		    # attemping to remove the group that was added
		    my $groupdelOutput = &B_Backtick("$groupdel");
		    &B_log("ACTION","Bastille was unable to add the user $user to the system.\n" .
			       "In turn the Bastille attempted to remove the group added.\n" .
			       "The output of that command is as follows:\n" .
			       "# $groupdel\n" .
			       "$groupdelOutput\n" .
			       "Another unused user name will be attempted.\n");
		    &B_System($groupdel,$groupadd);
		    $user = "named" . $inc;
		    $inc++;
		}
	    }
	    else { # could not add the group to the system
		&B_log("ACTION","The group $user could not be added to the system\n" .
			   "Another unused group name will be tried.\n");
		$user = "named" . $inc;
		$inc++;

	    }
	}

    } # end while
    # at this point a named user has been added.
    return "$user";
}
1;





