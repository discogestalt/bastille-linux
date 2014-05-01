# Copyright (C) 2002-2003,2006 Hewlett Packard Development Company, L.P.
# Copyright (C) 2005 Jay Beale
# Copyright (C) 2005 Charlie Long, Delphi Research
# Licensed under the GNU General Public License, version 2


use Bastille::API;
use Bastille::API::ServiceAdmin;
use Bastille::API::FileContent;

    sub test_ftpgeneral{
	if ( &B_is_service_off('ftp') and &B_is_service_off('vsftpd') ) {
	    return SECURE_CANT_CHANGE();
	}
    };
$GLOBAL_TEST{'FTP'}{'ftpgeneral'} = \&test_ftpgeneral;



if( &GetDistro !~ "^HP-UX") {

# TO DO: Ask HP if they'll accept this more dynamic routine (than the one
# defined for ftpusers).
# HP response: the routine looks good and more general, but the get_ftpuser_list
# function ONLY checks passwords, so we'd have to generalize that before pulling
# it in.

	sub test_ftpaccess{
	    # location of ftpusers file
	    my $ftpusers = &getGlobal('FILE',"ftpusers");

	    # UID where human users start
	    my $human_uid_start = 500;

	    if( &GetDistro =~ "^RH") {
		$human_uid_start = 500;
	    }
	    elsif( &GetDistro =~ "^SE") {
		$human_uid_start = 1000;
	    }

	    @$restrictedUser = B_get_ftpuser_list($human_uid_start);

	    # if the ftpusers file exists then
	    if(-e $ftpusers) {
		# check and see if each resticted user is in the file
		foreach my $user (@restrictedUser) {
		    if(! &B_match_line($ftpusers,"\^\\s\*$user\\s\*\$")) {
			# if a user is missing ask the question.
			return NOTSECURE_CAN_CHANGE();
		    }
		}
	    }
	    else {
		# if the file does not exists ask the question
		return NOTSECURE_CAN_CHANGE();

	    }

	    # if all resticted users are present inside of the
	    # ftpusers file then don't ask the question.
	    return SECURE_CANT_CHANGE();
	};
    $GLOBAL_TEST{'FTP'}{'ftpaccess'} = \&test_ftpaccess;

    sub ftpusertest($){
	my $matchString = $_[0];

	#TODO: move these hard-coded paths to getGlobal
	my $ftpaccess = &getGlobal('FILE','ftpaccess');
	my $vsftpdconf_location1 = '/etc/vsftpd/vsftpd.conf';
	my $vsftpdconf_location2 = '/etc/vsftpd.conf';
	my $vsftpdconf;

        # When we're dealing with ftpaccess (wu-ftpd)
	if ( -e $ftpaccess ) {
	    # ...look for a class line with anonymous on it.
	    if (&B_match_line($ftpaccess,'class\s+.*anonymous')) {
		return NOTSECURE_CAN_CHANGE();
	    }
	}

	# Find the vsftpd.conf file, which is sometimes in its own directory.
	if ( -e $vsftpdconf_location1 ) {
	    $vsftpdconf = $vsftpdconf_location1;
	}
	elsif ( -e $vsftpdconf_location2 ) {
	    $vsftpdconf = $vsftpdconf_location2;
	}

	# When we're dealing with vsftpd, look for anonymous_enable=NO.
	# The default is YES, so there _must_ be a line saying no.
	if ( defined($vsftpdconf) ) {
	    unless (&B_match_line($vsftpdconf,"$matchString")) {
		return NOTSECURE_CAN_CHANGE();
	    }
	}
	return SECURE_CANT_CHANGE();
    }

    sub test_anonftp{
	return ftpusertest('^\s*anonymous_enable\s*=\s*(no|NO)');
    };
    $GLOBAL_TEST{'FTP'}{'anonftp'} = \&test_anonftp;

    sub test_userftp {
	return &ftpusertest('^\s*local_enable\s*=\s*(yes|YES)');
    };
    $GLOBAL_TEST{'FTP'}{'userftp'} = \&test_userftp;

}

sub B_get_ftpuser_list($)
{
    $uid_where_human_users_start = shift;
    my $users;
    my $passwd = &getGlobal('FILE','passwd');
    open(PASSWD,$passwd);
    while(<PASSWD>) {
        #Get the users
        if (/([^:]+):([^:]+):([^:]+):([^:+])/)
        {
	    if ($3 < $uid_where_human_users_start) {
                push (@restrictedUsers, $1);
	    }
	}
    }
    return \@restrictedUsers;
}


    sub test_ftpusers {
	# location of ftpusers file
	my $ftpusers = &getGlobal('FILE',"ftpusers");
        my $ftpd = &getGlobal('BIN',"ftp");

	# list users that should be restricted inside of the ftpusers file
	my @restrictedUser = ("root","daemon","bin","sys","adm","uucp","lp","nuucp","hpdb");

        unless (-e $ftpd) {
            return NOT_INSTALLED();
        }

	# if the ftpusers file exists then
	if(-e $ftpusers) {
	    # check and see if each resticted user is in the file
	    foreach my $user (@restrictedUser) {
		if(! &B_match_line($ftpusers,"\^\\s\*$user\\s\*\$")) {
		    # if a user is missing ask the question.
		    return NOTSECURE_CAN_CHANGE();
		}
	    }
	}
	else {
	    # if the file does not exist, ask the question
	    return NOTSECURE_CAN_CHANGE();
	}

	# if all resticted users are present inside of the
        # ftpusers file then don't ask the question.
	return SECURE_CANT_CHANGE();

    };
$GLOBAL_TEST{'FTP'}{'ftpusers'} = \&test_ftpusers;

    sub test_ftpbanner {
	# location of ftp file
	my $ftpaccess = &getGlobal('FILE',"ftpaccess");
        my $ftpd = &getGlobal('BIN',"ftp");

        unless (-e $ftpd) {
            return NOT_INSTALLED();
        }

	# if the ftpaccess file exists then
	if(-e $ftpaccess) {
	    # check for banner line
	    if(! &B_match_line($ftpaccess,"banner ")) {
		    # if line is missing ask the question.
		    return NOTSECURE_CAN_CHANGE();
	    }
	}
	else {
	    # if the file does not exist, ask the question
	    return NOTSECURE_CAN_CHANGE();
	}

	return SECURE_CANT_CHANGE();

    };
$GLOBAL_TEST{'FTP'}{'ftpbanner'} = \&test_ftpbanner;

1;
