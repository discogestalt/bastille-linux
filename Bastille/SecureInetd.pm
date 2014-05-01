# Copyright (C) 1999-2005 Jay Beale
# Copyright (C) 2001, 2002,2006 Hewlett Packard Development Company L.P.
# Licensed under the GNU General Public License, version 2

# $Source: /cvsroot-fuse/bastille-linux/dev/working_tree/Bastille/Bastille/SecureInetd.pm,v $
# Modified by: $Author: jay $
# $Date: 2012/02/15 20:36:47 $
# $Revision: 1.68 $

package Bastille::SecureInetd;

use lib "/usr/lib";

use Bastille::API;
use Bastille::API::HPSpecific;
use Bastille::API::ServiceAdmin;
use Bastille::API::FileContent;
use Bastille::API::AccountPermission;

#######################################################################
##                    inetd / TCP Wrappers Configuration             ##
#######################################################################


#&ModifyInetdconf;
&deactivateInetdServices;

&SetWrappersDefaultDeny;
&CreateBanners;
&ServiceAudit;
&LogInetd;
&FtpLogging;

################################################################################
# &deactivateInetdServices;
#
#  This subroutine is used to deactivate HP-UX services.  If run on a Linux
#  system this subroutine directs execution to the subroutines defined to
#  deactivate Linux inetd/xinetd services.
#
#  For HP-UX the questions labeled below and there corresponding services
#  can be disabled depending on the answers given for each question. the format
#  is as follows:
#
#question_label:
#   services disabled as they appear in inetd.conf
#
#deactivate_tftp:
#   tftp        dgram  udp wait   root /usr/lbin/tftpd    tftpd
#deactivate_bootps:
#   bootps      dgram  udp wait   root /usr/lbin/bootpd   bootpd
#deactivate_finger:
#   finger      stream tcp nowait bin  /usr/lbin/fingerd  fingerd
#deactivate_uucp:
#   uucp        stream tcp nowait root /usr/sbin/uucpd    uucpd
#deactivate_ntalk:
#   ntalk        dgram  udp wait   root /usr/lbin/ntalkd   ntalkd
#deactivate_ident:
#   ident        stream tcp wait   bin  /usr/lbin/identd   identd
#deactivate_time:
#   time         stream tcp nowait root internal
#   time         dgram  udp nowait root internal
#deactivate_builtin:
#   daytime      stream tcp nowait root internal
#   daytime      dgram  udp nowait root internal
#   echo         stream tcp nowait root internal
#   echo         dgram  udp nowait root internal
#   discard      stream tcp nowait root internal
#   discard      dgram  udp nowait root internal
#   chargen      stream tcp nowait root internal
#   chargen      dgram  udp nowait root internal
#deactivate_ktools:
#   kshell stream tcp nowait root /usr/lbin/remshd remshd -K
#   klogin stream tcp nowait root /usr/lbin/rlogind rlogind -K
#deactivate_dttools:
#   dtspc stream tcp nowait root /usr/dt/bin/dtspcd /usr/dt/bin/dtspcd
#   rpc xti tcp swait root /usr/dt/bin/rpc.ttdbserver 100083 1 \
#            /usr/dt/bin/rpc.ttdbserver
#   rpc dgram udp wait root /usr/dt/bin/rpc.cmsd 100068 2-5 rpc.cmsd
#deactivate_recserv:
#   recserv stream tcp nowait root /usr/lbin/recserv recserv  -display :0
#deactivate_swat:
#   swat    stream tcp   nowait.400 root /opt/samba/bin/swat swat
#deactivate_printer:
#   printer     stream tcp nowait root /usr/sbin/rlpdaemon  rlpdaemon -i
#
################################################################################
sub deactivateInetdServices {
    if(&GetDistro =~ "^HP-UX"){




	my @inetdServices = ('telnet','ftp','rtools','tftp','bootp',
			     'finger','uucp','ntalk','ident','time',
			     'builtin','ktools','dttools','recserv',    # , 'cmsd', 'ttdbserver' is in the dttools
			     'swat','printer','rquotad',
                             'registrar', 'instl_boots',
                             'rstatd', 'rusersd', 'rwalld', 'sprayd'
                             );   #'kcms_server'
	&InetdRestart;
	foreach my $service (@inetdServices) {
	    if ( &getGlobalConfig("SecureInetd","deactivate_" . $service) eq "Y" ) {
		&B_log("DEBUG","# sub deactivate_$service\n");
		&B_deactivate_inetd_service($service);
	    }
	}
	&InetdRestart;
    }
    else {
	&DeactivateTelnet;
	&DeactivateFTP;
    }
}



