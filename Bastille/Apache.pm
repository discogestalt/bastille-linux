# Copyright (C) 1999-2005 Jay Beale
# Copyright (C) 2001-2003 Hewlett Packard Development Company, L.P.
# Licensed under the GNU General Public License, version 2


package Bastille::Apache;
use lib "/usr/lib";

use Bastille::API;
use Bastille::API::HPSpecific;
use Bastille::API::ServiceAdmin;
use Bastille::API::FileContent;


@ENV="";
$ENV{PATH}="";
$ENV{CDPATH}=".";
$ENV{BASH_ENV}="";

# TO DO:
#
# 1. Write ConfigureSSL

#######################################################################
##                              HTTP/APACHE                          ##
#######################################################################

&DeactivateApacheServer;
&DeactivateHPWSApache;
&LimitListeningInterfaces;
&ChrootHPWSApache;
&ModifyAccessconf;
#&ConfigureSSL;


sub DeactivateApacheServer {

    if ( &getGlobalConfig("Apache","apacheoff") eq "Y" ) {

	&B_log("ACTION","# sub DeactivateApacheServer\n");
	&B_chkconfig_off ("httpd");
	if (&GetDistro =~ "^SE") {
	    if ( -e (&getGlobal('DIR', 'initd') . "/apache2") ) {
	        &B_chkconfig_off ("apache2");
	    }
	}
    }
}


sub DeactivateHPWSApache {

    if ( &getGlobalConfig("Apache","deactivate_hpws_apache") eq "Y" ) {

	my $isHPWSApacheOff =  &B_is_service_off('hpws_apache');
	                    
	&B_log("ACTION","# sub DeactivateHPApache2\n");

	# if the apache running is the hpws version, turn it off
	if(defined $isHPWSApacheOff && $isHPWSApacheOff == 0) {
	    my $exportpath = "export PATH=/usr/bin; ";

	    # stop the service using the stopall switch
	    &B_System($exportpath . &getGlobal('FILE', 'hpws_apachectl') . " stopall", 
		      $exportpath . &getGlobal('FILE', 'hpws_apachectl') . " start");

	    # set parameter, so that service will stay off after reboots
            &B_set_rc("HPWS_APACHE_START",0);
	} 
	
    }

}


sub LimitListeningInterfaces {

    if ((&getGlobalConfig("Apache","bindapachelocal") eq "Y") or (&getGlobalConfig("Apache","bindapachenic") eq "Y")) {
	
	&B_log("ACTION","# sub LimitListeningInterfaces\n");

	# First, figure out which configuration file to modify...
	# This is made more complicated by the fact that SUSE has broken httpd into many files.
	my $httpd_file;
	if (&GetDistro =~ /^SE/) {
	    $httpd_file=&getGlobal('FILE','listen.conf');
	}
	else {
	    $httpd_file=&getGlobal('FILE', "httpd.conf");
	}

	# Bind Apache to a particular interface or to the loopback device.

	if (&getGlobalConfig("Apache","bindapachenic") and (&getGlobalConfig("Apache","bindapacheaddress") =~ /^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}/) ) {
	    my $listen_ip=&getGlobalConfig("Apache","bindapacheaddress");
	    if (! ($listen_ip =~ /\:/) ) {
		# user did not specify port number
		&B_log("ERROR","Binding Apache to a particular IP address: no port specified, defaulting to :80\n");
		$listen_ip .= ":80";
	    }
	    
	    &B_replace_line($httpd_file,'^\s*Listen\s',"Listen ${listen_ip}\n");
	}
	elsif (&getGlobalConfig("Apache","bindapachelocal") eq "Y") {
	    &B_replace_line($httpd_file,'^\s*Listen\s',"Listen 127.0.0.1:80\n");
	}
	else {
	    &B_log("ERROR","Invalid address specified when trying to limit Apache's listening interfaces.  Probably, you tried to bind Apache to a particular interface, but did not specify a valid interface number...\n");
	}

    }
}

