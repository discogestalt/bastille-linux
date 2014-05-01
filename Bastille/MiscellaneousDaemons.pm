# Copyright (C) 1999, 2000, 2003 Jay Beale
# Copyright (C) 2001, 2002, 2008 Hewlett Packard Development Company, L.P.
# Licensed under the GNU General Public License, version 2

package Bastille::MiscellaneousDaemons;
use lib "/usr/lib";

use Bastille::API;
use Bastille::API::ServiceAdmin;
use Bastille::API::FileContent;
use Bastille::API::HPSpecific;


use strict;
use English;

@ENV="";
$ENV{PATH}="";
$ENV{CDPATH}=".";
$ENV{BASH_ENV}="";



#######################################################################
##                          Miscellaneous Daemons                    ##
#######################################################################

# Deactivate ?standard? services chosen at install, at admin's option.
# Explain why they might want to turn this stuff off.  Remember, most
# newbies will take the, "I don't want to break anything -- turn it all on!"
# approach.  Let's deactivate apmd, portmap, pcmcia, nfs, netfs, smb,
# dhcpd, amd, gpm, innd, linuxconf, if possible.

&DeactivateAPMD;
&DeactivateRemoteFS;
&DeactivatePCMCIA;
&DeactivateDHCP;
&DeactivateGPM;
&DeactivateINND;
&DeactivateAllChkconfig;
&DeactivatePTY;
&DeactivatePwgrd;
&DeactivateRbootd;
&DeactivateKudzu;
&DeactivateHPOJ;
&DeactivateISDN;
&DeactivateBluetooth;


&RestrictRendezvous;
&RestrictAutoDiskMount;
&RestrictNTPD;

# Restricting access for the dtlogin, diagmond, and syslog daemons to the local machine.
&RestrictXaccess;
&RestrictDiagnostics;
&RestrictSyslog;

#Added for CIS on HP-UX
&other_boot_serv;
&nfs_core;


# If we are running SuSE7.x, we also write to rc.config so that changes are unaltered
# upon reboot of the system. Otherwise, rc.config would overwrite these changes.

#
# Disable non-standard services, which may have been badly chosen at install:
#
# Possibly disable arpwatch, autofs, bootparamd, gated, mars-nwe, mcserv,
# postgresql, routed, rstatd, rusersd, rwalld, rwhod, snmpd, squid, xntpd,
# ypbind, yppasswdd, ypserv

#
#### WHICH ONES SHOULD WE DISABLE?
#

&DeactivateRoutingDaemons;
&DeactivateNIS;
&DeactivateNISPlus;
&DeactivateSmbclient;
&DeactivateSmbServer;
&DeactivateBind;
&NobodySecureRPC;
&ConfigureSSH;
&DeactivateSNMPD;


sub DeactivateAPMD {

    if (&getGlobalConfig("MiscellaneousDaemons","apmd") eq "Y") {
        &B_log("DEBUG","# sub DeactivateAPMD\n");

	# Deactivate both apmd and its newer ACPI counterpart acpid.
        &B_chkconfig_off ("apmd");
	&B_chkconfig_off ("acpid");
        if (&GetDistro =~ "^SESLES10" and -e &getGlobal('FILE',"initd_acpid")) {
            my $acpi_line = "ACPI_MODULES=\"NONE\"";
            $acpi_line .= "\n";
            &B_replace_line(&getGlobal('FILE',"initd_acpid"),'^ACPI_MODULES=',$acpi_line);
        }
        elsif (&GetDistro =~ "^SE" and -e &getGlobal('FILE',"rc.config")) {
            &B_replace_line(&getGlobal('FILE',"rc.config"),'^START_APMD=','START_APMD="no"\n');
        }
}
}