sub SetWrappersDefaultDeny {

    # If they've got TCP Wrappers and want this, set a default deny
    # policy in hosts.allow.  Intent here is to get the safe_finger
    # stuff in again.

    if (&getGlobalConfig("SecureInetd","tcpd_default_deny") eq "Y") {

	&B_log("DEBUG","# sub SetWrappersDefaultDeny\n");

	# add a line to the end of /etc/hosts.allow
	my $line = '# Bastille: default deny
# no safe_finger for in.fingerd (prevent loops)
in.fingerd : ALL : DENY
# Allow ssh -- the administrator should consider tightening this down
sshd : ALL : ALLOW
# but everything else is denied & reported with safe_finger
ALL : ALL : spawn (/usr/sbin/safe_finger -l @%h | /bin/mail -s "Port Denial noted %d-%h" root) & : DENY
';
	if (! -e &getGlobal('FILE', "hosts.allow") ) {
		# make a default hosts.allow file
		&B_place("/hosts.allow",&getGlobal('FILE', "hosts.allow"));
		&B_chmod(0644,&getGlobal('FILE', "hosts.allow"));
	}
	&B_append_line(&getGlobal('FILE', "hosts.allow"),'^\s*ALL\s*:\s*ALL\b',$line);
    }
}


sub DeactivateTelnet {
    if ( &getGlobalConfig("SecureInetd","deactivate_telnet") eq "Y" ) {
	&B_log("DEBUG","# sub deactivate_telnet\n");
	if (( -e &getGlobal('DIR', "xinetd.d") . "/telnet") && (&getGlobal('DIR', "xinetd.d") ne "")) {
	    # If telnet is run via xinetd, then add/modify the disable line
	    &B_replace_line(&getGlobal('DIR', "xinetd.d") . '/telnet','disable\s*=',"\tdisable\t\t= yes\n");
	    &B_insert_line(&getGlobal('DIR', "xinetd.d") . '/telnet','disable\s*=',"\tdisable\t\t= yes\n",'server\s*=');

	    # If telnet is run via xinetd, then delete the file
	    # &B_delete_file(&getGlobal('DIR', "xinetd.d") . "/telnet");
	}
	elsif ( -e &getGlobal('FILE', "inetd.conf") ) {
		&B_hash_comment_line( &getGlobal('FILE', "inetd.conf"),'^\s*telnet');
	}
    }
}

sub DeactivateFTP {
    if ( &getGlobalConfig("SecureInetd","deactivate_ftp") eq "Y" ) {
	&B_log("DEBUG","# sub deactivate_ftp\n");
	if (( -e &getGlobal('DIR', "xinetd.d") . "/ftp") && (&getGlobal('DIR', "xinetd.d") ne "" )) {
	    # If ftp is run via xinetd as 'ftp', then add/modify the disable line
	    &B_replace_line(&getGlobal('DIR', "xinetd.d") . '/ftp','disable\s*=',"disable\t\t=\tyes\n");
	    &B_insert_line(&getGlobal('DIR', "xinetd.d") . '/ftp','disable\s*=',"disable\t\t=\tyes\n",'server\s*=');

	    # If ftp is run via xinetd, then delete the file
	    # &B_delete_file(&getGlobal('DIR', "xinetd.d") . "/ftp");
	}
	elsif (( -e &getGlobal('DIR', "xinetd.d") . "/wu-ftpd") && (&getGlobal('DIR', "xinetd.d") ne "" )) {
	    # If ftp is run via xinetd as 'wu-ftpd', then add/modify the disable line
	    &B_replace_line(&getGlobal('DIR', "xinetd.d") . '/wu-ftpd','disable\s*=',"disable\t\t=\tyes\n");
	    &B_insert_line(&getGlobal('DIR', "xinetd.d") . '/wu-ftpd','disable\s*=',"disable\t\t=\tyes\n",'server\s*=');

	    # If ftp is run via xinetd as 'wu-ftpd', then delete the file
	    # &B_delete_file(&getGlobal('DIR', "xinetd.d") . "/wu-ftpd");
	}
	elsif ( -e &getGlobal('FILE', "inetd.conf") ) {
		&B_hash_comment_line( &getGlobal('FILE', "inetd.conf"),'^\s*ftp');
	}

	# If vsftpd is run standalone, we'd better deactivate it.
	if ( -e &getGlobal('FILE',"chkconfig_vsftpd") ) {
	    &B_chkconfig_off("vsftpd");
	}
    }
}

