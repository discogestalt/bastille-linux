# Copyright (C) 1999, 2000 Jay Beale
# Copyright (C) 2001-2003,2005-2008 Hewlett Packard Development Company, L.P.
# Licensed under the GNU General Public License, version 2

package Bastille::AccountSecurity;
use lib "/usr/lib";


use Bastille::API;
use Bastille::API::AccountPermission;
use Bastille::API::HPSpecific;
use Bastille::API::FileContent;


#######################################################################
##                     Account Creation/Security                     ##
#######################################################################

&ProtectRhosts;
&PasswordAging;
&PasswordStrength_Linux;
&RestrictCronAt;
&RestrictCrontabsFile;
&UserRCFiles;
&UserDotFiles;
&RestrictHome;
&LockAccountEmptyPassword;
&DisableSerialPortLogin;
&DisableGUILogin;
&NoDotInRootPath;
&BlockSystemAccounts;
&UnOwnedFiles;
&SetMesgN;
&SetUmask;
&RootTTYLogins;
&Securetty;

# HPDefaultSecurity sets values in /etc/default/security.  Similar
# settings are set by setPWpolicies for existing users and/or trusted
&HPDefaultSecurity;
&HPSingleUserPassword;
&HPEnableAudit;

# Do this one last to decrease the chances of hitting a needed trusted
# mode conversion after converting to shadow passwords
# Passwords will be hidden if hidepasswords or you want password policies
&HPHidePasswords;

&setPWpolicies;

&RemoveUnnecessaryAccounts;
&RemoveUnnecessaryGroups;

sub appendOrReplace ($$$) {
    my $fullpath = $_[0];
    my $regex = $_[1];
    my $stringToAdd = $_[2];

    if ( -e $fullpath ) {
        unless (&B_replace_line( $fullpath,"$regex","$stringToAdd")) {
            &B_append_line( $fullpath ,"$regex","$stringToAdd");
        }
    }
}

sub ProtectRhosts { # Linux

    if ( &getGlobalConfig("AccountSecurity","protectrhost") eq "Y" ) {

	&B_log("ACTION","# sub ProtectRhosts\n");

	unless (&GetDistro =~ /^OSX/) {
	    # Disallow rlogin,rsh,rexec via Pluggable Authentication Modules
	    foreach $service ( "rexec","rlogin","rsh","login" ) {
		if ( -e &getGlobal('DIR', "pamd") . "/$service" ) {
		    &B_prepend_line(&getGlobal('DIR', "pamd") . "/$service","pam_deny","auth      required   pam_deny.so\n");
		}
	    }
	}

	# Deactivate the daemons by removing execute status
	&B_chmod_if_exists(0000,&getGlobal('BIN',"rlogind"));
	&B_chmod_if_exists(0000,&getGlobal('BIN',"rshd"));
	&B_chmod_if_exists(0000,&getGlobal('BIN',"rexecd"));

	# Deactivate the user binaries by removing execute status and confirming that files are owned by root:root
	&B_chmod_if_exists(0000,&getGlobal('BIN',"rlogin"));
	&B_chmod_if_exists(0000,&getGlobal('BIN',"rsh"));
	&B_chmod_if_exists(0000,&getGlobal('BIN',"rcp"));

	# Comment out rsh/rlogin/rexec lines from inetd.conf
        # Note: SecureInetd.pm does this too.
	if ( -e &getGlobal('FILE', "inetd.conf") ) {
	    &B_hash_comment_line( &getGlobal('FILE', "inetd.conf"),"rlogind");
	    &B_hash_comment_line( &getGlobal('FILE', "inetd.conf"),"rexecd");
	    &B_hash_comment_line( &getGlobal('FILE', "inetd.conf"),"rshd");
	}
	if ( -e &getGlobal('FILE','xinetd.conf') ) {
	    # Some systems, including Mac OS X, have an inetd.conf file even when they're xinetd-based.
	    # Actually, you can have both inetd and xinetd running, so longer as they don't overlap ports.
	    foreach $file ('exec','login','rlogin','shell','rsh') {
		if (( -e &getGlobal('DIR', "xinetd.d") . "/$file") && (&getGlobal('DIR', "xinetd.d") ne "")) {
		    &B_replace_line(&getGlobal('DIR', "xinetd.d") . "/$file",'disable\s*=',"\tdisable\t\t= yes\n");
		    &B_insert_line(&getGlobal('DIR', "xinetd.d") . "/$file",'disable\s*=',"\tdisable\t\t= yes\n",'server\s*=');
		}
	    }
	}
    }
}


sub PasswordAging { # Linux

# Set default password aging, such that accounts are disabled if the
# password is not changed every 60 days.  We use this hopefully to keep
# passwords fresh and automatically disable accounts that haven't been
# used in a while.  We could create a cron job that parses lastlog looking
# for unused accounts, but that would fail if your lastlog got deleted by
# an attacker or cycled by your log cycler, as the cron job would disable
# many accounts...

    if (&getGlobalConfig("AccountSecurity","passwdage") eq "Y") {
	&B_log("ACTION","# sub Password Aging\n");
	&B_log("ACTION","adding PASS_MAX_DAYS setting to /etc/login.defs\n");

	# Make sure a PASS_MAX_DAYS line is modified or added.
        my $got_replaced=&B_replace_line("/etc/login.defs",'^\s*PASS_MAX_DAYS',"PASS_MAX_DAYS   60\n");
        unless ($got_replaced) {
            B_append_line("/etc/login.defs",'^\s*PASS_MAX_DAYS',"PASS_MAX_DAYS   60\n");
        }
	# Add a warning period - TODO: in the future, gain the ability to
	# check the warning period in place already so that longer ones are
	# not replaced by shorter ones.
	&appendOrReplace("/etc/login.defs",'^\s*PASS_WARN_AGE',"PASS_WARN_AGE   5\n");
    }
}