sub DeactivateRemoteFS(;$){
    my $NFSCoreNotOn = $_[0];

    if (&getGlobalConfig("MiscellaneousDaemons","remotefs") eq "Y") { #Linux
	&B_log("DEBUG","# sub DeactivateRemoteFS\n");

        # For now, we break NFS/SAMBA.  Does someone want to make a "secure?" NFS
        # configuration?  Should we allow samba? Can we use samba without the
        # automounter? Are they safe when we don't know if the admin has a firewall?
	# question: should we remove the symbolic links for netfs, which
	# mounts external net-based drives?

	# Turn off the portmapper -- it's only used by NIS and NFS on Linux.
        &B_chkconfig_off ("portmap");
	# Turn off NFS server daemon
        &B_chkconfig_off ("nfs");
	# Deactivate server-and-client-side NFSv4 idmapd on Linux
        &B_chkconfig_off ("rpcidmapd");
	# Deactivate client-side NFSv4 script
	&B_chkconfig_off ("rpcgssd");
	# Deactivate client-side NFS script
	&B_chkconfig_off ("nfslock");
        &B_chkconfig_off ("smb");
	# Deactivate the remote-filesystem (client-side) mounting script
	&B_chkconfig_off ("netfs");
	# Disable the NFS automounter
        &B_chkconfig_off ("amd");

	# Deactivate the network automounting without deactivating local CD-ROM mounting
	# in recent Linux distributions (RHFC4).
	if ( -e '/etc/auto.master') {
	    &B_hash_comment_line('/etc/auto.master','^\\s*\/net\\s+\/etc\/auto\.net');
	}

	if (&GetDistro =~ "^SE7" and -e &getGlobal('FILE',"rc.config")) {
	    &B_replace_line(&getGlobal('FILE',"rc.config"),'^START_PORTMAP','START_PORTMAP="no"\n');
	    &B_replace_line(&getGlobal('FILE',"rc.config"),'^NFS_SERVER','NFS_SERVER="no"\n');
	    &B_replace_line(&getGlobal('FILE',"rc.config"),'^START_SMB','START_SMB="no"\n');
	}

	if ( defined(&getGlobal('FILE', "inetd.conf") ) ) {
	   my $inetd_conf = &getGlobal('FILE', "inetd.conf");
	   if ( -e $inetd_conf ) {
	      &B_hash_comment_line($inetd_conf,"nfs");
	   }
	}

    }

    if (((&getGlobalConfig("MiscellaneousDaemons","nfs_server")) eq "Y")  or
        (defined($NFSCoreNotOn))){
	&B_log("DEBUG","# sub DeactivateRemoteFS\n");

	if (&GetDistro =~ "^HP-UX") {
            # Kill off process and change permanant start-up behavior
            &B_ch_rc ("nfs.server");
	}
	elsif (&GetDistro =~ '^OSX') {
	    # NFS is deactivated on OSX simply by making sure there are no exported
	    # filesystems.
	    &B_hash_comment_line('/etc/exports','^\s*[^\#]+');
	}

    }


    if (((&getGlobalConfig("MiscellaneousDaemons","nfs_client")) eq "Y")  or
        (defined($NFSCoreNotOn))){
	&B_log("DEBUG","# sub DeactivateRemoteFS\n");

	if ( &GetDistro =~ "^HP-UX") {
            # Kill off process and change permanent start-up behavior
            &B_ch_rc ("nfs.client");
		if (&GetDistro =~ "^HP-UX11.(.*)" and $1>=31) {
		    &B_ch_rc ("autofs");
		}

	}
	elsif (&GetDistro =~ '^OSX') {
	    # You can't deactivate NFS client daemon (nfsiod) separately without
	    # deactivating the network, unless you're willing to modify the NFS
	    # script.  Right!

	    &B_hash_comment_line(&getGlobal('FILE','NFS'),'^\s*nfsiod\b');

	    # We also deactivate the automounter here, which is done via /etc/hostconfig.

	    # JJB: Replace the line below with an abstraction, after talking with
	    #      Keith Buck.
	    &B_replace_line(&getGlobal('FILE','hostconfig'),'^AUTOMOUNT\=\-YES\-',"AUTOMOUNT=-NO-\n");
	}
    }


}