sub ModifyInetdconf {

# uncomment pop3,imap,tftpd and in.bootpd ; the latter two are used
# specifically as "booby traps" to better log scans
# further, comment the (default non-tcp wrapped) linuxconf

   if (&getGlobalConfig("SecureInetd","modifyinetd") eq "Y") {

       &B_log("DEBUG","# sub ModifyInetdconf\n");

       &B_hash_uncomment_line (&getGlobal('FILE', "inetd.conf"),"^pop-3");
       &B_hash_uncomment_line (&getGlobal('FILE', "inetd.conf"),"^imap");
       &B_hash_uncomment_line (&getGlobal('FILE', "inetd.conf"),"^tftp");
       &B_hash_uncomment_line (&getGlobal('FILE', "inetd.conf"),"^bootpd");
       &B_hash_comment_line (&getGlobal('FILE', "inetd.conf"),"linuxconf");

       # Default ssh: allow all IP's.
       my $ssh_allowed_hosts="ALL";

       if (&getGlobalConfig("SecureInetd","limit_ssh") eq "Y") {

	   # If the range isn't written, just set it to ALL
	   unless (&getGlobalConfig("SecureInetd","limit_ssh_range")) {
	       $ssh_allowed_hosts="ALL";
	   }
	   else {

	       # Add localhost to the ssh range if it's not there...
	       $ssh_allowed_hosts=&getGlobalConfig("SecureInetd","limit_ssh_range");
	       unless ($ssh_allowed_hosts =~ /127\.0\.0\.1/) {
		   $ssh_allowed_hosts="$ssh_allowed_hosts 127.0.0.1";
	       }
	   }
      }

       # Replace entire hosts.allow file

       my $hosts_allow_file = <<END_HOSTS_ALLOW;
#
# hosts.allow   This file describes the names of the hosts which are
#               allowed to use the local INET services, as decided
#               by the '/usr/sbin/tcpd' server.
#

# Bastille modifications made below...

# Let everyone ssh here.
sshd: $ssh_allowed_hosts : ALLOW

# TELNET: Please be advised that telnet is a rather dangerous protocol.
#         All usernames/passwords used in remote sessions via telnet can
#         be seen by many other computers between them.  In fact, most
#         ethernet configurations allow every other computer on your
#         local area network to see the entire session, passwords and all.
#         Further, there are utilities (like Hunt) in wide use that allow
#         one of these hosts to take over your telnet session.
#
#         There is a much safer facility that allows for remote logins,
#         which is installed on your box, called ssh.  To use it, type:
#
#                 ssh username\@targethost
#
#         Please don't uncomment the line below...

#in.telnetd: ALL : banners /etc/banners : ALLOW

# FTP:    Please be advised that ftp is a rather dangerous protocol.
#         All usernames/passwords used in remote sessions via ftp can
#         be seen by many other computers between them.  In fact, most
#         ethernet configurations allow every other computer on your
#         local area network to see the entire session, passwords and all.
#
#         There is a much safer facility that allows for remote copies,
#         which is installed on your box, called scp.  To use it, read a
#         bit by typing
#
#                       man scp
#
#         In essence, it works much like "cp," but with remote sources/targets.
#         For example,  scp jay\@zark.umuc.edu:/etc/hosts /etc/hosts
#
#
#         Please don't uncomment the line below...

#in.ftpd: ALL : banners /etc/banners : ALLOW

# POP3/:   You can allow pop3/imapd, but it is highly recommended that you
# IMAPD:   look into a secure version that does not transmit names/passwords
#          in cleartext.  Please consider doing this before you uncomment the
#          lines below:

#ipop3d: ALL : ALLOW
#imapd:  ALL : ALLOW


# Set a default deny stance with back finger "booby trap" (Venema's term)
# Allow finger to prevent deadly finger wars, whereby another booby trapped
# box answers our finger with its own, spawning another from us, ad infinitum

in.fingerd: ALL : ALLOW

ALL : ALL : spawn (/usr/sbin/safe_finger -l @%h | /bin/mail -s "Port Denial noted %d-%h" root) & : DENY

END_HOSTS_ALLOW

       &B_blank_file ("/etc/hosts.allow");
       &B_append_line ("/etc/hosts.allow","Bastille",$hosts_allow_file);


   }
}

