# Copyright (c) 2005 Jay Beale
# Copyright (C) 2002-2003, 2005, 2006 Hewlett Packard Development Company, L.P.
# Licensed under the GNU General Public License, version 2

# This is to be pulled into the API to define tests
# currently these only work for HP-UXrequire Bastille::API;

use Bastille::API;
use Bastille::API::ServiceAdmin;
use Bastille::API::FileContent;

#if (&GetDistro =~ /^HP/) {
    
  $GLOBAL_TEST{'Apache'}{'deactivate_hpws_apache'} = 
    sub {
        my $apachectl = getGlobal("FILE","hpws_apachectl");
        # Return not-installed if the file we're going to use isn't there.
        if (not((-e $apachectl))) {
            return NOT_INSTALLED();
        }
        
	# see if the hpws_apache service is scheduled to run
	my $isHPWServiceOff = &B_is_service_off('hpws_apache');
	                    

	if(defined $isHPWServiceOff && $isHPWServiceOff == 0) {
	    # HPWS version is running
	    return NOTSECURE_CAN_CHANGE();
	} else {
	    # otherwise don't ask the question
	    return SECURE_CANT_CHANGE();
	}
    };

  $GLOBAL_TEST{'Apache'}{'chrootapache'} = 
    sub {
        my $apachectl = getGlobal("FILE","hpws_apachectl");
	# location of httpd.conf file for HPWS apache V.2.0.x
	my $hpws_httpd_conf = &getGlobal('FILE',"hpws_httpd.conf");
	# location of chroot os cp script for HPWS apache V.2.0.x
	my $hpws_chroot_os_cp = &getGlobal('FILE',"hpws_chroot_os_cp.sh");

        # Return not-installed if 2.0.x files aren't there.
        if (not((-e $apachectl) and (-e $hpws_httpd_conf) and
                (-e $hpws_chroot_os_cp))){
            return NOT_INSTALLED();
        }

	# if a httpd.conf file and a chroot_os_cp.sh file exist for HPWS Apache then
	if(-e $hpws_httpd_conf && -e $hpws_chroot_os_cp){
	    # if Apache 2.0 has not already been chrooted then
	    if(! &B_match_line($hpws_httpd_conf,"\^\\s\*Chroot\\s\+\.\+\$")){
		# ask the question
		return NOTSECURE_CAN_CHANGE();
	    }
	}

	# if hpws has already been chrooted then don't ask
	# the question
	return SECURE_CANT_CHANGE();
    };


  $GLOBAL_TEST{'Apache'}{'apacheoff'} =
    sub {
	return (&B_is_service_off('apache') and &B_is_service_off('apache2')  and 
		&B_is_service_off('httpd') );
    };

  $GLOBAL_TEST{'Apache'}{'bindapachelocal'} =
    sub {
	# Only ask the question if an Apache binary is present.
	if (&apache_present) {

	    # SuSE uses a listen.conf file for Listen statements.
	    my $listen_file;
	    if (&GetDistro =~ /^SE9\.?/ or &GetDistro =~ /^SESLES/ ) {
		$listen_file = &getGlobal('FILE','listen.conf');
	    }
	    else {
		$listen_file = &getGlobal('FILE','httpd.conf');
	    }
	    unless (&B_match_line($listen_file,'^\s*Listen\s+127\.')) {
		return NOTSECURE_CAN_CHANGE();
	    }
	    # If there wasn't a file without a Listen line, we're good.
	    return SECURE_CANT_CHANGE();
	}
	else {
	    # Return SKIP if Apache isn't present.
	    return NOT_INSTALLED();
	}
    };

  $GLOBAL_TEST{'Apache'}{'bindapachenic'} =
    sub {
	# Only ask the question if an Apache binary is present.
	if (&apache_present) {

	    # SuSE uses a listen.conf file for Listen statements.
	    my $listen_file;
	    if (&GetDistro =~ /^SE9\.?/ or &GetDistro =~ /^SESLES/ ) {
		$listen_file = &getGlobal('FILE','listen.conf');
	    }
	    else {
		$listen_file = &getGlobal('FILE','httpd.conf');
	    }
	    # Check the file for a Listen line that indicates an IP address
	    if (&B_match_line($listen_file,'^\s*Listen\s+\d+\.\d+\.\d+\.\d+')) {
		return SECURE_CANT_CHANGE();
	    }
	    else {
		return NOTSECURE_CAN_CHANGE();
	    }
	}
	else {
	    return NOT_INSTALLED();
	}
    };