sub PasswordStrength_Linux {

# Set password strength requirements, including a minimum length requirement of 8 characters

    return;

    if (&getGlobalConfig("AccountSecurity","password_strength_linux") eq "Y") {
	&B_log("ACTION","# sub Password Strength Linux\n");

	if ( -e "/lib/security/pam_passwdqc.so") {
	    &B_log("ACTION","activating pam_passwdqc (password quality control) to /etc/pam.d/passwd\n");

            &appendOrReplace("/etc/pam.d/passwd",
                             '^\s*password\s+required\s+pam_passwdqc\.so',
                             "password required pam_passwdqc.so min=disabled,disabled,disabled,disabled,8 random=0\n");
	}
    }
}

#
# CIS implementation user_rc_files
#
# notes:
#---------------------------------------------------------------------------------------------------
# .netrc files may contain unencrypted passwords
# that may be used to attack other systems,
# while .rhosts files used in conjunction with
# the BSD-style <93>r-commands<94> (rlogin, remsh, rcp)
# implement a weak form of authentication based on the network address
# or host name of the remote computer
# (which can be spoofed by a potential attacker to exploit the local system).
#
sub UserRCFiles {
    if ( &getGlobalConfig("AccountSecurity","user_rc_files") eq "Y" )  {
        &B_log("ACTION","# sub UserRCFiles\n");
        
        # find homes
        my @homes = &B_find_homes();
        foreach my $home (@homes) {
            if ( -d $home ) {
                if ( -e "$home/.netrc") {
                    &B_delete_file("$home/.netrc");
                }
                if ( -e "$home/.rhosts") {
                    &B_delete_file("$home/.rhosts");
                }
                if ( -e "$home/.shosts") {
                    &B_delete_file("$home/.shosts");
                }   
            }
            
        }
    }
}

#
# CIS implementation user_dot_files
#
# notes:
#---------------------------------------------------------------------------------
# Group or world-writable user configuration files may enable
# malicious users to steal or modify other users' data
# or to gain another user's system privileges
#
sub UserDotFiles {
    if ( &getGlobalConfig("AccountSecurity","user_dot_files") eq "Y" ) {
        &B_log("ACTION","# sub UserDotFiles\n");
        # find non-root loginable homes
        my @homes = &B_find_homes();
        my $ls = &getGlobal("BIN","ls");
        foreach my $home (@homes) {  
            # all dot files under the home directory
            if ( -d $home ) {
                my @dotfiles = `$ls -d $home/.[!.]* 2>&1`;
                if (($?>>8) != 0 ) {
                    &B_log("DEBUG", "# sub UserDotFiles failed  for backtick " . "$ls -d $home/.[!.]*") ;
                    next;
                }
                foreach my $dot (@dotfiles) {
                    chomp $dot;
                    if ( ! -l $dot  && -f $dot ) {
                        B_chmod("go-w", $dot);
                    }
                }
            }
        }
    }
}

#
# CIS implementation block_system_accounts
#
# notes:
#-----------------------------------------------------------------------------------------------------
# Accounts that are not being used by regular users should be locked.
# Not only should the password field for the account be set to an invalid string,
# but the shell field in the password file should contain an invalid shell.
#
sub BlockSystemAccounts {
    
    if ( &getGlobalConfig("AccountSecurity","block_system_accounts") eq "Y" )  {
        &B_log("ACTION","# sub BlockSystemAccounts\n");
        
        # system account to be blocked
        my @userlist = qw | www sys smbnull
                                        iwww owww sshd
                                        hpsmh named uucp
                                        nuucp adm daemon
                                        bin lp nobody noaccess hpdb useradm|;
                                        
        if (&GetDistro =~ '^HP-UX11.(\d*)')  {
            my $distroVersion = $1;
            my $false = &getGlobal("BIN","false");
            my $passwd = &getGlobal("BIN", "passwd");
            
            # 11.23 use usermod.sam and 11.31 use usermod
            my $usermod;
            if ( &GetDistro =~ "^HP-UX11.(.*)" and $1 <= 23 ) {
                $usermod = &getGlobal("BIN","usermod.sam");
            }
            else {
                $usermod = &getGlobal("BIN","usermod");
            }
            
            foreach my $user (@userlist) {
                
                # if $user exists in /etc/passwd
                if (getpwnam($user)) {
                    
                    # lock account
                    &B_System("$passwd -l $user"); # no revert; rtn to NP is security risk

                    # user's shell change to /bin/false
                    my $org_shell = (getpwnam($user))[8];
                    $org_shell =~ s/\s+//g;
                
                    # if the orginal shell is not empty before lockdown
                    if ( ! $org_shell ) {
                        &B_System("$usermod -F -s $false $user");
                    }
                    else {
                        &B_System("$usermod -F -s $false $user", "$usermod -F -s $org_shell $user");
                    }  
                }
                
                # trusted mode lock
                my $tcb = &getGlobal("FILE","tcb");
                if ( -e $tcb) {
                    my $modprpw = &getGlobal("BIN","modprpw");
                    &B_System("$modprpw -m alock=YES $user", "$modprpw -m alock=NO $user");
                }
                
            }
        }
    }   
}