sub CreateBanners {
    my $tcpwrappers=0;
    if (&getGlobalConfig("SecureInetd","banners") eq "Y") {
#	my $distro = &GetDistro; # This information is already available, so not needed
	&B_log("DEBUG","# sub CreateBanners\n");
	if ( ((&GetDistro =~ /^RH/) or (&GetDistro =~ /^MN/))
             and ( -e (&getGlobal('FILE', "tcpd")) )
             and ( -e (&getGlobal('FILE', "banners_makefile"))) ) {

	    # Create banners for telnet/ftp...

	    my $banners_makefile =  &getGlobal('FILE', "banners_makefile");
	    &B_create_dir ("/etc/banners");
	    &B_chmod (0744,"/etc/banners");

	    &B_cp($banners_makefile,"/etc/banners/Makefile");

	    &B_create_file("/etc/banners/prototype");
	    $tcpwrappers=1;
	}


        my $owner = &getGlobalConfig("SecureInetd", "owner");
	my $banner_line = <<ENDBANNER;

***************************************************************************
                            NOTICE TO USERS


This computer system is the private property of $owner, whether
individual, corporate or government.  It is for authorized use only.
Users (authorized or unauthorized) have no explicit or implicit
expectation of privacy.

Any or all uses of this system and all files on this system may be
intercepted, monitored, recorded, copied, audited, inspected, and
disclosed to your employer, to authorized site, government, and law
enforcement personnel, as well as authorized officials of government
agencies, both domestic and foreign.

By using this system, the user consents to such interception, monitoring,
recording, copying, auditing, inspection, and disclosure at the
discretion of such personnel or officials.  Unauthorized or improper use
of this system may result in civil and criminal penalties and
administrative or disciplinary action, as appropriate. By continuing to use
this system you indicate your awareness of and consent to these terms
and conditions of use. LOG OFF IMMEDIATELY if you do not agree to the
conditions stated in this warning.

****************************************************************************

ENDBANNER

        if ($tcpwrappers == 1) {
	    &B_append_line("/etc/banners/prototype","NOTICE",$banner_line);
	}

	unless (&GetDistro =~ /^OSX/) {
	    # There's no /etc/issue or equivalent on OS X

	    unless ( -e &getGlobal('FILE', "issue") ) {
		&B_create_file(&getGlobal('FILE', "issue"));
	    }

	    &B_blank_file(&getGlobal('FILE', "issue"),'NOTICE');
	    &B_append_line(&getGlobal('FILE', "issue"),"NOTICE",$banner_line);
	}
	else {
	    # This code shamelessly copied from the HP code below, with one
	    # minor change.
	    # Consider a logic-change to use the code for HP-UX and OSX.
	    unless ( -e &getGlobal('FILE', "motd") ) {
		&B_create_file(&getGlobal('FILE', "motd"));
	    }
	    &B_blank_file(&getGlobal('FILE', "motd"),'NOTICE');
	    &B_append_line(&getGlobal('FILE', "motd"),"NOTICE",$banner_line);
	}

	if(&GetDistro =~ "^HP-UX"){

	    unless ( -e &getGlobal('FILE', "motd") ) {
		&B_create_file(&getGlobal('FILE', "motd"));
	    }
	    &B_blank_file(&getGlobal('FILE', "motd"),'a$b');
	    &B_append_line(&getGlobal('FILE', "motd"),"NOTICE",$banner_line);

	    #  Loop throught inetd.conf and add the Banners file location to common services.
	    if(open INETD, "< " . &getGlobal('FILE',"inetd.conf")){
		while(my $line = <INETD>){
		    chomp $line;
		    if(($line =~ /\s+rlogind\s*$|\s+rlogind\s*\-.*$/) && ($line !~ /-B/)){
			&B_replace_line(&getGlobal('FILE',"inetd.conf"),"$line","$line -B " . &getGlobal('FILE',"issue") . "\n");

		    }
		    elsif(($line =~ /\s+telnetd\s*|\s+telnetd\s*\-.*$/) && ($line !~ /-b/)){
			&B_replace_line(&getGlobal('FILE',"inetd.conf"),"$line","$line -b " . &getGlobal('FILE',"issue") . "\n");

		    }
		}
		close INETD;
	    }
	    else{
		&B_log("ERROR","Bastille could not open " . &getGlobal('FILE',"inetd.conf") ."\n");
	    }
	}
    }
}

