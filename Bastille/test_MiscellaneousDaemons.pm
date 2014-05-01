# Copyright (C) 2002-2008 Hewlett Packard Development Company, L.P.
# Copyright (C) 2005 Jay Beale
# Copyright (C) 2005 Charlie Long, Delphi Research
# Licensed under the GNU General Public License, version 2

use Bastille::API;
use Bastille::API::HPSpecific;
use Bastille::API::ServiceAdmin;
use Bastille::API::FileContent;


#TODO: See if we can define these in a loop
sub test_nfs_server {
    return &B_is_service_off("nfs.server");
}
    $GLOBAL_TEST{'MiscellaneousDaemons'}{'nfs_server'} = \&test_nfs_server;


sub test_nfs_client {
    return &B_is_service_off('nfs.client');
}
    $GLOBAL_TEST{'MiscellaneousDaemons'}{'nfs_client'} =\&test_nfs_client;


sub test_disable_ptydaemon {
    return &B_is_service_off("ptydaemon");
}
    $GLOBAL_TEST{'MiscellaneousDaemons'}{'disable_ptydaemon'} =\&test_disable_ptydaemon;


sub test_disable_pwgrd {  #service pwgr is enacted via pwgrd
    return &B_is_service_off('pwgr');
}
    $GLOBAL_TEST{'MiscellaneousDaemons'}{'disable_pwgrd'} =\&test_disable_pwgrd;


sub test_disable_rbootd {
    return &B_is_service_off('rbootd');
}
    $GLOBAL_TEST{'MiscellaneousDaemons'}{'disable_rbootd'} =\&test_disable_rbootd;

sub test_minimalism {
    return STRING_NOT_DEFINED(); #This isn't even a "real" question, and shouldn't be in the report or config.
    }
    $GLOBAL_TEST{'MiscellaneousDaemons'}{'minimalism'} = \&test_nis_server;

sub test_nis_server {
    return &B_is_service_off('nis.server');
}
$GLOBAL_TEST{'MiscellaneousDaemons'}{'nis_server'} = \&test_nis_server;

sub test_nis_client {
    if (&GetDistro =~ /^HP-UX/) {
        return &remoteServiceCheck('nis');
    }
    else {
        return &B_is_service_off("ypbind");
    }
}
$GLOBAL_TEST{'MiscellaneousDaemons'}{'nis_client'} = \&test_nis_client;

sub test_nisplus_server {
    return &B_is_service_off('nisp.server');
}
$GLOBAL_TEST{'MiscellaneousDaemons'}{'nisplus_server'} = \&test_nisplus_server;

sub test_nisplus_client {
    return &remoteNISPlusServiceCheck('nisplus');
}
$GLOBAL_TEST{'MiscellaneousDaemons'}{'nisplus_client'} = \&test_nisplus_client;

sub other_boot_serv {

    return &B_combine_service_results(&B_is_service_off("mrouted"),
                                      &B_is_service_off("rwhod"),
                                      &B_is_service_off("ddfs"),
                                      &B_is_service_off("rarpd"),
                                      &B_is_service_off("rdpd"),
                                      &B_is_service_off("snaplus2")); 
}
$GLOBAL_TEST{'MiscellaneousDaemons'}{'other_boot_serv'} = \&other_boot_serv;
    
sub test_nfs_core {
    my $coreFile=&getGlobal('FILE',"link_nfs_core");
    my $file_result;
    
    my $version = &GetDistro;
    $version =~ s/HP-UX11.(\d{2})/$1/;
    
    if ( $version >= 31 ){
            $file_result = &B_is_service_off("nfs.core");
        } else {
        if (-e $coreFile ) {
            $file_result = NOTSECURE_CAN_CHANGE();
            } else {
            $file_result = SECURE_CANT_CHANGE();
        }
    }

    return &B_combine_service_results((
        &test_nis_client,
        &test_nis_server,
        &test_nfs_client,
        &test_nfs_server,
        &test_nisplus_server,
        &test_nisplus_client,
        $file_result ));
    
}
$GLOBAL_TEST{'MiscellaneousDaemons'}{'nfs_core'} = \&test_nfs_core;


#
# CIS implementation disable_smbclient
#
sub test_disable_smbclient{
    return &B_is_service_off('cifsclient');
}
$GLOBAL_TEST{'MiscellaneousDaemons'}{'disable_smbclient'} = \&test_disable_smbclient;

#
# CIS implementation disable_smbserver
#
sub test_disable_smbserver{
    return &B_is_service_off('samba');
}
$GLOBAL_TEST{'MiscellaneousDaemons'}{'disable_smbserver'} = \&test_disable_smbserver;

#
# CIS implementation disable_bind
#
sub test_disable_bind {
    return &B_is_service_off('named');
}
$GLOBAL_TEST{'MiscellaneousDaemons'}{'disable_bind'} = \&test_disable_bind;


#
# CIS implementation nobody_secure_rpc
#
sub test_disable_secure_rpc {
    my $keyserv_options = &B_get_rc("KEYSERV_OPTIONS");
    if ( $keyserv_options !~ /-d .*/ ) {
        return NOTSECURE_CAN_CHANGE();
    }
    return SECURE_CANT_CHANGE();
}
$GLOBAL_TEST{'MiscellaneousDaemons'}{'nobody_secure_rpc'} = \&test_disable_secure_rpc;