#
# CIS implementation unowned_files
#-----------------------------------------------
#
# It is a good idea to locate files that are owned by users
# or groups not listed in the system configuration files,
# and make sure to reset the ownership of these files to
# some active user on the system as appropriate.
#
sub UnOwnedFiles {
     if ( &getGlobalConfig("AccountSecurity","unowned_files") eq "Y" ) {
        &B_log("ACTION","# sub UnOwnedFiles\n");
        my $find = &getGlobal("BIN","find");
        
	# optional list of dirs that $find should not descend (via -prune)
	my $avoid_paths=""; 
	if (&GetDistro =~ '^HP-UX11.31SRPcont') {
		$avoid_paths="-o -path /stand -o -path /sbin -o -path /usr" ;
	} elsif (&GetDistro =~ '^HP-UX11.31SRPhost') {
		$avoid_paths="-o -path /var/hpsrp" ;
	} else {
		# empty
	}

        open UNOWN, "$find / \\\( -fstype nfs $avoid_paths \\\) -prune -o  \\\( -nouser -o -nogroup \\\) -print |"; 
        while($file = <UNOWN>) {
            chomp $file;
            # remove worldwritable suid and sgid bits
            # B_chmod will only change the mode of the target if $file is a link    
            # &B_chmod("o-w,u-sg", $file);
            # change the ownership of $file if it is unowned or ungrouped, not follow the link.
            if ( &B_is_unowned_file($file) ) {
                &B_chown_link("bin", $file);
            }
            if ( &B_is_ungrouped_file($file) ) {
                &B_chgrp_link("bin", $file);
            }
        }
        close UNOWN;
     }
}


# Restrict at/cron (cron as example)
# 1. If cron.deny exists, delete the file.
# 2. If cron.allow exists, blank the file.
#    If no cron.allow, create the file.
# 3. Append the only account "root" into cron.allow.
# 4. chown root:sys cron.allow.
# 5. chmod 0400 cron.allow.

sub restrictAtOrCron ($) {
    
    # $_ should be either "at" or "cron"
    my $deny = $_[0] . ".deny";
    my $allow = $_[0] . ".allow";

    # If at/cron.deny exists, delete it
    my $denyFile = &getGlobal('FILE', $deny);
    if ( -e $denyFile) {
        &B_delete_file($denyFile);
    }

    # If at/cron.allow exists, blank it.
    # Or if no at/cron.allow, create it.
    # Append the only account "root" into the file.
    my $allowFile = &getGlobal('FILE', $allow);
    if (-e $allowFile) {
        # attention,  I gave a strange pattern to make it will not match.
        &B_blank_file($allowFile,"$=*()$@^");
    }
    else {
        &B_create_file($allowFile);
    }
    &B_append_line($allowFile,'^root$',"root\n");

    # chown root:sys at/cron.allow
    # chmod 0400 at/cron.allow
    &B_chown((getpwnam("root"))[2], $allowFile);
    &B_chgrp((getgrnam("sys"))[2], $allowFile);
    &B_chmod(0400, $allowFile);
}

#
# CIS implementaton cronuser atuser
# -----------------------------
# Restrict at/cron to authorized users
# -------------------------------------------------
#
sub RestrictCronAt {
   if ( &getGlobalConfig("AccountSecurity","cronuser") eq "Y" ) {
       &B_log("ACTION","# sub RestrictCron\n");
       &restrictAtOrCron('cron');
   }
   if ( &getGlobalConfig("AccountSecurity","atuser") eq "Y" ) {
       &B_log("ACTION","# sub RestrictAt\n");
       &restrictAtOrCron('at');
   }
}

#
# CIS implementation crontabs_file
#
# notes:
# -----------------------------------------------------------------------------------------------------
# The system crontab files are accessed only by the cron daemon
# (which runs with superuser privileges) and the crontab command
# (which is set-UID to root).  Allowing unprivileged users to read or (even worse)
# modify system crontab files can create the potential for a local user
# on the system to gain elevated privileges.
#
sub RestrictCrontabsFile {
    if ( &getGlobalConfig("AccountSecurity","crontabs_file") eq "Y" ) {
        &B_log("ACTION","# sub RestrictCrontabsFile\n");
        my $crontabs_dir = &getGlobal("DIR","crontabs");
        my $ls = &getGlobal("BIN","ls");
        my @files = `$ls $crontabs_dir`;
        if (($?>>8) != 0 ) {
             &B_log("DEBUG", "# sub RestrictCrontabsFile failed  for backtick " . "$ls $crontabs_dir") ;
             return 1;
        }
        foreach my $file (@files) {
            chomp $file;
            $file = "$crontabs_dir" . "/" ."$file";
            &B_chmod(0400, $file);
            &B_chown(0,$file);
            &B_chgrp((getgrnam("sys"))[2],$file);
        }
    }
}

#
# CIS implementation restrict_home
#---------------------------------------------------------------------------------------------------------
# Group or world-writable user home directories may enable malicious users
# to steal or modify other users' data or to gain another user's system privileges.
# While the above modifications are relatively benign, making global modifications
# to user home directories without alerting your user community can result in
# unexpected outages and unhappy users.
# 
sub RestrictHome {

    if ( &getGlobalConfig("AccountSecurity","restrict_home") eq "Y") {
        &B_log("ACTION","# sub RestrictHome\n");
        # find non-root loginable homes
        my @homes = &B_find_homes();
        my $roothome = (getpwnam("root"))[7];
        foreach my $home (@homes) {
            chomp $home;
            # applied to all non-root homes
            if ($home eq $roothome ) {
                next;
            }
            if ( -d $home ) {
                B_chmod("g-w",$home);
                B_chmod("o-rwx",$home);
            }  
        }
    }
}

