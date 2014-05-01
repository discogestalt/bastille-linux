# Copyright (C) 1999, 2000 Jay Beale
# Licensed under the GNU General Public License, version 2

package Bastille::ConfigureMiscPAM;
use lib "/usr/lib";

use Bastille::API;
use Bastille::API::FileContent;

# To DO:
#
# 1. Expand LimitRemoteRootLogins
#


#######################################################################
##    Misc. Pluggable Authentication Modules (PAM) Configuration     ##
#######################################################################

&ModifyLimitsconf;

# TO DO: Expand this for non-redhat systems
#&LimitRemoteRootLogins;

&LimitConsoleLogins;



sub ModifyLimitsconf {

    # Change /etc/security/limits.conf to prevent many types of DoS attacks.

    if (&getGlobalConfig("ConfigureMiscPAM","limitsconf") eq "Y") {

       &B_log("ACTION","# sub ModifyLimitsconf\n");

       unless (&GetDistro =~ /^OSX/) {
	   my $file=&getGlobal('FILE', "limits.conf");

	   &B_append_line ($file,'^[^\#]*hard\s*core',"# prevent core dumps\n*\thard\tcore\t0\n\n");
	   &B_append_line ($file,'^[^\#]*soft\s*nproc',"#limit user processes per user to 150\n*\tsoft\tnproc\t100\n");
	   &B_append_line ($file,'^[^\#]*hard\s*nproc',"*\thard\tnproc\t150\n\n");
	   
# 4/5/2003 JJB
# Removed this line for now -- this causes us too much trouble now, as disk
# space gets extremely cheap.
#
#          &B_append_line ($file,'^[^\#]*hard\s*fsize',"# limit size of any one of users' files to 100mb\n*\thard\tfsize\t100000\n\n");
       }
       else {
	   my $file=&getGlobal('FILE','hostconfig');
	   &B_append_line ($file,'^COREDUMPS\=\-',"COREDUMPS=-NO-\n");
	   &B_replace_line ($file,'^COREDUMPS\=\-YES\-',"COREDUMPS=-NO-\n");
       }
   }
}

#sub LimitRemoteRootLogins {

   #&B_log("ACTION","# sub LimitRemoteRootLogins\n");

# Limit root to logging in only from console, closing up brute force 
# remote attacks against root's password

### RedHat6.0 - based systems already limit this -- we mostly want to make
### sure that this hasn't changed.

# Further, note that we don't have to add the second admin account to 
# /etc/securetty, since securetty does a UID lookup on its listings and
# on the current account and compares...

#}

sub LimitConsoleLogins {

    # Limit console logins to a small set of prenamed accounts

    if ( ( &getGlobalConfig("ConfigureMiscPAM","consolelogin") eq "Y") and (&getGlobalConfig("ConfigureMiscPAM","consolelogin_accounts") )) {

	&B_log("ACTION","# sub LimitConsoleLogins\n");

        # Optionally, limit console logins to root and the administrator.

	my $console_accts = &getGlobalConfig("ConfigureMiscPAM","consolelogin_accounts");

	my $file=&getGlobal('FILE', "pam_access.conf");

	&B_append_line($file,'^\s*[^#].*:\s*ALL\s+EXCEPT',"-:ALL EXCEPT $console_accts:LOCAL\n");

	# Make sure the appropriate login services respect pam_access.conf
	# by making sure their PAM config files reference pam_access.so
	my $pamFile;
	foreach $pamFile ('login','xdm','gdm','kde') {
	    # 'login' is used by the getty apps (virtual consoles, serial)
	    # the others are X logins (standard, GNOME, KDE)
	    my $pamFQfilename = &getGlobal('DIR', 'pamd') . '/' . $pamFile;
	    if ( -e $pamFQfilename ) {
		&B_append_line( $pamFQfilename,'^\s*[^#]*\s*account\s{1,}required\s{1,}/lib/security/pam_access.so\s*$', "account    required     /lib/security/pam_access.so\n");
	    }
	}
    }
	    
}



1;