#
# CIS implementation sshd_config
#
sub test_configure_ssh {
    my $sshd_config = &getGlobal('FILE', 'sshd_config');
    
    if ( -e $sshd_config ) {
	if ( !&B_match_line( $sshd_config, '^Protocol\s+2') ) {
	    # print "^Prototocol 2 is not matched\n";
	    return NOTSECURE_CAN_CHANGE();
	}
	if ( !&B_match_line( $sshd_config, '^X11Forwarding\s+yes')) {
	    # print "^X11Forwarding matched\n";
	    return NOTSECURE_CAN_CHANGE();
	}
	if (!&B_match_line( $sshd_config, '^IgnoreRhosts\s+yes') ) {
	    # print "^IgnoreRhosts not matched\n";
	    return NOTSECURE_CAN_CHANGE();
	}
        
        # for those who still use SSH-1 protocol
        if ( B_match_line( $sshd_config, '^RhostsAuthentication')){
            if (!&B_match_line( $sshd_config, '^RhostsAuthentication\s+no')) {
                print "^RhostsAuthentication not matched\n";
                return NOTSECURE_CAN_CHANGE();
            }
        }
        
	if (!&B_match_line( $sshd_config, '^RhostsRSAAuthentication\s+no')) {
	    # print "^RhostsRSAAuthentication not matched\n";
	    return NOTSECURE_CAN_CHANGE();
	}
	if (!&B_match_line( $sshd_config, '^PermitRootLogin\s+no')) {
	    # print "^PermitRootLogin not matched\n";
	    return NOTSECURE_CAN_CHANGE();
	}
	if (!&B_match_line( $sshd_config, '^PermitEmptyPasswords\s+no')) {
	    # print "^PermitEmptyPasswords not matched\n";
	    return NOTSECURE_CAN_CHANGE();
	}
	if (!&B_match_line( $sshd_config, '^Banner\s+/etc/issue')) {
	    # print "^Banner not matched\n";
	    return NOTSECURE_CAN_CHANGE();
	}
	return SECURE_CANT_CHANGE();
    }
    return INCONSISTENT();
}
$GLOBAL_TEST{'MiscellaneousDaemons'}{'configure_ssh'} = \&test_configure_ssh;

#
# CIS implementation snmpd, with better "belt and suspenders" logic
#
sub test_snmpd {
    if( &GetDistro =~ "^HP-UX") {
        # todo - add check to ensure no set/get/trap snmpd.conf entries (or hash_commented out)
        return &B_is_service_off('SnmpMaster');
    }
}
$GLOBAL_TEST{'MiscellaneousDaemons'}{'snmpd'} = \&test_snmpd;


    sub test_xaccess {
	# location of the Xconfig file
	my $xconfig = &getGlobal('BFILE',"Xconfig");
	# location of Bastille's Xaccess file
	my $xaccess = &getGlobal('BFILE',"Xaccess.bastille");

        my $rcFile = &getGlobal('BIN',"dtlogin.rc");
	if(! -e $rcFile ) {
            return NOT_INSTALLED();
        }
	if ((-e $xaccess) and
            (&B_match_line($xconfig,"Dtlogin\.accessFile:\\s+$xaccess"))) {
	    # don't ask the question
	    return SECURE_CANT_CHANGE();
	} else {
	    # otherwise ask the question
	    return NOTSECURE_CAN_CHANGE();
	}

    }
    $GLOBAL_TEST{'MiscellaneousDaemons'}{'xaccess'} = \&test_xaccess;


sub test_diagnostics_localonly {
    if( &GetDistro =~ "^HP-UX") {
        if ((! -e &getGlobal('BIN',"diagnostic")) or
            (! -e &getGlobal('BIN',"toggle_switch")) ) {
            return  NOT_INSTALLED();
        }
        my $netstat = &getGlobal("BIN","netstat");
        my $local_only = &getGlobal("FILE","local_only");
        my $grep = getGlobal("BIN","grep");
        my $psLine = &B_Backtick("$netstat -a | $grep diagmond");
            if (($psLine =~
                /^tcp \s+\d+\s+\d+\s+localhost\.diagmond\s+\*\.\*\s+LISTEN$/) and
                (-e $local_only)){
                return SECURE_CANT_CHANGE();
            } else {
		return NOTSECURE_CAN_CHANGE();
            }
        }
    }
    $GLOBAL_TEST{'MiscellaneousDaemons'}{'diagnostics_localonly'} = \&test_diagnostics_localonly;


sub test_syslog_localonly {
	if( &GetDistro =~ "^HP-UX") {
	    my $opts = &B_get_rc("SYSLOGD_OPTS");
	    if ($opts =~ /-N/) {
		return SECURE_CANT_CHANGE();
	    }
	    else {
		return NOTSECURE_CAN_CHANGE();
	    }
	}
    }
    $GLOBAL_TEST{'MiscellaneousDaemons'}{'syslog_localonly'} = \&test_syslog_localonly;