sub ServiceAudit {
    if (&getGlobalConfig("SecureInetd","inetd_general") eq "Y") {
	&B_log("DEBUG","# sub ServiceAudit\n");
	my $inetd_text =
	   "Disable all of the unneeded services in /etc/inetd.conf.  You can\n" .
           "do this by putting a \"#\" at the beginning of the line \n" .
	   "corresponding to each unnecessary service and running \"inetd -c\".\n\n".

           "You can also configure inetd to allow or deny connections based on\n" .
           "ip address.  HP-UX has ip-based access control built into the inetd\n" .
           "server.  See inetd.sec(4) for details.  You may also want to consider\n" .
           "tcpwrappers, which you can find at http://software.hp.com.  The\n" .
           "functionality is nearly equivalent, with tcpwrappers being slightly\n" .
           "more flexible and cross-platform, but requiring edits to inetd.conf\n" .
           "to make sure that the access controls are used.  Remember that,\n" .
           "in general, ip addresses are spoofable and therefore this should\n" .
           "only be used as an additional layer of security.\n\n";

	&B_TODO("\n---------------------------------\nInetd Audit:\n" .
		"---------------------------------\n" .
		$inetd_text,"SecureInetd.inetd_general");
    }
}


sub LogInetd {
    if (&getGlobalConfig("SecureInetd","log_inetd") eq "Y") {
	&B_log("DEBUG","# sub LogInetd\n");
        &B_set_rc("INETD_ARGS",'"\"-l\""');
    }

}

# CIS implement logging for ftp daemon
sub FtpLogging {
    if (&getGlobalConfig("SecureInetd","ftp_logging") eq "Y") {
	&B_log("DEBUG","# sub FtpLogging\n");
        my $inetdconf = &getGlobal("FILE", "inetd.conf");
        &B_replace_lines($inetdconf,  [[ '(ftp.+ftpd\s+)(ftpd)(.*)',  '$1ftpd -l$3' ]]);
    }
}

sub InetdRestart {

    if ( &GetDistro =~ "^HP-UX" ){ #send SIGHUP to inetd to re-read inetd.conf

	my $ps = &getGlobal('BIN',"ps");
	my @processes = `$ps -elf`;
	my $inetd =  &getGlobal('BIN',"inetd");

	if("@processes" =~ "$inetd") {
           # inetd is running
	   &B_System( $inetd . " -c", $inetd . " -c");
	}
    }
}

1;