#
# CIS implementation lock_account_nopasswd
#-----------------------------------------------------
# Verify that there are no accounts with empty password fields
#
sub LockAccountEmptyPassword {
     if ( &getGlobalConfig("AccountSecurity","lock_account_nopasswd") eq "Y" ) {
        &B_log("ACTION","# sub LockAccountEmptyPassword\n");
    
        my $logins = &getGlobal("BIN", "logins");
        my $passwd = &getGlobal("BIN","passwd");
        my @entries = `$logins -ox`;
        if ( ($? >> 8) != 0 ) {
            &B_log("DEBUG", "# sub LockAccountEmptyPassword failed  for backtick " .  "$logins -ox");
            return 0;
        }
        foreach my $entry ( @entries ) {
            chomp($entry);
            my @data = split(/:/,$entry);
            if ( $data[7] =~ /NP/ ) {
                B_System("$passwd -l $data[0]", "$passwd -d $data[0]");
            }
        }
     }
}

# 
# CIS implementation serial_port_login
#------------------------------------------------
# Disable login: prompts on serial ports
# 
sub DisableSerialPortLogin {
    if ( &getGlobalConfig("AccountSecurity","serial_port_login") eq "Y" ) {
        &B_log("ACTION","# sub DisableSerialPortLogin\n");
        my $inittab = &getGlobal("FILE", "inittab");
        &B_hash_comment_line($inittab, '^[^#].*getty.*tty.*$');
        my $init = &getGlobal("BIN", "init");
        # re-read /etc/inittab;
        &B_System("$init q");
        # &B_chown((getpwnam("root"))[2], $inittab);
        # &B_chgrp((getgrnam("sys"))[2],$inittab);
        # &B_chmod("go-w",$inittab);
        # &B_chmod("ug-s",$inittab);
    }
}


# 
# CIS implementation gui_login
#---------------------------------------
# Disable GUI login, if possible
#
sub DisableGUILogin {
    if ( &getGlobalConfig("AccountSecurity","gui_login") eq "Y" ) {
        
        &B_log("ACTION","# sub DisableGUILogin\n");
        
        #These are services associated with the GUI login, and relevant to CIS
        &B_ch_rc("xfs"); #/etc/rc.config.d/xfs
        &B_ch_rc("audio");  #/etc/rc.config.d/audio
        &B_ch_rc("slsd");  #/etc/rc.config.d/slsd;

        my $dtlogin = &getGlobal("BIN", "dtlogin.rc");
        if ( -e $dtlogin) { #TODO: Should we do this check or write regardless?
            #Note setting DESKTOP to "0" is okay since check is "!= CDE"
            &B_ch_rc("dtlogin.rc"); # #dtlogin and dtrc processes?
        }
    }
}



#
# CIS implementation root_path
#----------------------------------------------
# No '.' or group/world-writable directory in root $PATH
#
sub NoDotInRootPath {
     if ( &getGlobalConfig("AccountSecurity","root_path") eq "Y" ) {
        &B_log("ACTION","# sub NoDotInRootPath\n");
        
        my $root_shell= (getpwnam("root"))[8] ;

        if ( $root_shell !~ "/sh" ) {
            &B_log("ACTION","Root shell, $root_shell, is not Posix. TODO.txt item generated instead.\n");
            &B_TODO("\n---------------------------------\n" .
		    "No '.' or group/world-writable directory in root \$PATH:\n" .
		    "---------------------------------\n" .
		    "Bastille detected that root in this system does not use posix shell\n" .
                    "But Bastille only support posix shell  for this item\n" .
                    "So if you want to ensure No '.' or group/world-writable directory is in root \$PATH:\n" .
                    "you can set it yourself using the command provided by the shell you are using\n");
	    return;
        }
        
	# for posix shell  
        my $files = [ &getGlobal("FILE","profile") ];
        my $roothome = (getpwnam("root"))[7];
        # if root's home is not "/".  the the home directory get from getpwnam will like this: /home/root
        if ( $roothome ne "/" ) {
            $roothome .= "/";
        }
        my $localprofile = $roothome . ".profile";
        unshift @$files, $localprofile;

        my $local_profile_change_todo_txt = "\n" .
            "---------------------------------\n" .
            "No '.' or group/world-writable directory in root \$PATH:\n" .
            "---------------------------------\n" .
            "Bastille has detected vulnerable directories introduced into the root \$PATH .\n" .
            "Fixed PATH assignments have been appended to the local root profile $localprofile \n" .
            "to immediately address this vulnerability, but this is only a short-term measure. \n" .
            "Identify and correct the original source of the root \$PATH vulnerabilities,\n" .
            "and then remove the temporary Bastille fixed PATH assignments in $localprofile .\n" .
            "Review the files $localprofile, /etc/profile, and /etc/PATH for possible sources.\n";

	my $bastille_comment="# BASTILLE #: lockdown modification: root_path #####"; 
        
        for my $file (@$files) {
            my @path_arr = &B_get_path($file);
            
            my @good_path;
            my @bad_path;
            for my $dir (@path_arr) {
                chomp $dir;
                if ( $dir ne "."  &&
                    ! &B_permission_test("group", "w", $dir) &&
                    ! &B_permission_test("other","w", $dir)) {
                   push @good_path, $dir;
                } else {
		   push @bad_path, $dir; 
		}
            }
            
            if ( @bad_path ) {
                &B_log("ACTION","Insecure \$PATH components found from sourcing file: $file .\n");
		my $good_path_str="";
                my $set_path_cmd="";

		$good_path_str = join(":", @good_path)  if ( @good_path ); 

                if ( $file eq $localprofile ) {
                    # local profile producing insecure PATH 
                    # mod local profile to:
                    #   save original PATH on entrance 
		    &B_prepend_line( $file, 'ORIGPATH=', "$bastille_comment  \n" .
                                                         "   ORIGPATH=\$PATH \n" .
                                                         "\n" );
                    #   set sanitized PATH on exit 
                    $set_path_cmd = 'PATH=$ORIGPATH:' . $good_path_str;
                    &B_append_line($file, "", "\n"                   .
                                              "$bastille_comment \n" .
                                              "   $set_path_cmd  \n" );
                }
                else {
                    # global profile producing insecure PATH
                    # mod _local_ profile to replace existing PATH on entrance 
                    #   with sanitized global profile PATH
                    $set_path_cmd = 'PATH=' . $good_path_str;
                    my $comment2="# BASTILLE #: static PATH replacement for insecure PATH from /etc/profile #";
                    &B_prepend_line($localprofile, "", "\n"                    .
                                                       "$bastille_comment \n"  .
                                                       "$comment2 \n"          .
                                                       "   $set_path_cmd \n"   .
                                                       "\n" );
                }
                # remind user to investigate root cause of insecure path
                &B_TODO( $local_profile_change_todo_txt );
            }
        }
     }
}

