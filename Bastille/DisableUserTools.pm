# Copyright (C) 1999-2005 Jay Beale
# Licensed under the GNU General Public License, version 2

package Bastille::DisableUserTools;
use lib "/usr/lib";

use Bastille::API;
use Bastille::API::AccountPermission;

#######################################################################
##                      Disabling of User Space Tools                ##
#######################################################################

&DisableCompiler;    # Optional!


### What other tools should be deactivated?


sub DisableCompiler {

    if (&getGlobalConfig("DisableUserTools","compiler") eq "Y") {
	&B_log("ACTION","# sub DisableCompiler\n");

	&B_chmod(0700,"/usr/bin/gcc");
	&B_chmod(0700,"/usr/bin/g++");      

	# BUG: We really should be deactivating a lot more than just gcc.
    }
    
}

1;

