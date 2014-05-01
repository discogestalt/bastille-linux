# Licensed under the GNU General Public License, version 2

# This is to be pulled into the API to define tests

use Bastille::API;
use Bastille::API::FileContent;

$GLOBAL_TEST{'BootSecurity'}{'protectlilo'} = 
    sub {
        # Floppy disk will not be checked.
        my $liloConfFile = &getGlobal('FILE', 'lilo.conf');

        if ( -e $liloConfFile ) {
            # Check if the LILO configuration file contains a password line.
            # REVISIT: Do we need to check timeout, delay, restricted?
            if (! &B_match_line($liloConfFile, '^\s*password=')) {
                return NOTSECURE_CAN_CHANGE();
            }
            # Check that root is the owner of the configuration file.
            my $uid = (stat($liloConfFile))[4];
            my $gid = (stat($liloConfFile))[5];
            if ($uid != 0 || $gid != 0) {
                return NOTSECURE_CAN_CHANGE();
            }
            # Check the permissions on the configuration file (0600).
            if (! &B_check_permissions($liloConfFile, 0600)) {
                return NOTSECURE_CAN_CHANGE();
            }
        }
        # REVISIT: Is it possible to check if lilo has been run after the 
        # configuration file was modified?
        return SECURE_CANT_CHANGE();
    };

$GLOBAL_TEST{'BootSecurity'}{'lilodelay'} = 
    sub {
        # Floppy disk will not be checked.
        my $liloConfFile = &getGlobal('FILE', 'lilo.conf');

        if ( -e $liloConfFile ) {
            # Check if the LILO configuration file contains a delay line
	    # with a time shorter than 10 deciseconds.
	    # Also accept a timeout line if it's shorter than that.
	    if (open LILO,$liloConfFile) {

		foreach $line (<LILO>) {
		    if ($line =~ /^\s*(delay|timeout)\s*=\s*(\d+)/) {
			if ($2 <= 10) {
			    return SECURE_CANT_CHANGE();
			}
		    }
		}
	    }

	    return NOTSECURE_CAN_CHANGE();

        }
        # REVISIT: Is it possible to check if lilo has been run after the 
        # configuration file was modified?
        return SECURE_CANT_CHANGE();
    };

$GLOBAL_TEST{'BootSecurity'}{'lilosub_drive'} = 
    sub {
	my $liloConfFile = &getGlobal('FILE', 'lilo.conf');
	
        unless ( -e $liloConfFile ) {
	    return SECURE_CANT_CHANGE();
	}
	else {
	    return NOTSECURE_CAN_CHANGE();
	}
    };
$GLOBAL_TEST{'BootSecurity'}{'lilosub_floppy'} = 
    sub {
	my $liloConfFile = &getGlobal('FILE', 'lilo.conf');
	
        unless ( -e $liloConfFile ) {
	    return SECURE_CANT_CHANGE();
	}
	else {
	    return NOTSECURE_CAN_CHANGE();
	}
    };
$GLOBAL_TEST{'BootSecurity'}{'lilosub_writefloppy'} = 
    sub {
	my $liloConfFile = &getGlobal('FILE', 'lilo.conf');
	
        unless ( -e $liloConfFile ) {
	    return SECURE_CANT_CHANGE();
	}
	else {
	    return NOTSECURE_CAN_CHANGE();
	}
    };

$GLOBAL_TEST{'BootSecurity'}{'passsum'} = 
    sub { 
	my $inittab=&getGlobal('FILE','inittab');

        # Look for a line like this in inittab:
        #
        # ~~:S:respawn:/sbin/sulogin

	unless (&B_match_line($inittab,':/sbin/sulogin\s*$')) {
	    return NOTSECURE_CAN_CHANGE();
	}
	return SECURE_CANT_CHANGE();
    };
$GLOBAL_TEST{'BootSecurity'}{'secureinittab'} = 
    sub { 
	my $inittab=&getGlobal('FILE','inittab');

        # Look for a line like this in inittab:
        #
        # :ctrlaltdel:

	if (&B_match_line($inittab,'^[^\#]*:ctrlaltdel:')) {
	    return NOTSECURE_CAN_CHANGE();
	}
	return SECURE_CANT_CHANGE();
    };