# 
# CIS implementation mesgn
#
# notes:
#--------------------------------------------------------------------------------------------
# "mesg n" blocks attempts to use the write or
# talk commands to contact the user at their terminal,
# but has the side effect of slightly strengthening permissions on the user's tty device.
# Since write and talk are no longer widely used at most sites,
# the incremental security increase is worth the loss of functionality.
# Note that this setting is the default on HP-UX 11i.
#
sub SetMesgN {
    if ( &getGlobalConfig("AccountSecurity","mesgn") eq "Y" ) {
        &B_log("ACTION","# sub SetMesgN\n");

        my @filelist = (&getGlobal("FILE","profile"),
                        &getGlobal("FILE","csh.login"),
                        &getGlobal("FILE","d.profile"),
                        &getGlobal("FILE","d.login"));
                        
        for my $file (@filelist) {
            if ( -e $file ) {
                # Replace "mesg [yg]" by "mesg n", 
                # or append "mesg n" into the file.
                &appendOrReplace($file, '^\s*mesg\s+[yg]', "mesg n\n");
            }
        }
    }
}

sub SetUmask {
    if ( &getGlobalConfig("AccountSecurity","umaskyn") eq "Y" ) {
	&B_log("ACTION","# sub SetUmask\n");

        # set the umask in all known shell startup scripts
        my $umask = &getGlobalConfig("AccountSecurity","umask");
        if ($umask =~ /^[1-7]/){ #safer to have non-zero leading umask
            $umask = "0" . $umask;
        }

	my @filelist = ("profile", "rootprofile", "zprofile", "csh.login");

	if (&GetDistro =~ '^OSX') {
	    @filelist = ("profile", "csh.login");
	}
        for my $startupfile (@filelist) {
           my $fullpath=&getGlobal('FILE', $startupfile);
	   &appendOrReplace($fullpath, '^(\s*)*umask',"umask $umask\n");
        }

        # on HP-UX11.22 and later, set the system umask for all pam_unix(5)
        # initiated sessions
	if (&GetDistro =~ "^HP-UX11.(.*)" and $1>20) {
	    if (defined $umask) {
		my $secfile = &getGlobal('FILE','security');
		&B_set_value('UMASK', $umask, $secfile);
	    }
	}
    }
}

sub RootTTYLogins { # Linux
    if ( &getGlobalConfig("AccountSecurity","rootttylogins") eq "Y" ) {
	&B_log("ACTION","# sub RootTTYLogins\n");
	my $securetty = &getGlobal('FILE','securetty');

        if ( -e $securetty) {
            my $tty;
            foreach $tty (1,2,3,4,5,6,7,8,9,0) {
                &B_delete_line($securetty, "tty$tty");
                &B_delete_line($securetty, "vc/$tty");
            }
	}
        else {
            # A missing /etc/securetty file would allow root login from
            # anywhere.
            &B_create_file($securetty);
            &B_append_line($securetty,
                           '#.*must\s+exist',
                           '# This file must exist to block root logins, so don\'t delete it unless you want to imply "root may login on any tty device."');
        }

        # Prevent root from logging in via a graphical display manager.
        if (( -e '/etc/pam.d/xdm' ) || ( -e '/etc/pam.d/gdm' ) || ( -e '/etc/pam.d/kde' )) {
	    &B_create_file("/etc/bastille-no-login");
	    &B_append_line("/etc/bastille-no-login",'\broot\b',"root\n");
        }
	# stop root from logging in via xdm
#       &B_append_line("/etc/X11/xdm/Xresources","xlogin\.Login\.allowRootLogin","xlogin.Login.allowRootLogin: false");
# TODO: Determine why the above line was commented out.
	if ( -e '/etc/pam.d/xdm') {
	    &B_prepend_line("/etc/pam.d/xdm",'bastille-no-login',"auth\trequired\t/lib/security/pam_listfile.so onerr=succeed item=user sense=deny file=/etc/bastille-no-login\n");
	}

	# stop root from logging in via gdm
#       &B_replace_line("/etc/X11/gdm/gdm.conf",'^\s*AllowRoot\b',"AllowRoot=0\n");
# TODO: Determine why the above line was commented out.
	if ( -e '/etc/pam.d/gdm') {
	    &B_prepend_line("/etc/pam.d/gdm",'bastille-no-login',"auth\trequired\t/lib/security/pam_listfile.so onerr=succeed item=user sense=deny file=/etc/bastille-no-login\n");
	}

	# stop root from logging in via kdm
	if ( -e '/etc/pam.d/kde') {
	    &B_prepend_line("/etc/pam.d/kde",'bastille-no-login',"auth\trequired\t/lib/security/pam_listfile.so onerr=succeed item=user sense=deny file=/etc/bastille-no-login\n");
	}
    }
}