sub DeactivatePCMCIA { #Linux

    # If this isn't a notebook, strongly recommend disabling PCMCIA.
    if (&getGlobalConfig("MiscellaneousDaemons","pcmcia") eq "Y") {
    &B_log("DEBUG","# sub DeactivatePCMCI\n");

        &B_chkconfig_off ("pcmcia");
    if (&GetDistro !~ "^SESLES10") {
        if (&GetDistro =~ "^SE" and -e &getGlobal('FILE',"rc.config")) {
	    &B_replace_line(&getGlobal('FILE',"rc.config"),'^START_PCMCIA','START_PCMCIA="no"\n');
        }
   }
}
}

sub DeactivateDHCP { #Linux

    # If this is # If this is not a DHCP server, we deactivate dhcpd.

    if (&getGlobalConfig("MiscellaneousDaemons","dhcpd") eq "Y") {
        &B_log("DEBUG","# sub DeactivateDHCP\n");

        &B_chkconfig_off ("dhcpd");
    if (&GetDistro !~ "^SESLES10") {
        if (&GetDistro =~ "^SE" and -e &getGlobal('FILE',"rc.config")) {
            &B_replace_line(&getGlobal('FILE',"rc.config"),'^IFCONFIG_0="dhcpclient"','IFCONFIG_0=""\n');
        }
    }
}
}

sub DeactivateGPM { #Linux

    if (&getGlobalConfig("MiscellaneousDaemons","gpm") eq "Y") {
        &B_log("DEBUG","# sub DeactivateGPM\n");

        &B_chkconfig_off ("gpm");
    if (&GetDistro !~ "^SESLES10") {
        if (&GetDistro =~ "^SE" and -e &getGlobal('FILE',"rc.config")) {
            &B_replace_line(&getGlobal('FILE',"rc.config"),'^START_GPM="yes"','START_GPM="no"\n');
	    &B_log("DEBUG","# this is where GPM should be edited in rc.config\n");
        }
    }
}
}

sub DeactivateINND { #Linux

    # Deactivate innd unless they really need a new server.

    if (&getGlobalConfig("MiscellaneousDaemons","innd") eq "Y" ) {
	&B_log("DEBUG","# sub DeactivateINND\n");

    if ((&GetDistro =~ "^SESLES10")) {
	&B_chkconfig_off ("inn");
    }
    else {
	&B_chkconfig_off ("innd");
   }
    }
}


sub DeactivateRoutingDaemons { #Linux

    # Disable gated if they're not running a router...  Otherwise, disable
    # either gated or routed.

    &B_log("DEBUG","# sub DeactivateRoutingDaemons\n");

    if (&getGlobalConfig("MiscellaneousDaemons","disable_routed") eq "Y") {
	&B_chkconfig_off ("routed");
    }
    if (&getGlobalConfig("MiscellaneousDaemons","disable_gated") eq "Y") {
	&B_chkconfig_off ("gated");
    }

}

# Verify no legacy '+' entries exist in passwd and group files
# '+' entries in various files used to be markers for systems to insert
# data from NIS maps at a certain point in a system configuration file.
# These entries are no longer required on HP-UX systems, but may
# exist in files that have been imported from other platforms.
# These entries may provide an avenue for attackers to gain privileged access on the system.
# They should be deleted if they exist.

sub RemoveLegacyEntry {
    my $passwd = &getGlobal("FILE","passwd");
    my $group = &getGlobal("FILE", "group");
    my $patterns_and_substitutes = [
        [ '^+:.*$'  => ''  ]
    ];
    &B_replace_lines($passwd, $patterns_and_substitutes);
    &B_replace_lines($group, $patterns_and_substitutes);
}