$GLOBAL_TEST{'BootSecurity'}{'protectgrub'} = 
    sub { 
        my $grubConfFile = &getGlobal('FILE', 'grub.conf');

        if (-e $grubConfFile ) {
            # Check if the GRUB configuration file contains a password line.
            # REVISIT: Perhaps the line should be checked for more than just 
            # the word "password".
            if (! &B_match_line($grubConfFile, '^\s*password')) {
                return NOTSECURE_CAN_CHANGE();
            }
            # Check that root is the owner of the configuration file.
            my $uid = (stat($grubConfFile))[4];
            my $gid = (stat($grubConfFile))[5];
            if ($uid != 0 || $gid != 0) {
                return NOTSECURE_CAN_CHANGE();
            }
            # Check the permissions on the configuration file (0600).
            if (! &B_check_permissions($grubConfFile, 0600)) {
                return NOTSECURE_CAN_CHANGE();
            }
        }
        return SECURE_CANT_CHANGE();
    };



#$GLOBAL_TEST{'BootSecurity'}{'secureinittab'} = 
#    sub {
#        # Does anything need to be done here?  Disabling ctrl-alt-del was not 
#        # recommended in the FKL guide, and password protecting single-user 
#        # mode was dependent on passsum.
#        return SECURE_CANT_CHANGE();
#    };



$GLOBAL_TEST{'BootSecurity'}{'disable_autologin'} = 
    sub {

	# If we're on Linux, look at gdm.conf and kdmrc.
        my $distro = &GetDistro;
	unless ( ($distro =~ /^OSX/) or ($distro =~ /^HP/) ) {

	    # KDM uses AutoLoginEnable lines in kdmrc
	    my $kdmrc = &getGlobal('FILE','kdmrc');
	    if ( &B_match_line($kdmrc,'^\s*AutoLoginEnable\s*=(yes|YES)\b') ) {
                return NOTSECURE_CAN_CHANGE();
	    }	    
	    # GDM autologin mechanisms
	    my $gdmconf = &getGlobal('FILE','gdm.conf');
	    if ( &B_match_line($gdmconf,'^TimedLoginEnable\s*=(yes|YES)\b') ) {
		return NOTSECURE_CAN_CHANGE();
	    }
	    elsif ( &B_match_line($gdmconf,'^AutomaticLoginEnable\s*=(yes|YES)\b') ) {
		return NOTSECURE_CAN_CHANGE();
	    }

	}

	# Mandrake and SuSE each have their own sysconfig-related mechanisms too.

	if (&GetDistro =~ /^MN/) {
	    my $file = '/etc/sysconfig/autologin';
            if ( -e $file ) {
                if (&B_match_line($file, '^\s*AUTOLOGIN\s*=\s*(yes|YES)')) {
                    return NOTSECURE_CAN_CHANGE();
                }
            }
	}
	elsif (&GetDistro =~ /^SE/) {
# TODO:
#    Write this for SuSE by making sure that the following file has lines
#    either deleted or set to appropriate values:
#
#    DISPLAYMANAGER_AUTOLOGIN =  (delete)
#    DISPLAYMANAGER_PASSWORD_LESS_LOGIN = no  (replace & add  OR  delete)
#
#	    &B_replace_line('/etc/sysconfig/displaymanager','^\s*
	}
	elsif (&GetDistro =~ /^OSX/) {
	    my $file = '';
	    if ( -e '/Library/Preferences/com.apple.loginwindow.plist') {
		$file = '/Library/Preferences/com.apple.loginwindow.plist';
	    }
	    elsif ( -e '/Library/com.apple.loginwindow.plist') {
		$file = '/Library/com.apple.loginwindow.plist';
	    }
            if ($file != '') {
                if (&B_match_line($file, '\s*<key>autoLoginUser</key>\n\s*<string>[^>]+</string>')) {
                    return NOTSECURE_CAN_CHANGE();
                }
            }
        }
        return SECURE_CANT_CHANGE();
    };



1;
