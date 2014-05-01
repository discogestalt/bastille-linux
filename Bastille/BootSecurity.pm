# Copyright (C) 1999, 2000 Jay Beale
# Copyright (C) 2001 Hewlett Packard Development Company, L.P.
# Licensed under the GNU General Public License, version 2

package Bastille::BootSecurity;
use lib "/usr/lib";

use Bastille::API;
use Bastille::API::HPSpecific;
use Bastille::API::FileContent;
use Bastille::API::AccountPermission;

# Expected tough bug area:  ProtectLILO!!!! (Especially floppy work)


#######################################################################
##                Protecting LILO and single user mode               ##
#######################################################################

&ProtectLILO;
&ProtectGRUB;
&SecureInittab;
&DisableAutologin;

sub ProtectLILO {

    ## ProtectLILO can password the lilo prompt so that specifying special
    ## options to the kernel at the LILO prompt requires a password.  It can
    ## also set the delay to zero so that the user/attacker has no time to
    ## type anything at the LILO prompt.
    ##
    ## Both of these protect lots of different attacks which boot the kernel
    ## under "special parameters."  One such very common practice is to boot
    ## Red Hat Linux in single user mode _without_a_password_ by typing
    ## linux single at the LILO prompt.

    my $set_lilo_delay_zero=0;
    my $lilo_password="";
    my @lilo_config_files;


    #
    # Determine what changes to make...
    # 

    # Should we set the lilo delay to zero?
    if (&getGlobalConfig("BootSecurity","lilodelay") eq "Y") {
	$set_lilo_delay_zero=1;
    }

    # Should we password protect the lilo prompt?
    if ((&getGlobalConfig("BootSecurity","protectlilo") eq "Y") and(&getGlobalConfig("BootSecurity","protectlilo_password"))) { 
	$lilo_password=&getGlobalConfig("BootSecurity","protectlilo_password");
    }



    #
    # Which media (hard disk/floppy) should we modify lilo on?
    #

    # If they want to modify the hard disk's lilo file, make sure it exists.
    if (&getGlobalConfig("BootSecurity","lilosub_drive") eq "Y") {
	if ( -e &getGlobal('FILE', "lilo.conf")  ) {
	    push @lilo_config_files,&getGlobal('FILE', "lilo.conf");
	}
	else {
	    &B_log("ERROR","Couldn't modify hard drive's lilo.conf -- couldn't");
	    &B_log("ERROR","find " . &getGlobal('FILE', "lilo.conf") . "\n");
	}
    }

    # If they want to modify the floppy disk's lilo file, mount the floppy,
    # make sure we can write to it...

    if ((&getGlobalConfig("BootSecurity","lilosub_floppy") eq "Y") and (&getGlobalConfig("BootSecurity","lilosub_writefloppy") =~ /fd(\d)/ )) {
	my $dev_number=$1;
	my $floppy_dev="/dev/fd$dev_number";
	my $floppy_file = &getGlobal('DIR', "floppy") . &getGlobal('FILE', "lilo.conf");

	# Check to see that the drive isn't already mounted...
	if ( open MTAB,&getGlobal('FILE', "mtab") ) {
	    while (my $line = <MTAB>) {
		if ($line =~ /\/dev\/fd$dev_number/ ) {
		    my $command=&getGlobal('BIN',"umount");
                    `$command $floppy_dev`;
		}
	    }
	    close MTAB;
	}

	# Now mount the drive and add it to the list of drives to lilo
	my $command=&getGlobal('BIN',"mount");
        my $floppydir=&getGlobal('DIR', "floppy");
        `$command -t ext2 $floppy_dev $floppydir`;
	if ( -e $floppy_file ) {
	    push @lilo_config_files,$floppy_file;
	}
    }

    #
    # Make the modifications to the file now...
    #

    if ( ($set_lilo_delay_zero or $lilo_password) and (@lilo_config_files)){
	
	&B_log("ACTION","# sub ProtectLILO\n");
	
        my $file;
	
	foreach $file (@lilo_config_files) {

	    #
	    # Make the actual insertions
	    #

	    # Set the lilo delay to zero?
	    if ( $set_lilo_delay_zero ) {

		# lilo.conf man page is inaccurate on "delay" option -- if you 
		# set it to 0, it waits indefinitely; 
		# instead set to 1 (tenth of a second)

		&B_hash_comment_line($file,'^\s*timeout=');
		&B_hash_comment_line($file,'^\s*prompt');
		&B_prepend_line($file,'^\s*delay',"delay=1\n");
	    }

	    # Password protect the lilo prompt
	    if ( $lilo_password ) {

		my $line="restricted\n" . "password=" . $lilo_password . "\n";
		&B_prepend_line($file,'^\s*restricted',$line);
	    }

	    #
	    # Put good permissions on the file, especially since the lilo
	    # password needs to be hidden from view by users.
	    #
                  
	    &B_chmod(0600,"$file");
	    &B_chown(0,"$file");

	    unless ($GLOBAL_LOGONLY) {

		# Now, re-run lilo to make the configuration take effect 

		    if (&getGlobal('BIN',"lilo")) {
			if ($file =~ /^&getGlobal('DIR', "floppy")/) {
                            my $command=&getGlobal('BIN',"lilo");
                            my $arg=&getGlobal('DIR', "floppy");
                            `$command -r $arg`;
			}
			else {
			    my $command=&getGlobal('BIN',"lilo");
                            `$command`;
			}
			&B_log("ACTION","# Re-running lilo");
		    }
		    else {
			&B_log("ERROR","Couldn't re-run lilo because we couldn't find lilo!.\nPlease re-run lilo by typing:\n\tlilo   (for hard drive booting)\n\tlilo -r " . &getGlobal('DIR', "floppy") . "   (for floppy drive booting)\n");
		    }
	    }
	}
    }
}