#
# CIS implementation nis_server nis_client
#        
sub DeactivateNIS(;$){
    my $NFSCoreNotOn = $_[0];

    &B_log("DEBUG","# sub DeactivateNIS\n");

    # NIS Server section
    if ((&getGlobalConfig("MiscellaneousDaemons","nis_server") eq "Y")  or
        (defined($NFSCoreNotOn))){
	&B_log("DEBUG","# deactivating NIS server\n");
	if ( &GetDistro =~ "^HP-UX") {
	    &B_ch_rc ("nis.server");
	}
	else {
	    &B_chkconfig_off ("ypserv");
	    &B_chkconfig_off ("yppasswdd");
	}

    }


    # NIS Client Section
    if ((&getGlobalConfig("MiscellaneousDaemons","nis_client") eq "Y") or
        (defined($NFSCoreNotOn))){
	&B_log("DEBUG","# deactivating NIS client\n");
        
        # remove legacy entries.
        &RemoveLegacyEntry;
        
	if ( &GetDistro =~ "^HP-UX") {
            # NIS_DOMAIN is used both by NIS and NIS+ clients,
            # so we set it to "" when both NIS and NIS+ clients are disabled.
            my $nisplus_will_stop = &getGlobalConfig("MiscellaneousDaemons","nisplus_client") ;
            if ( ! $nisplus_will_stop || $nisplus_will_stop eq  "Y") {
                &B_set_rc('NIS_DOMAIN',"");
            }
	    &B_ch_rc("nis.client");

	    # nsswitch.conf is used by several programs to determine how to resolve
	    # system unknowns.  e.g. the hosts entry of this file is used by nslookup
	    # to resolve network host names.
	    my $nsswitch = &getGlobal('FILE',"nsswitch.conf");

	    # The system defaults may use nis, in this case Bastille will
	    # create a reasonable default that depends on the system files
	    if( ! -f $nsswitch ) {
		&B_create_nsswitch_file("files");
	    }

	    # if an nsswitch.conf file was using nis to resolve unknowns then
	    # changes need to be made to this file in order to ensure that
	    # the new system configuration is acknowledged by the nsswitch.conf file.
	    if( &B_match_line($nsswitch,'.+:\s+.*nis[^p]|.+:\s+.*compat') ) {
                B_replace_lines(
                    $nsswitch,
                    [
                        [ 'nis', ''],
                        [ 'compat', '']
                    ]
                );
	    }
	    my $passwd_file = &getGlobal("FILE","passwd");
	    &B_log('DEBUG','Deleting NIS entries from: ' . $passwd_file);
	    &B_delete_line($passwd_file ,'^\+:.*');

	}
	else {
	    &B_chkconfig_off ("ypbind");
	}

        if (&GetDistro !~ "^SESLES10") {
	    if (&GetDistro =~ "^SE" and -e &getGlobal('FILE',"rc.config")) {
	        &B_replace_line(&getGlobal('FILE',"rc.config"),'^START_YPBIND=','START_YPBIND="no"\n');
            }
	}
    }
}

#CIS-referenced "other boot services"

sub other_boot_serv() {
    if (&getGlobalConfig("MiscellaneousDaemons","other_boot_serv") eq "Y"){
        &B_ch_rc("mrouted");
        &B_ch_rc("rwhod");
        &B_ch_rc("ddfs");
        &B_ch_rc("rarpd");
        &B_ch_rc("rdpd");
        &B_ch_rc("snaplus2");
    }   
}

sub nfs_core() {
    # Turn off entire nfs infrastructure, including the client and server
    # make the yes child skip nfs server and client as it subsumes them.
    
    #Call with true value to override question settings
    #Since killing nfs core assumes killing nfs and nis client and server
    # due to rpc dependencies.
    if (&getGlobalConfig("MiscellaneousDaemons","nfs_core") eq "Y") {
        &B_log("DEBUG","# deactivating NFS Core services (nfs_core) \n");
        DeactivateNIS(1);
        DeactivateRemoteFS(1);
       
        my $version = &GetDistro;
        $version =~ s/HP-UX11.(\d{2})/$1/;
        if ( $version >= 31 ){
            &B_ch_rc("nfs.core"); 
        } else {
	    # workaround to disable nfs.core without rc.config.d file support (HPUX <= 11.23)
	    # delete rc2.d link file, and mark file as volatile in IPD to avoid swverify errors
	    my $rm=&getGlobal('BIN',"rm");
	    my $ln=&getGlobal('BIN',"ln");
	    my $swmodify=&getGlobal('BIN',"swmodify");
            my $coreFile=&getGlobal('FILE',"link_nfs_core");
            my $coreFileActual=&getGlobal('BIN',"nfs.core");
            &B_System("$coreFile stop","$coreFile start");
	    &B_System("$swmodify -x files='$coreFile' -a is_volatile=true  NFS.NFS-CORE",
	              "$swmodify -x files='$coreFile' -a is_volatile=false NFS.NFS-CORE"); 
            &B_System("$rm $coreFile",
		      "$ln -s $coreFileActual $coreFile");
        }
    }
}


