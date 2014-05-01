# Copyright (C) 2002-2003 Hewlett Packard Development Company, L.P.
# Copyright (C) 2005 Jay Beale
# Copyright (C) 2005 Charlie Long, Delphi Research
# Licensed under the GNU General Public License, version 2


use Bastille::API;
use Bastille::API::ServiceAdmin;
use Bastille::API::FileContent;
use Bastille::API::HPSpecific;

  sub test_deactivate_telnet{ &B_is_service_off('telnet'); };
$GLOBAL_TEST{'SecureInetd'}{'deactivate_telnet'} = \&test_deactivate_telnet;

  sub test_deactivate_ftp{
  if (&GetDistro =~ /^HP/) {
	return &B_is_service_off('ftp');
  }
  else {
	my $rtn1 = &B_is_service_off('ftp');
	my $rtn2 = &B_is_service_off('vsftpd');
	if ( ($rtn1 == SECURE_CANT_CHANGE()) and ($rtn2 == SECURE_CANT_CHANGE()) ) {
		return SECURE_CANT_CHANGE();
	}
	else {
		return NOTSECURE_CAN_CHANGE();
	}
  }
}
$GLOBAL_TEST{'SecureInetd'}{'deactivate_ftp'} = \&test_deactivate_ftp;


  sub test_deactivate_rtools { &B_is_service_off('rtools'); }
$GLOBAL_TEST{'SecureInetd'}{'deactivate_rtools'} = \&test_deactivate_rtools;

  sub test_deactivate_tftp{ &B_is_service_off('tftp'); }
$GLOBAL_TEST{'SecureInetd'}{'deactivate_tftp'} = \&test_deactivate_tftp;

  sub test_deactivate_bootp { &B_is_service_off('bootp'); }
$GLOBAL_TEST{'SecureInetd'}{'deactivate_bootp'} = \&test_deactivate_bootp;

  sub test_deactivate_finger{ &B_is_service_off('finger'); }
$GLOBAL_TEST{'SecureInetd'}{'deactivate_finger'} = \&test_deactivate_finger;

  sub test_deactivate_uucp{ &B_is_service_off('uucp'); }
$GLOBAL_TEST{'SecureInetd'}{'deactivate_uucp'} = \&test_deactivate_uucp;

  sub test_deactivate_ntalk { &B_is_service_off('ntalk'); }
$GLOBAL_TEST{'SecureInetd'}{'deactivate_ntalk'} = \&test_deactivate_ntalk;

  sub test_deactivate_ident{ &B_is_service_off('ident'); }
$GLOBAL_TEST{'SecureInetd'}{'deactivate_ident'} = \&test_deactivate_ident;

  sub test_deactivate_time { &B_is_service_off('time'); }
$GLOBAL_TEST{'SecureInetd'}{'deactivate_time'} = \&test_deactivate_time;

# if all of the built in services (daytime, echo, discard, and chargen) are disabled then
# don't ask the question
    sub test_deactivate_builtin { &B_is_service_off('builtin'); }
$GLOBAL_TEST{'SecureInetd'}{'deactivate_builtin'} = \&test_deactivate_builtin;

# if both kshell and klogin are already disabled then don't ask the question
    sub test_deactivate_ktools { &B_is_service_off('ktools'); }
$GLOBAL_TEST{'SecureInetd'}{'deactivate_ktools'} = \&test_deactivate_ktools;

# if the CDE related services are disabled then don't ask the question
    sub test_deactivate_dttools{ &B_is_service_off('dttools'); }
$GLOBAL_TEST{'SecureInetd'}{'deactivate_dttools'} = \&test_deactivate_dttools;

    sub test_deactivate_recserv{ &B_is_service_off('recserv'); }
$GLOBAL_TEST{'SecureInetd'}{'deactivate_recserv'} = \&test_deactivate_recserv;

    sub test_deactivate_swat{ &B_is_service_off('swat'); }
$GLOBAL_TEST{'SecureInetd'}{'deactivate_swat'} = \&test_deactivate_swat;

    sub test_deactivate_printer{ &B_is_service_off('printer'); }
$GLOBAL_TEST{'SecureInetd'}{'deactivate_printer'} = \&test_deactivate_printer;

    sub test_deactivate_rquotad{&B_is_service_off('rquotad'); }
$GLOBAL_TEST{'SecureInetd'}{'deactivate_rquotad'} = \&test_deactivate_rquotad;

# additional  inetd services
    sub test_deactivate_registrar{&B_is_service_off('registrar'); }
$GLOBAL_TEST{'SecureInetd'}{'deactivate_registrar'} = \&test_deactivate_rquotad;
    sub test_deactivate_instl_boots{&B_is_service_off('instl_boots'); }
$GLOBAL_TEST{'SecureInetd'}{'deactivate_instl_boots'} = \&test_deactivate_instl_boots;
    sub test_deactivate_rstatd{&B_is_service_off('rstatd'); }
$GLOBAL_TEST{'SecureInetd'}{'deactivate_rstatd'} = \&test_deactivate_rstatd;
    sub test_deactivate_rusersd{&B_is_service_off('rusersd'); }
$GLOBAL_TEST{'SecureInetd'}{'deactivate_rusersd'} = \&test_deactivate_rusersd;
    sub test_deactivate_rwalld{&B_is_service_off('rwalld'); }
$GLOBAL_TEST{'SecureInetd'}{'deactivate_rwalld'} = \&test_deactivate_rwalld;
    sub test_deactivate_sprayd{&B_is_service_off('sprayd'); }