sub ProtectGRUB {

    if ( (&GetDistro =~ /^OSX/) or (&GetDistro =~ /^HP-UX/) ) {
	return;
    }

    ## ProtectGRUB can password the GRUB prompt so that specifying special
    ## options to the kernel at the GRUB prompt requires a password.  

    ## Both of these protect lots of different attacks which boot the kernel
    ## under "special parameters."  One such very common practice is to boot
    ## Red Hat Linux in single user mode _without_a_password_.

    my $grub_password="";
    my @grub_config_files;

    # Should we password protect the grub prompt?
    if ((&getGlobalConfig("BootSecurity","protectgrub") eq "Y") and(&getGlobalConfig("BootSecurity","protectgrub_password"))) { 
	$grub_password=&getGlobalConfig("BootSecurity","protectgrub_password");
    }
    else {
	return;
    }


    #
    # Which media (hard disk/floppy) should we modify grub on?
    #
    
    # If they want to modify the hard disk's grub file, make sure it exists.
    if ( -e &getGlobal('FILE', "grub.conf")  ) {
	push @grub_config_files,&getGlobal('FILE', "grub.conf");
    }
    else {
	&B_log("ERROR","Couldn't modify hard drive's grub.conf -- couldn't\n");
	&B_log("ERROR","find " . &getGlobal('FILE', "grub.conf") . "\n");
	return;
    }

    #
    # Make the modifications to the file(s) now...
    #

    if ( ($grub_password) and (@grub_config_files)){
	
	&B_log("ACTION","# sub ProtectGRUB\n");
	
        my $file;
	
	foreach $file (@grub_config_files) {

	    #
	    # Make the actual insertions
	    #

	    # Password protect the grub prompt
	    # Don't use md5, as this introduces a dependency.
	    # Consider using md5 later.
	    my $line = "password $grub_password\n";
	    my $rtn = &B_prepend_line($file,'password',$line);
	    unless ($rtn) {
		&B_log("ERROR","Couldn't prepend $line to $file\n");
	    }

	    #
	    # Put good permissions on the file, especially since the grub
	    # password needs to be hidden from view by users.
	    #
                  
	    &B_chmod(0600,"$file");
	    &B_chown(0,"$file");

	}
    }
}