#
# End of "other boot services" functions
#

#
# CIS implementation nisplus_server nisplus_client
#
sub DeactivateNISPlus {

    &B_log("DEBUG","# sub DeactivateNISPlus\n");

    # NISPlus Server section
    if (&getGlobalConfig("MiscellaneousDaemons","nisplus_server") eq "Y") {
        &B_log("DEBUG","# deactivating NISPlus server\n");
        if ( &GetDistro =~ "^HP-UX") {
            &B_ch_rc ("nisp.server");
        }
    }

    # NISPlus Client Section
    if (&getGlobalConfig("MiscellaneousDaemons","nisplus_client") eq "Y") {
        &B_log("DEBUG","# deactivating NISPlus client\n");
        if ( &GetDistro =~ "^HP-UX") {
            # NIS_DOMAIN is used both by NIS and NIS+ clients,
            # so we set it to "" when both NIS and NIS+ clients are disabled.
            my $nis_will_stop = &getGlobalConfig("MiscellaneousDaemons","nis_client");
            if ( !$nis_will_stop || $nis_will_stop  eq "Y") {
                &B_set_rc('NIS_DOMAIN',"");
            }
            &B_ch_rc ("nisp.client");

            # nsswitch.conf is used by several programs to determine how to resolve
            # system unknowns.  e.g. the hosts entry of this file is used by nslookup
            # to resolve network host names.
            my $nsswitch = &getGlobal('FILE',"nsswitch.conf");

            # The system may use nisplus, in this case Bastille will
            # create a reasonable default that depends on the system files
            if( ! -f $nsswitch ) {
                &B_create_nsswitch_file("files");
            }

            # if an nsswitch.conf file was using nisplus to resolve unknowns then
            # changes need to be made to this file in order to ensure that
            # the new system configuration is acknowledged by the nsswitch.conf file.
            if( &B_match_line($nsswitch,'.+:\s+.*nisplus') ) {
                &B_replace_lines(
                    $nsswitch,
                    [
                        [ 'nisplus', '' ]
                    ],
                );
            }
        }
    }
}

#
# CIS implementation disable_smbclient
# 
sub DeactivateSmbclient{
     if (&getGlobalConfig("MiscellaneousDaemons","disable_smbclient") eq "Y") {
	&B_log("DEBUG","# sub DeactivateSmbclient\n");
        &B_ch_rc("cifsclient");
     }
}

#
# CIS implementation disable_smbserver
#
sub DeactivateSmbServer {
     if (&getGlobalConfig("MiscellaneousDaemons","disable_smbserver") eq "Y") {
	&B_log("DEBUG","# sub DeactivateSmbServer\n");
        &B_ch_rc("samba");
     }
}

#
# CIS implementation disable_bind
#
sub DeactivateBind {
    if (&getGlobalConfig("MiscellaneousDaemons","disable_bind") eq "Y") {
	&B_log("DEBUG","# sub DeactivateBind\n");
        &B_ch_rc ("named");
     }
}


#
# CIS implementation nobody_secure_rpc
# ---------------------------------------------------
# Disable "nobody" access for secure RPC
#
sub NobodySecureRPC {
    if (&getGlobalConfig("MiscellaneousDaemons","nobody_secure_rpc") eq "Y") {
        &B_log("ACTION","# sub NoDotInRootPath\n");
        my $keyserv_options = &B_get_rc("KEYSERV_OPTIONS");
        my $ch_rc = &getGlobal("bin", "ch_rc");
        &B_System("$ch_rc -a -p KEYSERV_OPTIONS=\"-d $keyserv_options\"", "$ch_rc -a -p KEYSERV_OPTIONS=\"$keyserv_options\"");    
    }
}