sub RestrictUserView { # Linux

    # This routine restricts the kdm/gdm userview in Linux-Mandrake
    # Motivation: Compabilitity with msec

    if (&getGlobalConfig("AccountSecurity","forbiduserview") eq "Y") {
	&B_log("DEBUG","# sub RestrictUserView\n");

	# Old KDM's use UserView, while new ones use ShowUsers.
	my $kdmrc = &getGlobal('FILE','kdmrc');
	&B_replace_line($kdmrc,'^UserView\s*=',"UserView=false\n");
	&B_replace_line($kdmrc,'^\s*ShowUsers\s*=',"ShowUsers=None\n");

	# Now do gdm.  Older ones use Browser= 0 or 1, while newer ones use true or false.
	my $gdmconf = &getGlobal('FILE','gdm.conf');
	&B_replace_line($gdmconf,'^Browser\s*=\s*1","Browser=0\n');
	&B_replace_line($gdmconf,'^Browser\s*=\s*(true|True|TRUE)","Browser=false\n');

    }
}

sub Securetty {

    if (&getGlobalConfig("AccountSecurity","create_securetty") eq "Y") {

	&B_log("DEBUG","# sub Securetty\n");

	my $securetty = &getGlobal('FILE', "securetty");
	unless ( -e $securetty ) {
	    &B_create_file($securetty);
	}
	&B_blank_file($securetty,'a$b');
	&B_append_line($securetty,"console","console\n");

    }

}


sub HPDefaultSecurity {

    if (&GetDistro =~ "^HP-UX") {
	my $secfile = &getGlobal('FILE','security');

	# options to disallow logins by normal users
	# ABORT_LOGIN_ON_MISSING_HOMEDIR - don't login if homedir is missing
	# NOLOGIN - don't login if /etc/nologin exists
	foreach my $param ("ABORT_LOGIN_ON_MISSING_HOMEDIR", "NOLOGIN", ) {
	    if (&getGlobalConfig("AccountSecurity","$param") eq "Y") {
		&B_set_value("$param", '1', $secfile);
	    }
	}

	### Set password policies
        ### This sets values in /etc/default/security ONLY.  Corresponding trusted
        ### mode parameters are set in convertToTrusted.
        ###
	if (&getGlobalConfig("AccountSecurity","passwordpolicies") eq "Y") {
	  if (&GetDistro =~ "^HP-UX11.(.*)" and $1>20) {

	    if ((&isTrustedMigrationAvailable) and
                (not(&isSystemTrusted))){
		&convertToShadow; #Reduce coniguration test-matrix for HP-UX
		# Password-Policy interactions. (rf-12/1/05, jd/kb agreed)
	    }
	    #TODO: Add MIN_DIGIT and MIN_SPECIAL Questions.
	    foreach my $param ("MIN_PASSWORD_LENGTH",
			       "PASSWORD_MAXDAYS",
			       "PASSWORD_MINDAYS",
			       "PASSWORD_WARNDAYS",) {
		&B_set_value("$param",
			     &getGlobalConfig("AccountSecurity", $param), $secfile);
	    }

	    if (&getGlobalConfig("AccountSecurity", "PASSWORD_HISTORY_DEPTHyn") eq "Y") {

	        &B_set_value("PASSWORD_HISTORY_DEPTH",
			     &getGlobalConfig("AccountSecurity", "PASSWORD_HISTORY_DEPTH"), $secfile);
		#conversion attempt below doesn't occur if the Migration Package is
		#available (Perl "partial evaluation" behavior)
                if (!&isTrustedMigrationAvailable && !&convertToTrusted) {
                  &B_TODO("\n" .
                      "------------------------------------\n" .
                      "Password History Depth:\n" .
		      "------------------------------------\n".
                      "Because Trusted System conversion was unsuccessful, you\n".
                      "will need to use SAM/SMH to convert to Trusted mode before\n".
                      "the password history depth will take effect.\n", # TODOFlag
                      "AccountSecurity.PASSWORD_HISTORY_DEPTHyn");
                }
	    }
          }
	}


	if (&getGlobalConfig("AccountSecurity", "NUMBER_OF_LOGINS_ALLOWEDyn") eq "Y") {
	    &B_set_value("NUMBER_OF_LOGINS_ALLOWED",
			 &getGlobalConfig("AccountSecurity", "NUMBER_OF_LOGINS_ALLOWED"), $secfile);
	}

	if (&getGlobalConfig("AccountSecurity", "AUTH_MAXTRIESyn") eq "Y") {
	    &B_set_value("AUTH_MAXTRIES",
			 &getGlobalConfig("AccountSecurity", "AUTH_MAXTRIES"), $secfile);
	}

	if (&getGlobalConfig("AccountSecurity", "SU_DEFAULT_PATHyn") eq "Y") {
	    &B_set_value("SU_DEFAULT_PATH",
			 &getGlobalConfig("AccountSecurity", "SU_DEFAULT_PATH"), $secfile);
	}
    }
}