sub SecureInittab {

    if ((&getGlobalConfig("BootSecurity","secureinittab") eq "Y") or (&getGlobalConfig("BootSecurity","passsum") eq "Y") ) {
	&B_log("ACTION","# sub SecureInittab\n");

	# Do we want to disable Ctrl-Alt-Del rebooting of the system via
	# the line in /etc/inittab? 
	
	if (&getGlobalConfig("BootSecurity","secureinittab") eq "Y") {
	    unless ( -e '/bin/systemd' ) {
		&B_hash_comment_line(&getGlobal('FILE', "inittab"),":ctrlaltdel:");
	    }
	    else {
                &B_log("ACTION","# Trying systemd variant of secureinittab\n");
                # On systemd systems (Fedora 15 and later), clear the link between ctrl-alt-delete and the reboot service.
                $ctrl_alt_del = &getGlobal('FILE','ctrl-alt-del.target');
                $reboot = &getGlobal('FILE','reboot.target');
                
                if ( -e $ctrl_alt_delete and -e $reboot) {
                    &B_System("rm $ctrl_alt_del","ln -s $reboot $ctrl_alt_del");
                    &B_symlink("/dev/null",$ctrl_alt_del);
                }
                else {
                    &B_log("ERROR","secureinittab could not find one of the two systemd target files required to protect against ctrl-alt-delete rebooting.\n");
                }
                    
	    }
	}
	
	# Require a password to boot in single user mode (runlevel S/1)
	# by adding a line for /sbin/sulogin to runlevel S in /etc/inittab.
	
	# Password protect single user mode
	
	if (&getGlobalConfig("BootSecurity","passsum") eq "Y")  {

	    unless (&GetDistro =~ /^OSX/) {
		unless ( -e '/bin/systemd' ) {		    
		    if (&getGlobal('BIN',"sulogin")) {
			my $file=&getGlobal('FILE', "inittab");
			my $line_to_insert_after=":initdefault:";
			my $line_to_insert="\n~~:S:wait:" . &getGlobal('BIN',"sulogin") . "\n";
			my $pattern = "S:wait:.*sulogin";
			&B_insert_line($file,$pattern,$line_to_insert,$line_to_insert_after);
		    }
                    else {
                        &B_Log("ERROR","Could not protect single user mode because Bastille could not find sulogin.\n");
                    }

		}
		else {
		    # Fedora 15 and 16 use systemd, so we need to change the path to sulogin another way.
                    if (&getGlobal('BIN',"sulogin")) {
                        my $sulogin = &getGlobal('BIN',"sulogin");
			&B_replace_line(&getGlobal('FILE', "systemd_rescue.service"),'ExecStart',"ExecStart=$sulogin\n");
                    }
                    else {
                        &B_Log("ERROR","Could not protect single user mode because Bastille could not find sulogin.\n");
                    }
                
		}
	    }
	    else {
		# On OSX (and probably on *BSD), we modify the /etc/ttys file, replacing the console's "secure" word
		# with "insecure" -- this stops init from immediately giving a rootshell.
		&B_replace_pattern(&getGlobal('FILE','ttys'),'^console\s+.*\s+on\s+secure\s+','\bsecure\b','insecure');
	    }
	}
    }

}

sub DisableAutologin {

    # Another msec overlap requirement.
    # Disable Mandrake's autologin feature -- bad physical security risk.
    #
    # While this may feel distro-specific, it isn't really.  It's just that no
    # other distribution goes so far out of their way to be user friendly that
    # they offer to disable password-login.
    #

    # OK, this is ironic.  The above comment was written before OS X was
    # released.  OS X comes with autologin turned on by default as well...

    if (&getGlobalConfig("BootSecurity","disable_autologin") eq "Y") {
	&B_log("ACTION","# sub DisableAutologin\n");

	unless (&GetDistro =~ /^OSX/) {

	    # Mandrake used their own autologin system for a while.
	    my $file = "/etc/sysconfig/autologin";
	    if ( -e $file ) {
		&B_append_line($file,'^\s*AUTOLOGIN',"AUTOLOGIN=no\n");
		&B_replace_line($file,'^\s*AUTOLOGIN',"AUTOLOGIN=no\n");
	    }
	    
	    # KDM autologin
	    my $kdmrc = &getGlobal('FILE','kdmrc');
	    &B_replace_line($kdmrc,'^\s*AutoLoginEnable\s*=',"AutoLoginEnable=false");
	    
	    # GDM autologin mechanisms
	    my $gdmconf = &getGlobal('FILE','gdm.conf');
	    &B_replace_line($gdmconf,'^\s*TimedLoginEnable\s*=',"TimedLoginEnable=false\n");
	    &B_replace_line($gdmconf,'^\s*AutomaticLoginEnable\s*=',"AutomaticLoginEnable=false\n");

	}
	else {
	    # Reverse-engineering has shown that it is the 
	    # /Library/Preferences/com.apple.loginwindow.plist file that 
	    # stores this setting.

	    # Additional: O'Reilly's Mac OS X book cites this file location
	    # as /Library/com.apple.loginwindow.plist 
	    # JJB: Have e-mail'd book's author -- act on his reply.

	    # We've got to remove the line <key>autoLoginUser</key> and the
	    # <string>SOMEUSER</string> line that follows it.

	    my $file;
	    if ( -e '/Library/Preferences/com.apple.loginwindow.plist') {
		$file = '/Library/Preferences/com.apple.loginwindow.plist';
	    }
	    elsif ( -e '/Library/com.apple.loginwindow.plist') {
		$file = '/Library/com.apple.loginwindow.plist';
	    }
	    else {
		return;
	    }

 	    # This code must handle the case where this file is in binary instead of XML format.
 	    # Use plutil -convert xml1 <FILE> first?
 	    #
    	    # TODO: Generalize this...
 
 	    &B_System("/usr/bin/plutil -convert xml1 $file","");
	    
	    &B_chunk_replace($file,'\s*<key>autoLoginUser</key>\n\s*<string>[^>]+</string>','');

	}

    }
}

1;




