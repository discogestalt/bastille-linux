# Copyright (C) 1999, 2000 Jay Beale
# Copyright (C) 2001,2002 Hewlett Packard Development Company, L.P.
# Licensed under the GNU General Public License, version 2

package Bastille::Sendmail;
use lib "/usr/lib";

use Bastille::API;

use Bastille::API::HPSpecific;
use Bastille::API::FileContent;
use Bastille::API::ServiceAdmin;



#######################################################################
##                               Sendmail                            ##
#######################################################################

# It is very important to note that each of these subroutines represent
# an OPTIONAL configuration mode.  Different options work for different
# types of machines.  A web server may only need to process outgoing
# mail to other systems and internal only mail, say, to process
# error messages going out via email.  A corporate mail server, on the
# other hand, has other needs.

&ResistUsernameRecon;
&RunSendmailViaCron;
&DeactivateDaemonMode;


sub DeactivateDaemonMode {

    if (&getGlobalConfig("Sendmail","sendmaildaemon") eq "Y") {
	&B_log("ACTION","# sub DeactiveDaemonMode\n");
	unless ( &GetDistro =~ "^HP-UX") {
	    if(&getGlobalConfig("Sendmail","sendmailcron") ne "Y"){
		&B_chkconfig_off("sendmail");
	    }
	} else {
            $sendmailconfig = &getGlobal('FILE',"sysconfig_sendmail");
            my $chrc = &getGlobal('BIN','ch_rc'); #Have to turn it on first, or it will error
            &B_Backtick("$chrc -p -a SENDMAIL_SERVER=1 $sendmailconfig");
            &B_Backtick(&getGlobal("FILE","sysconfig_sendmail") . " start");
            &B_ch_rc("sendmail");
        }
    }
}

sub RunSendmailViaCron {

    if ( &getGlobalConfig("Sendmail","sendmailcron") eq "Y" ) {
	&B_log("ACTION","# RunSendmailViaCron\n");
	if(&GetDistro =~ "^HP-UX"){
            my $sendmail=&getGlobal('BIN','sendmail');
            my $pattern="$sendmail -q";
            my $cronjob="0,15,30,45 * * * * $sendmail -q";
            &B_Schedule($pattern,$cronjob);
	}
	else{
	    &B_replace_line(&getGlobal('FILE',"sysconfig_sendmail"),"DAEMON=yes","DAEMON=no\n");
	    &B_replace_line(&getGlobal('FILE',"sysconfig_sendmail"),"QUEUE=","QUEUE=15m\n");
	}

    }

}

sub ResistUsernameRecon {

    if (&getGlobalConfig("Sendmail","vrfyexpn") eq "Y") {
	# Disable sendmail's vrfy and expn commands
	&B_log("ACTION","# sub ResistUsernameRecon\n");

	&B_append_line(&getGlobal('FILE', "sendmail.cf"),'^O PrivacyOptions=goaway$',"O PrivacyOptions=goaway\n");

	if ( &GetDistro =~ "^HP-UX") {
            # if sendmail is running and not disabled by Bastille, restart it
            # to re-read the config file.
            if ( (!&B_is_service_off('sendmail')) &&
	          &getGlobalConfig("Sendmail","sendmaildaemon") eq "N") {
		&B_System (&getGlobal('FILE', "sysconfig_sendmail") . ' stop',
                           &getGlobal('FILE', "sysconfig_sendmail") . ' start');
		&B_System (&getGlobal('FILE', "sysconfig_sendmail") . ' start',
                           &getGlobal('FILE', "sysconfig_sendmail") . ' stop');
	    }
	}
    }
}


1;