sub ModifyAccessconf {

    if ( (&getGlobalConfig("Apache","symlink") eq "Y") or (&getGlobalConfig("Apache","ssi") eq "Y") or (&getGlobalConfig("Apache","cgi") eq "Y") or (&getGlobalConfig("Apache","apacheindex") eq "Y" ) ) {
	
	&B_log("ACTION","# sub ModifyAccessconf\n");

	# SUSE 9 and 10, as well as SLES break httpd.conf into multiple files.
        if ((&GetDistro =~ /^SE9\.?/) or (&GetDistro =~ /^SLES/) or
            (&GetDistro =~ /^SE10\.?/) ) {
	    @files = (&getGlobal('FILE','httpd_access.conf'),&getGlobal('FILE','listen.conf'),&getGlobal('FILE','suse-default-server.conf'));
	}
	else {
	    @files = (&getGlobal('FILE','httpd_access.conf'));
	}
	
	# Disable FollowSymLinks to prevent users linking world readable/user 
	# readable files to allow viewing/access by the server.
	#
	# Deactivate Server Side includes
	# Deactivate CGI scripts
	# Deactivate generation of indexes for directories that don't have them
 

	# Build up  a list of parameters to remove
	my @parameters_to_remove;
	if (&getGlobalConfig("Apache","apacheindex") eq "Y") {
	    push @parameters_to_remove,'Indexes';
	}
	if (&getGlobalConfig("Apache","ssi") eq "Y" ) {
	    push @parameters_to_remove, "Includes";
	}
	if (&getGlobalConfig("Apache","symlink") eq "Y" ) {
	    push @parameters_to_remove,"FollowSymLinks";
	}
	if (&getGlobalConfig("Apache","cgi") eq "Y") {
	    push @parameters_to_remove,"ExecCGI";
	}
	# TODO: Check all recent distros for Apache config options.  Good catch Debora/Andreas.
        if (&GetDistro =~ "^SESLES10") {
            # In newer versions of apache all of these are allowed now:
            # Options All (adds almost all options)
            # Options parameter  (parameter is the only option)
            # Options +parameter (add parameter to the list of options)
            # Options -parameter (remove parameter from the list of options)

	    foreach $access_file (@files) {
	        # Look for Options lines with each parameter, removing those parameters.
	        foreach $parameter (@parameters_to_remove) {

                    # Replace "Options All"
		    if (&B_match_line($access_file,"^\\s*Options All")) {
		        B_replace_pattern($access_file,"^\\s*Options All","Options All","Options All -$parameter");
                    }
                    # Replace "Options +parameter"
                    if (&B_match_line($access_file, "^\\s*Options\\s*.+[+]$parameter")) {
		        B_replace_pattern($access_file,"^\\s*Options\\s*.+[+]$parameter","[+]$parameter","\-$parameter");
                    }
                    # Replace "Options parameter"
                    if (&B_match_line($access_file, "^\\s*Options*.[^-]$parameter")) {
		        B_replace_pattern($access_file,"^\\s*Options*.[^-]$parameter","$parameter","\-$parameter");
                    }
                    # Correct any occurances of "Options --parameter" to "Options -parameter"
                    if (&B_match_line($access_file, "^\\s*Options\\s*.{2}[-]$parameter")) {
                        B_replace_pattern($access_file,"{2}[-]$parameter","{2}[-]$parameter","\-$parameter");
                    }
                }
            }
            # restart apache2 to pick up changes
            B_service_restart("apache2");
        }
        else {
	    foreach $access_file (@files) {
	        # Look for Options lines with each parameter, removing those parameters.
	        foreach $parameter (@parameters_to_remove) {

	    	    my $options_pattern = "^\\s*Options\\s+(.*\\b$parameter\\b.*)";
		    if (&B_match_line($access_file,$options_pattern)) {
		        # Matches lines like Options $parameter (the only item)
		        B_replace_pattern($access_file,"^\\s*Options\\s*$parameter\\s*\$","\\s*Options\\s*$parameter",'');
                        # Matches the first or middle item in a space-separated list
		        B_replace_pattern($access_file,"^\\s*Options.*\\b$parameter\\s*","\\b$parameter\\s*",'');

		    }
	        }
	    
	    }
	}
	
    } 

}


################################################################################
#  &ChrootHPWSApache;
#     This subroutine uses the chroot script that comes with Apache 2.0
#     or greater.  It makes modifications to httpd.conf so that when
#     Apache starts it will chroot itself into the jail that the above
#     mentions script creates.
#
#     uses B_replace_line B_create_dir B_System B_TODO
###############################################################################
sub ChrootHPWSApache {
    &B_log("ACTION","# sub ChrootHPWSApache\n");

    if(&getGlobalConfig('Apache','chrootapache') eq "Y"){
	my $chrootScript = &getGlobal('FILE',"hpws_chroot_os_cp.sh");
	my $httpd_conf = &getGlobal('FILE',"hpws_httpd.conf");
	my $httpd_bin = &getGlobal('BIN',"hpws_httpd");
	my $apachectl = &getGlobal('FILE',"hpws_apachectl");
	my $apacheJailDir = &getGlobal('BDIR',"hpws_apachejail");
	my $serverString = "HPWS Apache Server";

	&B_chrootHPapache($chrootScript,$httpd_conf,$httpd_bin,$apachectl,$apacheJailDir,$serverString);
    }
}


1;
