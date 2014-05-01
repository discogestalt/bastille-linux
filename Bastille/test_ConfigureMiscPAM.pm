# Copyright (C) 2005 Jay Beale
# Copyright (C) 2006 Hewlett Packard Development Company, L.P.
# Licensed under the GNU General Public License, version 2

use Bastille::API::FileContent;

#######################################################################
##                          test_ConfigureMiscPAM
#######################################################################

$GLOBAL_TEST{'ConfigureMiscPAM'}{'limitsconf'} =
    sub {

	my $limitsconf=&getGlobal('FILE', "limits.conf");

	unless ( -e $limitsconf) {
	    return NOTSECURE_CAN_CHANGE();
	}

	# Look for core dumps deactivated
	unless (&B_match_line($limitsconf,'^\s*\*hard\s+core\s+0\s*$')) {
	    return NOTSECURE_CAN_CHANGE();
	}

	# Look for a max processes per user of 500 to avoid fork bombs.
	unless (&B_match_line($limitsconf,'^\s*\*hard\s+nproc\s+(\d+)\s*$') and $2 < 500 ) {
	    return NOTSECURE_CAN_CHANGE();
	}

	return SECURE_CANT_CHANGE();
    };

$GLOBAL_TEST{'ConfigureMiscPAM'}{'consolelogin'} =
    sub {

        my $accessconf=&getGlobal('FILE', "pam_access.conf");

	if (&B_match_line($accessconf,'^\s*[^#].*:\s*ALL\s+EXCEPT')) {
	    return SECURE_CANT_CHANGE();
	}

	return NOTSECURE_CAN_CHANGE();
    };


1;
