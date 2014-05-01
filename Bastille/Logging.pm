# Copyright (C) 1999, 2000 Jay Beale
# Copyright (C) 2006 Hewlett Packard Development Company, L.P.
# Licensed under the GNU General Public License, version 2

package Bastille::Logging;
use lib "/usr/lib";

use Bastille::API;
use Bastille::API::ServiceAdmin;
use Bastille::API::FileContent;
use Bastille::API::AccountPermission;

#######################################################################
##                               Logging                             ##
#######################################################################

#&ConfigureAutomatedLogWatcher
&ConfigureAdditionalLogging;
&AddProcessAccounting;           # capveg 12/99
#&AddSecurityChecks;
&LAuS;

####&ConfigureAutomatedLogWatcher;
####
#### Anyone want to do this?
####


sub ConfigureAdditionalLogging {

    if (&getGlobalConfig("Logging","morelogging") eq "Y") {
	&B_log("ACTION","# sub ConfigureAdditionalLogging\n");

	# BUG: setting up remote logging should be a separate function, 
	#      such that we can configure it even when we aren't adding
	#      logs to the system.
	my $logging_host=&getGlobalConfig("Logging","remotelog_host");

	# Add two more logging files to RedHat's default scheme and log 
	# lots of data to TTY 7 and 8
	 

        # We add additional logging files:
        #/var/log/kernel       --    kernel messages
        #/var/log/syslog       --    messages of severity \"warning\" and 
	#                            \"error\" 
	#/var/log/loginlog     --    all logins...

	#
        # Also configure the 7th and 8th TTYs for more logging.     

	my $var_log_syslog_lines= <<END_SYSLOG;
# Log warning and errors to the new file /var/log/syslog
*.warn;*.err\t/var/log/syslog

END_SYSLOG

        my $var_log_kernel_lines= <<END_KERNEL;
# Log all kernel messages to the new file /var/log/kernel
kern.*\t/var/log/kernel

END_KERNEL

    my $var_log_loginlog_lines = <<END_LOGINLOG;
# Log all logins to /var/log/loginlog
auth.*;user.*;daemon.none\t/var/log/loginlog

END_LOGINLOG

    my $tty_log_lines= <<END_TTY_LOG;
# Log additional data to the Alt-F7 and Alt-F8 screens (Pseudo TTY 7 and 8)

*.info;mail.none;authpriv.none\t/dev/tty7
authpriv.*\t/dev/tty7
*.warn;*.err\t/dev/tty7
kern.*\t/dev/tty7
mail.*\t/dev/tty8

END_TTY_LOG

	my $syslogconf = &getGlobal('FILE','syslog.conf');
	&B_append_line($syslogconf,"ADDITIONS","############ BASTILLE ADDITIONS BELOW : ################# \n");
	
	&B_append_line($syslogconf,'\/var\/log\/syslog',$var_log_syslog_lines);
	&B_append_line($syslogconf,'\/var\/log\/kernel',$var_log_kernel_lines);
	&B_append_line($syslogconf,'\/var\/log\/loginlog',$var_log_loginlog_lines);
	&B_append_line($syslogconf,'\/dev\/tty7',$tty_log_lines);
	&B_append_line($syslogconf,'\/dev\/tty12',"*.*\t/dev/tty12\n");

	if ($logging_host) {
	    &B_append_line($syslogconf,"\\\@$logging_host","*.warn;*.err\t\@$logging_host\nauthpriv.*;auth.*\t\@$logging_host\n");
	}

	&B_append_line($syslogconf,"BASTILLE ADDITIONS CONCLUDED","########## BASTILLE ADDITIONS CONCLUDED : ###############\n");

	&B_create_file("/var/log/syslog");
	&B_create_file("/var/log/kernel");
	&B_create_file("/var/log/loginlog");

	#
	# Configure log rotation for the new log files:
	#

	my $rotation_lines = <<END_NEW_ROT;
   
/var/log/kernel {
    postrotate
	/usr/bin/killall -HUP syslogd
    endscript
}
   
/var/log/syslog {
    postrotate
	/usr/bin/killall -HUP syslogd
    endscript
}

/var/log/loginlog {
    postrotate
	/usr/bin/killall -HUP syslogd
    endscript
}
END_NEW_ROT


        &B_append_line("/etc/logrotate.d/syslog",'\bloginlog\b',$rotation_lines);
    
   }
}


