# Copyright (C) 2005 Jay Beale
# Copyright (C) 2005 Charlie Long, Delphi Research
# Licensed under the GNU General Public License, version 2


#######################################################################
##                          lpr/lpd and cups 
#######################################################################

use Bastille::API;
use Bastille::API::ServiceAdmin;
use Bastille::API::HPSpecific;

#To see if the lp service is turned off

sub test_printing {
    if (&GetDistro =~ "^HP-UX") {
	my $lpStat = &B_is_service_off("lp");

	my $xprintserver = &B_get_rc("XPRINTSERVERS");
	if ( !$xprintserver || $xprintserver eq '""') {
	    $xprintserver = SECURE_CANT_CHANGE();
	} else {
	    $xprintserver = NOTSECURE_CAN_CHANGE();
	}

	my $pdStat = &B_is_service_off("pd");
	
	return &B_combine_service_results($xprintserver, $pdStat, $lpStat);
	
    } else {
	return NOTEST(); # No test was ever written for Linux
    }
};
$GLOBAL_TEST{'Printing'}{'printing'} = \&test_printing;


#To see if the cupsd service is turned off
sub test_printing_cups {
    return &B_is_service_off("cups");
};
$GLOBAL_TEST{'Printing'}{'printing_cups'} =\&test_printing_cups;

#To see if the cups-lpd service is off

sub test_cups_lpd{
    return &B_is_service_off("cups-lpd");
};
$GLOBAL_TEST{'Printing'}{'printing_cups_lpd_legacy'} = \&test_cups_lpd;

1;