#
# CIS implementation configure_ssh
#
#
sub ConfigureSSH {
    if (&getGlobalConfig( 'MiscellaneousDaemons', 'configure_ssh' ) eq "Y") {
        &B_log("DEBUG","# sub ConfigureSSH\n");
        if ( my $sshd_config = &getGlobal('FILE','sshd_config') ) {
             my $pairs = [
                [ '(^#|^)Protocol\s+(.*)\s*$'    =>    'Protocol 2' ],
                [ '(^#|^)X11Forwarding\s+(.*)\s*$'    =>    'X11Forwarding yes' ],
                [ '(^#|^)IgnoreRhosts\s+(.*)\s*$'    =>    'IgnoreRhosts yes' ],
                [ '(^#|^)RhostsAuthentication\s+(.*)\s*$'    =>    'RhostsAuthentication no' ],
                [ '(^#|^)RhostsRSAAuthentication\s+(.*)\s*$'    =>    'RhostsRSAAuthentication no' ],
                [ '(^#|^)PermitRootLogin\s+(.*)\s*$'    =>    'PermitRootLogin no' ],
                [ '(^#|^)PermitEmptyPasswords\s+(.*)\s*$'    =>    'PermitEmptyPasswords no' ],
                [ '(^#|^)Banner\s+(.*)\s*$'    =>    'Banner \/etc\/issue' ]
            ];
            &B_replace_lines($sshd_config,$pairs);
        }
    }
}

#
# CIS implementation snmpd
# Disable SNMP and OpenView Agents, if remote management or monitoring are not needed.
#
sub DeactivateSNMPD {

    # SNMP is rather insecure.  If you need proof, go read the Phrack
    # article or read a bit about the protocol...

    if (&getGlobalConfig("MiscellaneousDaemons","snmpd") eq "Y") {
	&B_log("DEBUG","# sub DeactivateSNMPD\n");
	unless ( &GetDistro =~ "^HP-UX") {
	    &B_chkconfig_off ("snmpd");
	} else {
	    &B_ch_rc ("SnmpHpunix");
	    &B_ch_rc ("SnmpMib2");
	    &B_ch_rc ("SnmpTrpDst");
	    &B_ch_rc ("SnmpMaster");
	# Note the SNMP Peer service was deprecated some time ago

	    #Better alternative to CIS' deletion of random files and filesets
	    # disable snmpd comm by commenting out all community-names and traps
            my $snmpconf=&getGlobal('FILE', 'snmp.conf');
            &B_hash_comment_line( $snmpconf, '^\s*get-community-name:' );
            &B_hash_comment_line( $snmpconf, '^\s*set-community-name:' );
            &B_hash_comment_line( $snmpconf, '^\s*trap-dest:' );

	} # end HP-UX section
    }
}

###
### Should we disable the rest?
###

sub DeactivateAllChkconfig {

    # This routine is a duplicate of msec's functionality -- it turns
    # off all chkconfig-based services with the exception of those in
    # /etc/security/msec/server.4.

    if (&getGlobalConfig("MiscellaneousDaemons","minimize_chkconfig") eq "Y") {
	&B_log("DEBUG","# sub DeactivateAllChkconfig\n");

	open CHKCONFIGS,"/sbin/chkconfig --list |";
	my $line;
	while ($line = <CHKCONFIGS>) {
	    if ($line =~ /^(.*?)\s+0:/) {
		my $service = $1;
		my $chkconfig_this_off = 1;
		my $allowed_service;
		foreach $allowed_service ( "crond","syslog","keytable","network","gpm","xfs","pcmcia","bastille-firewall") {
		    if ($service eq $allowed_service) {
			$chkconfig_this_off=0;
		    }
		}

		if ($chkconfig_this_off) {
		    &B_chkconfig_off($service);
		}
	    }
	}
	close CHKCONFIGS;
    }

}

sub DeactivatePTY {
    if (&getGlobalConfig("MiscellaneousDaemons","disable_ptydaemon") eq "Y") {
	&B_log("DEBUG","# sub DeactivatePTY\n");
	&B_ch_rc ("vt");
	&B_ch_rc ("ptydaemon");
    }
}

sub DeactivatePwgrd {
   if (&getGlobalConfig("MiscellaneousDaemons","disable_pwgrd") eq "Y") {
	&B_log("DEBUG","# sub DeactivatePwgrd\n");
	&B_ch_rc ("pwgr");
    }
}

