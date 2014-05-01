# Copyright (C) 1999, 2000 Jay Beale
# Licensed under the GNU General Public License, version 2

package Bastille::Printing;
use lib "/usr/lib";

use Bastille::API;
use Bastille::API::HPSpecific;
use Bastille::API::ServiceAdmin;
use Bastille::API::FileContent;
use Bastille::API::AccountPermission;

@ENV="";
$ENV{PATH}="";
$ENV{CDPATH}=".";
$ENV{BASH_ENV}="";

### TO DO: Figure out how to disable printing in other distros...
### TO DO: Figure out what to do about MiscellaneousDaemons and Printing
### TO DO:    when porting to other distros...

#######################################################################
##                                lpr/lpd                            ##
#######################################################################

#&DisallowRemotePrinting;
&DisableLprdrm;
&DisableCUPSD;
&DisableCUPSlpd;
#&ConfigLPRng;


sub DisallowRemotePrinting { 
   &B_log("ACTION","# sub DisallowRemotePrinting\n");
   # Disallow remote printing if this won't be a print server

   ## This is the default configuration for Redhat6.0 -- watch for this
   ## though, when porting to other distributions.
}

sub DisableLprdrm {

   # If this machine will never be used for printing, disable lpr/lpd/lprm
   # altogether...

    if (&getGlobalConfig("Printing","printing") eq "Y") {
	&B_log("ACTION","# sub DisableLprdrm\n");
	if ( &GetDistro =~ "^HP-UX") {
	    # TPS use of rc environment expects string instead of 0/1 flag
	    # so can't use &B_ch_rc; hard coded B_set_value instead.
	    &B_set_value("XPRINTSERVERS",'""',"/etc/rc.config.d/tps");
            &B_ch_rc("pd");
            &B_ch_rc("lp");
	} else {
            &B_chkconfig_off("lpd");
            &B_chmod(0500,&getGlobal('BIN',"lpr"));
            &B_chmod(0500,&getGlobal('BIN',"lprm"));
            &B_chmod(0500,&getGlobal('BIN',"lpq"));
	}
    }
}

sub DisableCUPSD {

   # If this machine will never be used for printing, disable lpr/lpd/lprm
   # altogether...

    if (&getGlobalConfig("Printing","printing_osx") eq "Y") {
	&B_log("ACTION","# sub DisableCUPSD\n");
	&B_chmod(0500,&getGlobal('BIN',"lpr"));
	&B_chmod(0500,&getGlobal('BIN',"lprm"));
	&B_chmod(0500,&getGlobal('BIN',"lpq"));
	if (&GetDistro =~ /^OSX/) {
	    &B_replace_line(&getGlobal('FILE','hostconfig'),'^CUPS\=\-YES\-',"CUPS=-NO-\n");
	}
    }
    elsif (&getGlobalConfig("Printing","printing_cups") eq "Y") {
	&B_log("ACTION","# sub DisableCUPSD\n");
	&B_chmod(0500,&getGlobal('BIN',"lpr"));
	&B_chmod(0500,&getGlobal('BIN',"lprm"));
	&B_chmod(0500,&getGlobal('BIN',"lpq"));
	&B_chmod_if_exists(0500,&getGlobal('BIN',"lpstat"));
	&B_chmod_if_exists(0500,&getGlobal('BIN',"lppasswd"));
	my $distro = &GetDistro;
	unless (&GetDistro =~ /^OSX/) {
	    &B_chkconfig_off("cups");
	    &B_chkconfig_off("cups-config-daemon");
	}
    }
}

sub DisableCUPSlpd {
    if (&getGlobalConfig("Printing","printing_cups_lpd_legacy") eq "Y") {
	&B_log("ACTION","# sub DisableCUPSDlpd\n");

	# If we're on an xinetd-based system
	if  (&getGlobal('DIR', "xinetd.d") ne "") {
	    my $cups_lpd_xinetd_file = &getGlobal('FILE','cups-lpd');
	    if ( -e $cups_lpd_xinetd_file) {
		# Tweak or add a disable line to /etc/xinetd.d/cups-lpd
		&B_replace_line($cups_lpd_xinetd_file,'disable\s*=',"\tdisable\t\t= yes\n");
		&B_insert_line($cups_lpd_xinetd_file,'disable\s*=',"\tdisable\t\t= yes\n",'server\s*=');
	    }
        }
        elsif ( -e &getGlobal('FILE', "inetd.conf") ) {
	    &B_hash_comment_line( &getGlobal('FILE', "inetd.conf"),'^[^\#]*\bcups-lpd');
	}
    }
}


sub ConfigLPRng {
   #&B_log("ACTION","# sub ConfigLPRng\n");
   #### does someone want to come up with a LPRng configuration ?
}

1;