# Added for Linux auditing

if (&GetDistro !~ "^HP-UX") {

# Put this function in, since I don't know how well Linux services are
# defined... these, possibly duplicate checks were in place before,
# so I left them in so this Bastille version's results won't change from
# the releeased Linux version

sub testExistAndService ($$){
    my $binFile = $_[0];
    my $service = $_[1];

    if (! -e $binFile ) {
	    return NOT_INSTALLED();
	} else {
	    return &B_is_service_off("$service");
	}
}

    sub test_apmd {
	    # Start out with SECURE_CANT_CHANGE(), changing this if we
	    # find an activated apmd or acpid.

	    my $return = SECURE_CANT_CHANGE();
	    if ( &GetDistro !~ "^HP-UX") {

		# Is there an init script for apmd?
		if ( -e &getGlobal('FILE',"initd_apmd")) {

		    # Is apmd on?
		    unless (&B_is_service_off('apmd')) {
		        $return = NOTSECURE_CAN_CHANGE();
		    }
		}

		# Is there an init script for acpid?
		if ( -e &getGlobal('FILE',"initd_acpid")) {

		    # Is acpid on?
		    unless (&B_is_service_off('acpid')) {
		        $return = NOTSECURE_CAN_CHANGE();
		    }
		}
	    }
	    return($return);
        }
    $GLOBAL_TEST{'MiscellaneousDaemons'}{'apmd'} = \&test_apmd;


    sub test_remotefs {
    if( &GetDistro =~ "^RHEL") {
       if (! -e &getGlobal('FILE',"initd_nfs")) {
        return SECURE_CANT_CHANGE();
        }
        else {
        return &B_is_service_off('nfs');
        }
     }
    elsif( &GetDistro =~ "^SESLES") {
        if (! -e &getGlobal('FILE',"initd_nfs")) {
        return SECURE_CANT_CHANGE();
        }
        else {
        return &B_is_service_off('nfsserver');
        }
      }
    }
    $GLOBAL_TEST{'MiscellaneousDaemons'}{'remotefs'} = \&test_remotefs;

#pcmcia in SUSE or RedHat

    sub test_pcmcia {
    return &testExistAndService( &getGlobal('FILE',"initd_pcmcia"), 'pcmcia');
    }
    $GLOBAL_TEST{'MiscellaneousDaemons'}{'pcmcia'} = \&test_pcmcia;


    sub test_dhcpd {
    return &testExistAndService( &getGlobal('FILE',"initd_dhcpd"),'dhcpd');
    }
    $GLOBAL_TEST{'MiscellaneousDaemons'}{'dhcpd'} = \&test_dhcpd;


    sub test_gpm {
    return &testExistAndService(&getGlobal('FILE',"initd_gpm"),'gpm');
    }
    $GLOBAL_TEST{'MiscellaneousDaemons'}{'gpm'} = \&test_gpm;


    sub test_hpoj {
    return &testExistAndService( &getGlobal('FILE',"initd_hpoj"),'hpoj');
    }
    $GLOBAL_TEST{'MiscellaneousDaemons'}{'hpoj'} = \&test_hpoj;


    sub test_innd {
    return &testExistAndService(&getGlobal('FILE',"initd_innd"),'inn');
    }
    $GLOBAL_TEST{'MiscellaneousDaemons'}{'innd'} = \&test_innd;


    sub test_isdn {
    return &testExistAndService(&getGlobal('FILE',"initd_isdn"), 'isdn');
    }
    $GLOBAL_TEST{'MiscellaneousDaemons'}{'isdn'} = \&test_isdn;

# RedHat  uses kudzu to check for new hardware, vs hwscan for SuSE
#TODO: Deal with hwscan
    sub test_disable_kudzu {
    return &testExistAndService(&getGlobal('FILE',"initd_kudzu"), 'kudzu');
    }
    $GLOBAL_TEST{'MiscellaneousDaemons'}{'disable_kudzu'} = \&test_disable_kudzu;

    sub test_disable_routed  {
    return &testExistAndService(&getGlobal('FILE',"initd_routed"), 'routed');
    }
    $GLOBAL_TEST{'MiscellaneousDaemons'}{'disable_routed'} = \&test_disable_routed;

    sub test_disable_gated {
    return &testExistAndService(&getGlobal('FILE',"initd_gated"), 'gated');
    }
    $GLOBAL_TEST{'MiscellaneousDaemons'}{'disable_gated'} = \&test_disable_gated;

    sub test_rendezvous {
    return &testExistAndService(&getGlobal('FILE',"initd_mDNSResponder"),'mDNSResponder');
    }
    $GLOBAL_TEST{'MiscellaneousDaemons'}{'rendezvous'} = \&test_rendezvous;


    sub test_disable_bluetooth {
    return &testExistAndService(&getGlobal('FILE',"initd_bluetooth"),'bluetooth');
    }
    $GLOBAL_TEST{'MiscellaneousDaemons'}{'disable_bluetooth'} = \&test_disable_bluetooth;

} #End Skip these test definitions for HP-UX

1;