####AddProcessAccouting;
####
#### Turn on BSD style process accounting
####
#### Idea and Methodology contributed by "capveg@cs.umd.edu"
####

sub AddProcessAccounting { 

   &B_log("ACTION","# sub AddProcessAccounting\n");

   if ( (&getGlobalConfig("Logging","pacct") eq "Y") and (&getGlobal('BIN','accton')) ){

       if ( 0 and (&GetDistro !~ "^DB") and (&GetDistro !~ "^SE") ) {

       # Turn on accounting via the accton command

       &B_append_line(&getGlobal('DIR', "rcd") . "/rc.local","pacct","# Process accounting activated by Bastille \n" . &getGlobal('BIN',"accton") . " " . &getGlobal('DIR', "log") . "/pacct\n");

       &B_create_file(&getGlobal('DIR', "log") . "/pacct");
       &B_chmod (0600,&getGlobal('DIR', "log") . "/pacct");

       #
       # Set the log rotation for process accounting
       #
       my $pacct_rotate_lines = <<END_PACCT_ROT;

# Added by Bastille Linux
# default to rotation schedule set in /etc/logrotate.conf
END_PACCT_ROT

       $pacct_rotate_lines .= &getGlobal('DIR', "log") . "/pacct {\n";
       $pacct_rotate_lines .= "      postrotate\n";
       $pacct_rotate_lines .= &getGlobal('BIN',"accton") . "$GLOBAL_LOG/pacct\n";
       $pacct_rotate_lines .= "      endscript\n}";

       &B_create_file("/etc/logrotate.d/pacct");
       &B_append_line("/etc/logrotate.d/pacct","Bastille",$pacct_rotate_lines);

       } elsif (&GetDistro =~ "^DB") {
		      &B_log("ERROR","# Process Accounting is started automatically in Debian\nwhen the 'acct' package is installed and Bastille cannot (yet) enable it automatically.\n");
		      # TODO (jfs)
		      # Warning: on Debian the accounting is started automatically 
		      # when the 'acct' package is installed. An can be enabled/disabled
		      # in the /etc/init.d/acct script START_ACCT variable (0 or 1)

      }
      elsif (&GetDistro =~ "^SE") {
	      &B_chkconfig_on('acct');
      }
       
      }                               
}

#
#
#cd /etc
# awk '/^ftpd/ && !/-L/ { $NF = $NF " -L" }
#        /^ftpd/ && !/-l/ { $NF = $NF " -l" }
# { print }' inetd.conf > inetd.conf.tmp
# cp inetd.conf.tmp inetd.conf
# rm -f inetd.conf.tmp

sub LAuS {

    # This subroutine activates LAuS, the Linux Auditing System 
    # contributed by IBM.

    if ( (&GetDistro =~ /^HP-UX/) or (&GetDistro =~ /^OSX/) ) {
	return 0;
    }

    if (&getGlobalConfig("Logging","laus") eq "Y") {

	unless ( -e &getGlobal('FILE','initd_audit') ) {
	   &B_log('ERROR',"Logging.LAuS is activated, but LAuS does not appear to be installed - the /etc/init.d/ file is missing.\nPlease install the LAuS rpm and re-run bastille -b");
	   return;
	}
	my $AuditConfFile = &getGlobal('FILE','sysconfig_audit');
	my $etc_sysconfig_audit_lines = <<END_AUDIT_LINES;
# Bastille-enabled LAuS
AUDIT_ALLOW_SUSPEND=1
AUDIT_ATTACH_ALL=0
AUDIT_MAX_MESSAGES=1024
AUDIT_PARANOIA=0

END_AUDIT_LINES

        # Create the audit configuration file if it doesn't exist.
        &B_create_file($AuditConfFile);

	# Add the required lines
	&B_append_line ($AuditConfFile, '^\#\s+Bastille-enabled', $etc_sysconfig_audit_lines);

	# Activate LaUS via the /etc/init.d/audit script
	&B_chkconfig_on("audit");
    }
}

1;