$GLOBAL_TEST{'Apache'}{'generalweb'} =
    sub {
	if (&apache_present) {
	    return NOTSECURE_CAN_CHANGE();
	}
    };


  $GLOBAL_TEST{'Apache'}{'symlink'} =
    sub {
	# Only ask the question if an Apache binary is present.
	if (&apache_present) {

	    # SUSE breaks httpd.conf into many files.
	    if (&GetDistro =~ /^SE9\.?/ or &GetDistro =~ /^SESLES/ ) {
		@files = (&getGlobal('FILE','httpd.conf'),&getGlobal('FILE','listen.conf'),&getGlobal('FILE','suse-default-server.conf'));
	    }
	    else {
		@files = (&getGlobal('FILE','httpd.conf'));
	    }
	    # Check all Options lines to see if they have FollowSymLinks present
	    foreach $file (@files) {
		if (&B_match_line($file,'^\s*Options.*\bFollowSymLinks\b')) {
		    return NOTSECURE_CAN_CHANGE();
		}
	    }
	    # Otherwise return SKIPQ.
	    return SECURE_CANT_CHANGE();
	}
	else {
	    return NOT_INSTALLED();
	}
    };

  $GLOBAL_TEST{'Apache'}{'ssi'} =
    sub {
	# Only ask the question if an Apache binary is present.
	if (&apache_present) {

	    # SUSE breaks httpd.conf into many files.
	    if (&GetDistro =~ /^SE9\.?/ or &GetDistro =~ /^SESLES/ ) {
		@files = (&getGlobal('FILE','httpd.conf'),&getGlobal('FILE','listen.conf'),&getGlobal('FILE','suse-default-server.conf'));
	    }
	    else {
		@files = (&getGlobal('FILE','httpd.conf'));
	    }
	    foreach $file (@files) {
		# Check all Options lines to see if they have Includes present.
		# We allow IncludesNoExec, but might need to change that.
		if (&B_match_line($file,'^\s*Options.*\bIncludes\b')) {
		    return NOTSECURE_CAN_CHANGE();
		}
	    }
	    return SECURE_CANT_CHANGE();
	}
	else {
	    return NOT_INSTALLED();
	}
    };

  $GLOBAL_TEST{'Apache'}{'cgi'} =
    sub {
	# Only ask the question if an Apache binary is present.
	if (&apache_present) {
	    # SUSE breaks httpd.conf into many files.
	    if (&GetDistro =~ /^SE9\.?/ or &GetDistro =~ /^SESLES/ ) {
		@files = (&getGlobal('FILE','httpd.conf'),&getGlobal('FILE','listen.conf'),&getGlobal('FILE','suse-default-server.conf'));
	    }
	    else {
		@files = (&getGlobal('FILE','httpd.conf'));
	    }
	    foreach $file (@files) {
		# Check all Options lines to see if they have ExecCGI present.
		# We should consider allowing CGI execution in a single directory, but 
		# do this in a separate question.  Many servers don't need CGI.
		if (&B_match_line($file,'^\s*Options.*\bExecCGI\b')) {
		    return NOTSECURE_CAN_CHANGE();
		}
	    }
	    return SECURE_CANT_CHANGE();
	}
	else {
	    return NOT_INSTALLED();
	}
    };

  $GLOBAL_TEST{'Apache'}{'apacheindex'} =
    sub {
	# Only ask the question if an Apache binary is present.
	if (&apache_present) {
	    # SUSE breaks httpd.conf into many files.
	    if (&GetDistro =~ /^SE9\.?/ or &GetDistro =~ /^SESLES/ ) {
		@files = (&getGlobal('FILE','httpd.conf'),&getGlobal('FILE','listen.conf'),&getGlobal('FILE','suse-default-server.conf'));
	    }
	    else {
		@files = (&getGlobal('FILE','httpd.conf'));
	    }
	    foreach $file (@files) {
		# Check all Options lines to see if they have Index present.
		if (&B_match_line($file,'^\s*Options.*\bIndex\b')) {
		    return NOTSECURE_CAN_CHANGE();
		}
	    }
	    return SECURE_CANT_CHANGE();
	}
	else {
	    return NOT_INSTALLED();
	}
    };


###################################################################################
# &apache_present is a local routine to test_Apache which tells us whether Apache #
# is present on the system.  This is slightly non-trivial since different distros #
# use different versions of Apache.                                               #
###################################################################################

sub apache_present {

    if ( -e &getGlobal(FILE,'httpd') or -e &getGlobal(FILE,'httpd2') ) {
	return 1;
    }
  }
#}
1;