sub DeactivateRbootd {
   if (&getGlobalConfig("MiscellaneousDaemons","disable_rbootd") eq "Y") {
	&B_log("DEBUG","# sub DeactivatePwgrd\n");
	&B_ch_rc ("rbootd");
    }
}

sub RestrictXaccess {
    if (&getGlobalConfig("MiscellaneousDaemons","xaccess") eq "Y") {
	&B_log("DEBUG","# sub xaccess\n");

	&B_System(&getGlobal('BIN',"dtlogin.rc") . " reset",&getGlobal('BIN',"dtlogin.rc") . " reset");
	&B_create_file (&getGlobal('BFILE', 'Xaccess.bastille'));
	&B_blank_file  (&getGlobal('BFILE', 'Xaccess.bastille'), "Bastille");
	&B_append_line (&getGlobal('BFILE', 'Xaccess.bastille'), "Bastille" ,
			"# This is a blank Xaccess file created by Bastille to prevent \n" .
			"# XDMCP logins.  It is referenced from " . &getGlobal('BFILE', 'Xconfig') . ".\n \n");
	&B_cp(&getGlobal('FILE', 'Xconfig'),&getGlobal('BFILE', 'Xconfig'));
	&B_replace_line(&getGlobal('BFILE', 'Xconfig'), "Dtlogin\.accessFile",
			"Dtlogin\.accessFile:          " .  &getGlobal('BFILE', 'Xaccess.bastille'));
	&B_System(&getGlobal('BIN',"dtlogin.rc") . " reset",&getGlobal('BIN',"dtlogin.rc") . " reset");

    }
}

sub RestrictRendezvous {
    if (&getGlobalConfig("MiscellaneousDaemons","rendezvous") eq "Y") {
	&B_log("DEBUG","# sub rendezvous\n");
        
        my $distro = &GetDistro;

	if ($distro =~ /^OSX/) {
	    # Pre-Tiger, Rendezvous/Bonjour was started by SystemStarter...
	    
	    my $systemstarter_mDNSResponder_startscript = &getGlobal('FILE','systemstarter_mDNSResponder_startscript');
	    if ( -e $systemstarter_mDNSResponder_startscript ) {
		&B_hash_comment_line($systemstarter_mDNSResponder_startscript,'^\s*\/usr\/sbin\/mDNSResponder\b');
	    }
	    
	    # ...while post-Tiger, Rendezvous/Bonjour is started by launchd.
	    
	    my $launchd_mDNSResponder_configfile = &getGlobal('FILE','launchd_mDNSResponder_configfile');
	    
	    if ( -e $launchd_mDNSResponder_configfile ) {
		&B_deactivate_launchd($launchd_mDNSResponder_configfile);
	    }

	}
	elsif ( ($distro =~ /^RH/) or ($distro =~ '^MN') or ($distro =~ '^SE') ) {
	    &B_chkconfig_off('mDNSResponder');
	    &B_chkconfig_off('nifd');
	} else {
            &B_log("WARNING","No redezvous-shutdown method defined for this OS/distribution.");
        }
    }
}

sub RestrictAutoDiskMount {
    if (&getGlobalConfig("MiscellaneousDaemons","autodiskmount") eq "Y") {
	&B_log("DEBUG","# sub autodiskmount\n");

	if (&GetDistro =~ /^OSX/) {
	    &B_replace_line('/System/Library/StartupItems/Disks/Disks','^\s*\/sbin\/autodiskmount\s+\-va',"    /sbin/autodiskmount -v\n");
	}

    }
}

sub RestrictNTPD {
    if (&getGlobalConfig("MiscellaneousDaemons","disable_ntpd") eq "Y") {
	&B_log("DEBUG","# sub disable_ntpd\n");

	if (&GetDistro =~ /^OSX/) {
	    &B_replace_line(&getGlobal('FILE','hostconfig'),'^TIMESYNC=-YES-',"TIMESYNC=-NO-\n");
	}

    }
}


