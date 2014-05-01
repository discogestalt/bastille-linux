# Copyright (C) 1999 - 2005 Jay Beale
# Licensed under the GNU General Public License, version 2

#######################################################################
##                 Test for Disabled User Space Tools                ##
#######################################################################

use Bastille::API;

$GLOBAL_TEST{'DisableUserTools'}{'compiler'} =
    sub {

	# If gcc is executable, ask the question.
        my $gcc = &getGlobal('FILE','gcc');	
	if ( -e $gcc ) {
	    if (&B_check_permissions($gcc,0700)) {
		return NOTSECURE_CAN_CHANGE();
	    }
	}
	
	# If g++ is executable, ask the question.
	my $g_plus_plus = &getGlobal('FILE','g++');
	if ( -e $g_plus_plus ) {
	    if (&B_check_permissions($g_plus_plus,0700)) {
		return NOTSECURE_CAN_CHANGE();
	    }
	}

	# Otherwise, skip.
	return SECURE_CANT_CHANGE();
	
    };

1;