# HPHidePasswords - either convert to trusted mode or shadow depending on OS version
sub HPHidePasswords {

   if( &getGlobalConfig('AccountSecurity',"hidepasswords") eq "Y" ||
       &getGlobalConfig('AccountSecurity',"passwordpolicies") eq "Y") {
      &B_log("DEBUG","# sub HPHidePasswords\n");

      if (&isSystemTrusted) {
         &B_log("DEBUG","System is already trusted, passwords are hidden, no action taken.");
         return 1;
      }

      if ( -e &getGlobal('FILE','shadow') ) {
         &B_log("DEBUG","System already has shadow passwords, passwords are hidden, no action taken.");
         return 1;
      }

      if (&GetDistro =~ "^HP-UX11.(.*)" and $1<22) {
          # Conversion to trusted mode is required on 11.20 and prior
          &convertToTrusted;
      } else {
          &convertToShadow;
      }
   }
}

sub HPSingleUserPassword {
    # set password for single user mode
    if (&getGlobalConfig("AccountSecurity","single_user_password") eq "Y") {
	&B_log("DEBUG","# sub HPSingleUserPassword\n");
        if ((&GetDistro =~ "^HP-UX11.(.*)") and (&isTrustedMigrationAvailable) and
            (not(isSystemTrusted))) {
            # On versions of HP-UX 11.23 and later, we don't need to convert to trusted
	    # BOOT_AUTH - require root password to enter single user mode.
            &B_log("DEBUG","Trusted-mode conversion not necessary as IdMI installed");
	} elsif ( &convertToTrusted ) {
		# set single user password, if requested and the system is in trusted mode.
		my $getprdef = &getGlobal('BIN','getprdef');
		my $oldbootpwstring=&B_Backtick("$getprdef -m bootpw");
		chomp $oldbootpwstring;

		if ($oldbootpwstring ne "bootpw=YES") {
		    my $newbootpwstring="bootpw=YES";
		    &B_System(&getGlobal('BIN','modprdef') . " -m $newbootpwstring",
			      &getGlobal('BIN','modprdef') . " -m $oldbootpwstring");
		}
	    } else {
		&B_TODO("\n" .
			"------------------------------------\n" .
			"Set a password for single user mode:\n" .
			"------------------------------------\n".
			"Because Trusted System conversion was unsuccessful, you\n".
			"will need to use SAM/SMH to require a password for single user mode.\n", #TODOFlag
                        "AccountSecurity.single_user_password");
	    }
            #Do this regardless, just in case.
	    &B_set_value("BOOT_AUTH", '1', &getGlobal('FILE','security'));
    }
}

sub HPEnableAudit {
   # enable auditing
   if (&getGlobalConfig("AccountSecurity","system_auditing") eq "Y") {
       &B_log("DEBUG","# sub HPEnableAudit\n");

       # Conversion to trusted mode is required on HP-UX version 11.23 and prior
       # that don't have security extensions installed
       if (&isTrustedMigrationAvailable || &convertToTrusted) {

	    if (&isTrustedMigrationAvailable) { #Set additional flag for security mode extensions
		&B_set_value("AUDIT_FLAG", 1, &getGlobal('FILE','security'));
	    }

            my $auditSwitchSize = 10240;

           &B_set_rc("PRI_SWITCH",$auditSwitchSize);
           &B_set_rc("SEC_SWITCH",$auditSwitchSize);

           my ($auditFilesDir, $audnamesDir, $auditFileOne, $auditFileTwo);

           #Only set the secondary audit files prior to 11.31, since
           #11.31 introduces a new audit-file automatic switching mechanism.
           #Also, 11.31 introduced a new default audit directory, so make sure
           #that exists.

           #Changed to always put the files here as this dir doesn't get wiped upon tsconvert -r
           $auditFilesDir = &getGlobal('BDIR', 'audit31');

           if (&GetDistro =~ "^HP-UX11\.(.*)" and $1 >= 31) {
                $auditFileTwo = '*';
                $audnamesDir = $auditFilesDir;
           } else {
                $audnamesDir = &getGlobal('BDIR', 'auditPre31');
                $auditFileTwo = $auditFilesDir . "/" . &getGlobal('BFILE', 'auditFileTwo');
           }
           &B_create_dir($auditFilesDir);
           $auditFileOne = $auditFilesDir . "/" . &getGlobal('BFILE', 'auditFileOne');
           &B_set_rc("PRI_AUDFILE", $auditFileOne);
           &B_set_rc("SEC_AUDFILE", $auditFileTwo);

           #Now shut down the service if auditing may be on

           if(&B_get_rc("AUDITING") =~ /1/){
               &B_System(&getGlobal('FILE', 'chkconfig_auditing') . " stop", &getGlobal('FILE', 'chkconfig_auditing') . " start");
           } else{
               &B_set_rc("AUDITING",1);
           }

           if(&B_get_rc("START_ACCT") =~ /1/){
               &B_System(&getGlobal('FILE', 'chkconfig_acct') . " stop", &getGlobal('FILE', 'chkconfig_acct') . " start");
           } else{
               &B_set_rc("START_ACCT",1);
           }


           if (not( -e $audnamesDir . "/audnames")){
               my $mv = &getGlobal('BIN', 'mv');
               my $filesToBackup;

               if ((&GetDistro =~ "^HP-UX11\.(.*)") and ($1 < 31)) {
                  $filesToBackup = "$auditFileOne $auditFileTwo";
               } else {
                  $filesToBackup = "$auditFileOne";
               }
               my ($second, $minute, $hour, $day, $month, $year, $wd, $dy, $ds) = localtime;
               $year += 1900;
               my $backupDir = $auditFilesDir . "/AuditBackup_" .
                  "${year}_${month}_${day}_${hour}:${minute}:${second}" ;
               &B_create_dir($backupDir);
               &B_Backtick("$mv $filesToBackup $backupDir");
           }

           #(re)start the auditing service

           &B_System(&getGlobal('FILE', 'chkconfig_auditing') . " start",
                     &getGlobal('FILE', 'chkconfig_auditing') . " stop");
           &B_System(&getGlobal('FILE', 'chkconfig_acct') . " start",
                     &getGlobal('FILE', 'chkconfig_acct') . " stop");
       } else {
              &B_TODO("\n" .
                      "------------------------------------\n" .
                      "Enable auditing:\n" .
		      "------------------------------------\n".
                      "Because Trusted System conversion was unsuccessful and \n".
		      "HP-UX Standard-Mode Extensions are not installed, you\n".
                      "will need to enable auditing manually, or fix the problem\n" .
                      "and rerun Bastille.\n",     #TODOFlag
                      "AccountSecurity.system_auditing");

       }
   }
}