sub RestrictDiagnostics {
    if (&getGlobalConfig("MiscellaneousDaemons","diagnostics_localonly") eq "Y") {
	&B_log('DEBUG',"# sub diagnostics_localonly");

#        my $setpath="PATH=/usr/bin/; "; #Needed for toggle_switch
        &B_System(&getGlobal('BIN',"diagnostic") . " stop",
                  &getGlobal('BIN',"diagnostic") . " start");

# Note, commenting out toggle_switch for now since this is a frequent source
# of errors, and according to the diagnostics owner is not a necessary step in disabling
# diagnostics.
#        &B_System("$setpath " . &getGlobal('BIN',"toggle_switch") . " stop",
#                  "$setpath " . &getGlobal('BIN',"toggle_switch") . " restart");

        &B_create_file(&getGlobal('FILE',"local_only"));

#        &B_System("$setpath " . &getGlobal('BIN',"toggle_switch") . " restart",
#                  "$setpath " . &getGlobal('BIN',"toggle_switch") . " stop");

        &B_System(&getGlobal('BIN',"diagnostic") . " start",
                  &getGlobal('BIN',"diagnostic") . " stop");

    }
}



sub RestrictSyslog {
    if (&getGlobalConfig("MiscellaneousDaemons","syslog_localonly") eq "Y") {
	&B_log("DEBUG","# sub syslog_localonly");

        my $opts = &B_get_rc("SYSLOGD_OPTS");

        if ($opts !~ /-N/) {
	    &B_System(&getGlobal('BIN',"syslogd_init") . " stop",
		      &getGlobal('BIN',"syslogd_init") . " start");

	    if ($opts =~ /-/) {
		# $opts =~ s/^([^-]*)(-.*)$/$1-N $2/;
                if ($opts =~ /^"(.*)"$/) {
                    $opts = '"' . "-N " . $1 . '"';
                }
	    }
	    else {
		$opts = '"' . "-N" . '"';
	    }
	    &B_set_rc("SYSLOGD_OPTS", $opts);

	    &B_System(&getGlobal('BIN',"syslogd_init") . " start",
		      &getGlobal('BIN',"syslogd_init") . " stop");


        }
	else {
	    &B_log('DEBUG',"SYSLOGD_OPTS already contains a '-N' option");
	}



    }
}

sub DeactivateKudzu {
    if (&getGlobalConfig("MiscellaneousDaemons","disable_kudzu") eq "Y") {
	&B_log("DEBUG","# sub DeactivateKudzu\n");

	my $distro = &GetDistro;
	if ( ($distro =~ '^RH') or ($distro =~ '^MN') or ($distro =~ '^SE') ) {
	    &B_chkconfig_off("kudzu");
	}
	# else {
	# What do we do on Debian and Turbo?
	# }
    }
}

sub DeactivateHPOJ {
    if (&getGlobalConfig("MiscellaneousDaemons","disable_hpoj") eq "Y") {
	&B_log("DEBUG","# sub DeactivateHPOJ\n");

	my $distro = &GetDistro;
	if ( ($distro =~ '^RH') or ($distro =~ '^MN') or ($distro =~ '^SE') ) {
	    &B_chkconfig_off("hpoj");
	}
	# else {
	# What do we do on Debian and Turbo?
	# }
    }
}

sub DeactivateISDN {
    if (&getGlobalConfig("MiscellaneousDaemons","disable_isdn") eq "Y") {
	&B_log("DEBUG","# sub DeactivateISDN\n");

	my $distro = &GetDistro;
	# TODO: confirm that Mandrake also uses /etc/init.d/isdn running isdnlog
	if ( ($distro =~ '^RH') or ($distro =~ '^MN') or ($distro =~ '^SE') ) {
	    &B_chkconfig_off("isdn");
	}
	# else {
	# What do we do on Debian and Turbo?
	# }
    }
}

sub DeactivateBluetooth {
    if (&getGlobalConfig('MiscellaneousDaemons','disable_bluetooth') eq 'Y') {
	&B_log("DEBUG","# sub DeactivateBluetooth\n");

	my $distro = &GetDistro;
	if ( ($distro =~ '^RH') or ($distro =~ '^MN') or ($distro =~ '^SE') ) {
	    &B_chkconfig_off('bluetooth');
	}
    }
}

1;
