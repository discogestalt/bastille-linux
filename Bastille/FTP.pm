# Copyright (C) 1999 - 2005 Jay Beale
# Copyright (C) 2002 Hewlett Packard Development Company, L.P.
# Licensed under the GNU General Public License, version 2

package Bastille::FTP;
use lib "/usr/lib";

use Bastille::API;
use Bastille::API::ServiceAdmin;
use Bastille::API::FileContent;

@ENV="";
$ENV{PATH}="";
$ENV{CDPATH}=".";
$ENV{BASH_ENV}="";




#######################################################################
##                                  FTP                              ##
#######################################################################

&LimitFTPbyUserType;
&RestrictUserLogin;
&BannerOnUserLogin;


sub LimitFTPbyUserType {

    if ((&getGlobalConfig("FTP","anonftp") eq "Y") or (&getGlobalConfig("FTP","userftp") eq "Y")) {
	&B_log("ACTION","# sub LimitFTPbyUserType\n");

	# Are we using WU-FTPd?
	if ( -e '/etc/ftpaccess') {

	    # Optionally disable user and/or anonymous ftp
	    
	    # Construct the class line, based on what is disabled...  
	    # note: based on our tests, it is completely safe to have a line which lists no classes: no logins wil be allowed
	    #       in that case, which is what we want...
	    
	    my $class_line="class   all   ";
	    
	    unless (&getGlobalConfig("FTP","userftp") eq "N") {
		$class_line .= "real,guest";
		unless (&getGlobalConfig("FTP","anonftp") eq "N") {
		    $class_line .= ",";
		}
	    }
	    unless (&getGlobalConfig("FTP","anonftp") eq "N") {
		$class_line .= "anonymous";
	    }
	    $class_line .= "   *\n";
	    
	    # put the line in place...
	    
	    &B_replace_line ("/etc/ftpaccess",'^\s*class',$class_line);
	}

	# vsftpd has been a common FTP daemon in Linux since around 2002 or 2003 and has become the 
	# default FTP daemon of most distributions.

        # Find the vsftpd.conf file, which is sometimes in its own directory.
	my $vsftpdconf_location1 = '/etc/vsftpd/vsftpd.conf';
	my $vsftpdconf_location2 = '/etc/vsftpd.conf';
	my $vsftpdconf;
	if ( -e $vsftpdconf_location1 ) {
	    $vsftpdconf = $vsftpdconf_location1;
	}
	elsif ( -e $vsftpdconf_location2 ) {
	    $vsftpdconf = $vsftpdconf_location2;
	}

	if ( defined $vsftpdconf ) {
	    if (getGlobalConfig("FTP","anonftp") eq "Y") {
		&B_replace_line ($vsftpdconf,'^anonymous_enable\s*=',"anonymous_enable=NO\n");
		&B_append_line($vsftpdconf,'^anonymous_enable\s*=\s*NO',"anonymous_enable=NO\n");
	    }
	    if (getGlobalConfig("FTP","userftp") eq "Y") {
		&B_replace_line ($vsftpdconf,'^local_enable\s*=','local_enable=NO\n');
		&B_append_line($vsftpdconf,'^local_enable\s*=\s*NO','local_enable=NO\n');
	    }

            # Need to restart vsftpd for changes to take effect
            &B_service_restart("vsftpd");
	}
   }
}

sub RestrictUserLogin {
    if ( (&getGlobalConfig("FTP","ftpusers") eq "Y") ) {
	&B_log("ACTION","# sub RestrictUserLogin\n");
	# List of users to be disallowed ftp login
	my @restrictedUser = ("root","daemon","bin","sys","adm","uucp","lp","nuucp","hpdb","guest");

	foreach my $user (@restrictedUser) {
	    # append login unless it is already present inside of the file
	    if(! -e &getGlobal('FILE',"ftpusers")){
		&B_create_file(&getGlobal('FILE',"ftpusers"));
	    }
	    &B_append_line(&getGlobal('FILE',"ftpusers"),"^\\s*$user\\s*"  . '$',"$user\n");
	}
    }
}

sub BannerOnUserLogin {
    if ( (&getGlobalConfig("FTP","ftpbanner") eq "Y") ) {
	&B_log("ACTION","# sub BannerOnUserLogin\n");
        my $issuefile = &getGlobal('FILE','issue');

	unless ( -e $issuefile ) {
            my $banner_line="Authorized users only.  All activity may be monitored or reported.";
	    &B_create_file( $issuefile );
    	    &B_blank_file(  $issuefile ,'Authorized');
	    &B_append_line( $issuefile ,"Authorized", $banner_line );
	}

	# append banner line 
	if(! -e &getGlobal('FILE',"ftpaccess")){
	    &B_create_file(&getGlobal('FILE',"ftpaccess"));
	}
	&B_append_line(&getGlobal('FILE',"ftpaccess"), "banner ", "banner $issuefile");
    }
}

1;