$GLOBAL_TEST{'SecureInetd'}{'deactivate_sprayd'} = \&test_deactivate_sprayd;
    sub test_deactivate_cmsd{&B_is_service_off('cmsd'); }

    sub test_ftp_logging {
      my $inetdconf = &getGlobal("FILE", "inetd.conf");
      my $ftpd = &getGlobal("BIN", "ftp");
      my $handle;
      my $line;
      if (open($handle, "$inetdconf")) {
            while(<$handle>) {
                  if (/^\s*ftp\s+/) {
                        $line = $_;
                        last;
                  }
            }
            if ($line && $line !~ /-[lL] /) {
                  return NOTSECURE_CAN_CHANGE();
            }
            return SECURE_CANT_CHANGE();
            close $handle;
      }
      else {
            &B_log("DEBUG", "open $inetdconf for read failed");
            return NOT_INSTALLED();
      }
    }
$GLOBAL_TEST{'SecureInetd'}{'ftp_logging'} = \&test_ftp_logging;

sub test_log_inetd{
	# getting the list of current inetd arguments
	my $current_args = &B_get_rc("INETD_ARGS");
	# if the current arguments of inetd include a '-l' for logging then
	if($current_args =~ /\-l/) {
	    # don't ask the question
	    &B_log("DEBUG","(skip)log_inetd sub going to return: SECURE_CANT_CHANGE()");
	    return SECURE_CANT_CHANGE();
	}
	else {
	    # Otherwise, logging is not on, ask the question
	    &B_log("DEBUG","(ask)log_inetd sub going to return: NOTSECURE_CAN_CHANGE");
	    return NOTSECURE_CAN_CHANGE();
	}
    };
$GLOBAL_TEST{'SecureInetd'}{'log_inetd'} = \&test_log_inetd;

   sub test_tcpd_default_deny{
	my $hostsallow = &getGlobal('file','hosts.allow');
        my $hostsdeny = &getGlobal('file','hosts.deny');

	#
	# Check for the original hosts.deny method of setting up
	# default deny first.
	#
	if(-e $hostsdeny) {

	    #read file in backwards

	    open FILE, "<$hostsdeny";
	    my @lines = <FILE>;
	    close FILE;

	    my @rev = reverse @lines;

	    # Look through lines in reverse order. seeking a ALL:ALL
	    foreach $line (@rev) {
		if ($line =~ /^\s*ALL\s*:\s*ALL\s*$/) {
		    return SECURE_CANT_CHANGE();
		}
	    }
	}
	#
	# Check for the newer hosts.allow method of setting up
	# default deny now, where hosts.allow is the only file
	# that contains both ALLOW and DENY lines.
	#

	if(-e $hostsallow) {

	    #read file in forwards

	    open FILE, "<$hostsallow";
	    my @lines = <FILE>;
	    close FILE;

	    # Look through lines in forward order. seeking an ALL:ALL:DENY, while
	    # allowing for an ALL: ALL :  <some options> : DENY.
	    #
	    # If we find an ALL : ALL : ALLOW before that, its an immediate
	    # ASKQ, since the default-deny is superceded by this line.

	    foreach $line (@lines) {
		if ($line =~/^\s*ALL\s*:\s*ALL\s*:([^:]*:|)\s*DENY\s*$/ ) {
		    return SECURE_CANT_CHANGE();
		}
		if ($line =~/^\s*ALL\s*:\s*ALL\s*:([^:]*:|)\s*ALLOW\s*$/ ) {
		    return NOTSECURE_CAN_CHANGE();
		}
	    }
	}

	return NOTSECURE_CAN_CHANGE();
    };
$GLOBAL_TEST{'SecureInetd'}{'tcpd_default_deny'} = \&test_tcpd_default_deny;


      sub test_owner{
            my $issuefile = &getGlobal('FILE','issue');
            if( -e $issuefile ) {
                  if(&B_match_line($issuefile,'authorized|AUTHORIZED|Authorized')) {
                        return (SECURE_CANT_CHANGE(),
                                &B_getValueFromFile('property of ([\w\s]*), whether',
                                                   $issuefile));
                  } else {
                        return STRING_NOT_DEFINED();
                  }
            } else {
                  return STRING_NOT_DEFINED();
            }
      };
$GLOBAL_TEST{'SecureInetd'}{'owner'} = \&test_owner;


    sub test_banners{
        my @ownerResult = &{$GLOBAL_TEST{'SecureInetd'}{'owner'}};
        if ( $ownerResult[0] == SECURE_CANT_CHANGE() ) {
            return SECURE_CANT_CHANGE();
        } else {
            return NOTSECURE_CAN_CHANGE();
        }
    };
$GLOBAL_TEST{'SecureInetd'}{'banners'} = \&test_banners;


sub test_inetd_sec {
      my $inetdconf = &getGlobal('FILE','inetd.conf');
      open *FH, $inetdconf or return 0;
      my %services;
      my @data;
      while (my $line = <FH> ) {
            chomp $line;
            if ($line =~ /^\s*$/ || $line =~ /^\s*#.*/) {
            next;
            }
            if ($line =~ /^rpc\s*/) {
            @data = split /\s{1,}/, $line;
            $services{$data[10]} = 1;
            next;
            }
            @data = split /\s{1,}/, $line;
            $services{$data[0]} = 1;
      }
      
      my $inetdsec = &getGlobal('FILE','inetd.sec');
      foreach my $key (keys %services) {
            if ( ! &B_match_line( $inetdsec, "$key allow" ) ) {
                  return NOTSECURE_CAN_CHANGE();
            }
            if ( ! &B_match_line( $inetdsec, "$key deny" ) ) {
                  return NOTSECURE_CAN_CHANGE();
            }
      }
      return SECURE_CANT_CHANGE()
}
$GLOBAL_TEST{'SecureInetd'}{'inetd_sec'} = \&test_inetd_sec;

1;