sub setPWpolicies {

    if (&getGlobalConfig("AccountSecurity","passwordpolicies") eq "Y") {
        my $exptm=  &getGlobalConfig("AccountSecurity","PASSWORD_MAXDAYS");
        my $mintm=  &getGlobalConfig("AccountSecurity","PASSWORD_MINDAYS");
        my $expwarn=&getGlobalConfig("AccountSecurity","PASSWORD_WARNDAYS");
	my $passwd=&getGlobal('BIN','passwd') . " -r files";
	my $userlistcmd="$passwd -s -a";
        my $modprpw=&getGlobal('BIN','modprpw');

	if (&isSystemTrusted) {

	    &B_log("DEBUG","#sub setPWpolicies\n");
	    my $getprdef = &getGlobal('BIN','getprdef');

	    my $oldsettings = &B_Backtick("$getprdef -m exptm,mintm,expwarn");
	    $oldsettings =~ s/ //g;

	    # remove password lifetime and increasing login tries so they
	    # don't lock themselves out of the system entirely.
	    my $newsettings="exptm=$exptm,mintm=$mintm,expwarn=$expwarn";

	    &B_System(&getGlobal('BIN','modprdef') . " -m $newsettings",
		      &getGlobal('BIN','modprdef') . " -m $oldsettings");

            open USERS,"$userlistcmd|";
	    while (my $line=<USERS>) {
		chomp $line;
                my ($name, $status, $date, $oldmin, $oldmax, $oldwarn)=split(/\s+/, $line);
                chomp ($name, $newsettings, $oldsettings);
                B_System("$modprpw" . " -m $newsettings -l $name",
                         "$modprpw" . " -m $oldsettings -l $name");
            }
            close USERS;
	}
	elsif ( -e &getGlobal('FILE','shadow') ) {
	    open USERS,"$userlistcmd|";
	    while (my $line=<USERS>) {
		chomp $line;
		my ($name, $status, $date, $oldmin, $oldmax, $oldwarn)=split(/\s+/, $line);
		# if warn is set to 0, the field will be blank
		if (not defined $oldwarn || $oldwarn eq "") {
		    $oldwarn=0;
		}

		if ($name!~/root/) {
		    if (defined $oldmin && defined $oldmax) {
			&B_System("$passwd -n $mintm -x $exptm -w $expwarn $name",
				  "$passwd -n $oldmin -x $oldmax -w $oldwarn $name");
		    } else {
			&B_System("$passwd -n $mintm -x $exptm -w $expwarn $name",
				  "$passwd -x -1 $name");
		    }
		}
	    }
	    close USERS;
	}
	else {
	    &B_TODO("\n---------------------------------\n" .
		    "Password policies:\n" .
		    "---------------------------------\n" .
		    "Because trusted system conversion or shadow password\n" .
		    "conversion failed, you will need to manually set password\n" .
		    "policies using SAM/SMH or the passwd command.  Alternatively,\n" .
		    "fix the problem that caused the conversion to fail and\n".
		    "rerun Bastille.\n");
            &B_TODOFlags("set","AccountSecurity.PASSWORD_MAXDAYS");
            &B_TODOFlags("set","AccountSecurity.PASSWORD_MINDAYS");
            &B_TODOFlags("set","AccountSecurity.PASSWORD_WARNDAYS");

	}

    }
}

sub RemoveUnnecessaryAccounts {

    # This function removes unncessary accounts, as dictated by AccountSecurity.removeaccounts (Y/N)
    # and AccountSecurity.removeaccounts_list (accounts to remove, comma-separated)

    if (&getGlobalConfig('AccountSecurity','removeaccounts') eq "Y") {
	my @accounts_to_remove = split /\s+/,&getGlobalConfig('AccountSecurity','removeaccounts_list');
	foreach $account (@accounts_to_remove) {
	    &B_userdel($account);
	}
    }

}

sub RemoveUnnecessaryGroups {

    # This function removes unncessary groups, as dictated by AccountSecurity.removegroups (Y/N)
    # and AccountSecurity.removegroups_list (groups to remove, comma-separated)
    if (&getGlobalConfig('AccountSecurity','removegroups') eq "Y") {
       my @groups_to_remove = split /\s+/,&getGlobalConfig('AccountSecurity','removegroups_list');
       foreach $group (@groups_to_remove) {
           &B_groupdel($group);
       }
    }
}

1;
