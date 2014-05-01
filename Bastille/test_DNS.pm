# Copyright (C) 2002-2003, 2006 Hewlett Packard Development Company, L.P.
# Copyright (C) 2005 Jay Beale
# Copyright (C) 2005 Charlie Long, Delphi Research
# Licensed under the GNU General Public License, version 2

use Bastille::API;
use Bastille::API::ServiceAdmin;
use Bastille::API::FileContent;
use Bastille::API::HPSpecific;

    sub test_namedoff{
	# see if the named service is scheduled to run
	my $isServiceOff = &B_is_service_off('named');
	if(defined $isServiceOff && $isServiceOff == 0) {
	    # if it is running ask the question
	    return NOTSECURE_CAN_CHANGE();
	}
	else {
	    # otherwise don't ask the question
	    return SECURE_CANT_CHANGE();
	}
    };
$GLOBAL_TEST{'DNS'}{'namedoff'} = \&test_namedoff;

    sub test_chrootbind{

	my $distro = &GetDistro;
        my $ps = &getGlobal("BIN","ps");
        my $dnsjail='';


	# BIND doesn't need to be chrooted if it's missing.
	unless ( -e &getGlobal('FILE','named') ) {
	    return NOT_INSTALLED();
	}

	if ($distro =~ /^RHEL/ or $distro =~ /^RHFC/ ) {
	    # Chrooting BIND is easy on RHEL -- just set the
	    # ROOTDIR variable in /etc/sysconfig/named.
	    if ( &B_match_line(&getGlobal('FILE','sysconfig_named'),'^ROOTDIR\s*=\s*[^\s]+\s*$') ) {
		return SECURE_CANT_CHANGE();
	    }
	}
	elsif ($distro =~ /^SESLES/ or $distro =~ /^SE9/ ) {
	    # Chrooting BIND is easy on SLES and later SUSE versions -- just set the NAMED_RUN_CHROOTED to "yes" in
	    # /etc/sysconfig/named
	    if ( &B_match_line(&getGlobal('FILE','sysconfig_named'),'^\s*NAMED_RUN_CHROOTED=\s*yes\s*$') ) {
		return SECURE_CANT_CHANGE();
	    }
	}
	elsif ($distro =~ /^MN/) {
	    # As of Mandrake 10.1, there is init script support via the ROOTDIR variable, but they don't
	    # yet build their own chroot.  So we can't check this way.
	} elsif ($distro =~ /HP-UX/) {
            $dnsjail = &getGlobal("BDIR","jail");
            if (&B_get_rc("NAMED_ARGS") !~ /-t $dnsjail/){ #rc *must* be set
                return NOTSECURE_CAN_CHANGE();
            }
        }
	# Check to see if named is activated -- if it isn't, just skip the question.
	if (&B_is_service_off('named')) {
            &B_log("DEBUG","named service is set to \'off\', so secure.");
	    return SECURE_CANT_CHANGE();
	}

	#
	# If named is activated and the above items didn't find it configured for chroot, look for a chrooted BIND process.
	#

        #Get the named pid;
        my @process = B_list_full_processes("named");

        foreach my $process (@process) {
	    my $pid;
	    # Check its root.
	    my (@fields) = split(/\s+/, $process);
	    $pid = $fields[3];

	    if (defined $pid) {
		if ($distro =~ /HP-UX/) {
                    if ($process =~ /-t $dnsjail/) { # -t is the chroot option
                        return SECURE_CANT_CHANGE()
                    }
                } else {
                    # Parse the /proc/<pid>/root link.
                    my @procfile = split(/\s+/, `ls -ld /proc/$pid/root`);
                    if ($procfile[9] eq '->') {# Time field
                        unless (($procfile[10]) ne '/' and ($procfile[10] ne "")) {
                            # We're not chrooted.
                            return NOTSECURE_CAN_CHANGE();
                        }
                    }
                }
            }
	}
	return NOTSECURE_CAN_CHANGE();
    };
    $GLOBAL_TEST{'DNS'}{'chrootbind'} = \&test_chrootbind;
1;
