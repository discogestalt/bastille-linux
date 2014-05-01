# Copyright (C) 2002, 2005-2008 Hewlett Packard Development Company, L.P.
# Copyright (C) 2005 Jay Beale
# Copyright (C) 2005 Delphi Research

# Licensed under the GNU General Public License, version 2


# This is to be pulled into the API to define tests
# currently these only work for HP-UX

use Bastille::API;
use Bastille::API::AccountPermission;
use Bastille::API::ServiceAdmin;
use Bastille::API::FileContent;
use Bastille::API::HPSpecific;


# Doesn't vary with NIS
sub test_create_securetty {
	# location of the securetty file
	my $securetty = &getGlobal('FILE',"securetty");
	# if the securetty file exists then
	if(-e $securetty) {
	    # if a console line is found then
	    if(&B_match_line($securetty,"\^\\s\*console\\s\*\$")) {
		# don't ask the question
		return SECURE_CANT_CHANGE();
	    }
	}

	# otherwise ask the question.
	return NOTSECURE_CAN_CHANGE();
    };
$GLOBAL_TEST{'AccountSecurity'}{'create_securetty'} = \&test_create_securetty;

    sub test_hidepasswords {
	# location of shadow password file
	my $shadow = &getGlobal('FILE','shadow');
	# if shadowed password file exists
	if( -e $shadow){
	    # don't ask the question
	    return &secureIfNoNameService(SECURE_CANT_CHANGE());
	} else {
            return &isSystemTrusted;
        }
    };
$GLOBAL_TEST{'AccountSecurity'}{'hidepasswords'} = \&test_hidepasswords;

#Shouldn't vary in activation with Name Service
    sub test_system_auditing {
	
        if (&isSystemTrusted or &isTrustedMigrationAvailable) {
            my $current_auditing = &B_get_rc("AUDITING");
            # my $current_acct = &B_get_rc("START_ACCT");
            my $current_acct = 1;  # no need to have accounting for auditing
            my $audsys = &getGlobal("BIN","audsys");

            if(($current_auditing =~ /1/) and ($current_acct =~ /1/)){
                my $audResults = &B_Backtick("$audsys");
                if ($audResults =~ m/auditing system is currently on/) {
                    return SECURE_CANT_CHANGE();
                } else {
                    return INCONSISTENT();
                }
            } else {
                return NOTSECURE_CAN_CHANGE();
            }
        } else {
            return NOTSECURE_CAN_CHANGE();
        }
    };
$GLOBAL_TEST{'AccountSecurity'}{'system_auditing'} = \&test_system_auditing;


foreach my $loop_param ("ABORT_LOGIN_ON_MISSING_HOMEDIR", "NOLOGIN", "single_user_password") {
  my $param = $loop_param;
  $GLOBAL_TEST{'AccountSecurity'}{$param} =
  sub {
    if ($param eq "single_user_password") {
        $param = "BOOT_AUTH";
    }
    my $sec_setting = &B_get_sec_value("$param");
    if ($sec_setting eq "0") {
        return NOTSECURE_CAN_CHANGE();
    } elsif (not (defined ($sec_setting ))) {
	return NOTSECURE_CAN_CHANGE(); #Changed from STRING_NOT_DEFINED or else question is "missing"
    } elsif ($sec_setting eq "Not Unique") {
        return INCONSISTENT();
    } elsif ($sec_setting eq "1" ){
        return &secureIfNoNameService(SECURE_CANT_CHANGE());
    } else {
	return INCONSISTENT();
    }
  };
}



sub test_protectrhost{
	unless (&GetDistro =~ /^OSX/) {

	    # Check if rlogin, rsh, rexec are disallowed via Pluggable
            # Authentication Modules
	    foreach $service ( 'rexec', 'rlogin', 'rsh','login','shell' ) {
                $pamFile = &getGlobal('DIR', 'pamd') . "/$service";
		if ( -e $pamFile ) {
		    if (! &B_match_line($pamFile,
                                        'auth\s+required\s+pam_deny\.so$')) {
                        return NOTSECURE_CAN_CHANGE();
                    }
		}
            }

	}

	# Check if the rsh/rlogin/rexec lines have been commented out from
        # inetd.conf, if they exist.
        $inetdConfFile = &getGlobal('FILE', 'inetd.conf');
	if ( -e $inetdConfFile ) {
            if ( &B_match_line($inetdConfFile, 'rlogind')
                && (! &B_match_line($inetdConfFile, '^\s*#.*rlogind')) ) {
                return NOTSECURE_CAN_CHANGE();
            }
            if ( &B_match_line($inetdConfFile, 'rexecd')
                && (! &B_match_line($inetdConfFile, '^\s*#.*rexecd')) ) {
                return NOTSECURE_CAN_CHANGE();
            }
            if (&B_match_line($inetdConfFile, 'rshd')
                && (! &B_match_line($inetdConfFile, '^\s*#.*rshd')) ) {
                return NOTSECURE_CAN_CHANGE();
            }
	}
	if ( -e &getGlobal('FILE','xinetd.conf') ) {
	    # Some systems, including Mac OS X, have an inetd.conf file even
            # when they're xinetd-based.  Actually, you can have both inetd
            # and xinetd running, as long as they don't overlap ports.
	    foreach $file ('exec', 'login', 'rlogin', 'shell', 'rsh') {
		if (( -e &getGlobal('DIR', 'xinetd.d') . "/$file")
                    && (&getGlobal('DIR', 'xinetd.d') ne '')) {
		    if (! &B_match_line(&getGlobal('DIR', 'xinetd.d') . "/$file",'^\s*disable\s*=\s*yes') ) {
                        return NOTSECURE_CAN_CHANGE();
                    }
		}
	    }
	}
        return SECURE_CANT_CHANGE();
  };
$GLOBAL_TEST{'AccountSecurity'}{'protectrhost'} = \&test_protectrhost;

  sub test_passwdage {
        # Check if PASS_MAX_DAYS has been set to a two-digit number.
        if (! &B_match_line('/etc/login.defs', '^\s*PASS_MAX_DAYS\s+\d\d\n')) {
            return NOTSECURE_CAN_CHANGE();
        }
	else {
	    return SECURE_CANT_CHANGE();
	}
	
	# The following was here, on this non-HPUX item, but doesn't work on non-HPUX systems...unless
	# Bastille is no longer respecting REQUIRE_DISTRO on HP-UX.  JJB: consider investigating.
        #return &secureIfNoNameService(SECURE_CANT_CHANGE());
  };
$GLOBAL_TEST{'AccountSecurity'}{'passwdage'} = \&test_passwdage;

if (&GetDistro =~ "HP-UX") {
  #Define HP-UX Tests

    my $secfile = &getGlobal('FILE', 'security');
    my @policies = ('PASSWORD_MAXDAYS',
                    'PASSWORD_MINDAYS',
                    'PASSWORD_WARNDAYS',
                    'MIN_PASSWORD_LENGTH',
                    'PASSWORD_HISTORY_DEPTH',
                    'NUMBER_OF_LOGINS_ALLOWED',
                    'AUTH_MAXTRIES',
                    'SU_DEFAULT_PATH'
                    );
    my $policies = 'PASSWORD_MAXDAYS PASSWORD_MINDAYS PASSWORD_WARNDAYS '.
                   'MIN_PASSWORD_LENGTH PASSWORD_HISTORY_DEPTH';

    foreach my $policy (@policies){
        $GLOBAL_TEST{'AccountSecurity'}{"$policy"} = sub {
            my $value = &B_get_sec_value("$policy");
            if ($value eq 'Not Unique') {
                return STRING_NOT_DEFINED(); #Changed from "Inconsistent" so I don't get an "N" in the config
            } elsif (not(defined($value))) {
                return (STRING_NOT_DEFINED()); #Changed from "Not_Secure" so I don't get an "N" in the config
            } else {
                if (&isUsingRemoteNameService) {
                    return STRING_NOT_DEFINED();
                } else {
                    return (SECURE_CAN_CHANGE(), $value);
                }
            }
        };
    }

    my %ynQuestions = ('NUMBER_OF_LOGINS_ALLOWEDyn', 'NUMBER_OF_LOGINS_ALLOWED',
                       'AUTH_MAXTRIESyn', 'AUTH_MAXTRIES',
                       'SU_DEFAULT_PATHyn' , 'SU_DEFAULT_PATH',
                       'passwordpolicies' , "$policies",
                       'PASSWORD_HISTORY_DEPTHyn' , 'PASSWORD_HISTORY_DEPTH' );

    foreach my $ynQuestion (keys(%ynQuestions)) {
        &B_log("DEBUG","Defining tests for $ynQuestion");
        $GLOBAL_TEST{'AccountSecurity'}{"$ynQuestion"} =
        sub { # if any of the "children" of this question have been "secured"
              # by Bastille, then mark the Header "yes" (ask the question in the
              # UI, and mark the Question "Y" in the Reports.
            foreach my $policy (split(' ',$ynQuestions{$ynQuestion})){
                &B_log("DEBUG", "Testing policy $policy");
                my @rawReturn = &{$GLOBAL_TEST{'AccountSecurity'}{$policy}};
                my $testReturn = $rawReturn[0];
                my $testFiltered = &secureIfNoNameService($testReturn);
                if (($testFiltered == SECURE_CAN_CHANGE()) or
                    ($testFiltered == SECURE_CANT_CHANGE()) ){
                    return RELEVANT_HEADERQ();
                }
            } #This will tell users they have some name-service removal to do
            return &secureIfNoNameService(NOTRELEVANT_HEADERQ());
        };
    }

    sub test_umask {
	&B_log("ACTION","# test Umask\n");
	my @profileMasks=();
	my $HPUXSpecificUmask = &B_get_sec_value('UMASK');
        &B_log("DEBUG","HP-UX Specific UMASK: $HPUXSpecificUmask");
        if ($HPUXSpecificUmask eq 'Not Unique') {
            return INCONSISTENT();
        } else {
            my @filelist = ("profile", "zprofile", "csh.login");
            my $lastsetting='Initialized Setting';
            my $currentsetting='';
            foreach my $startupfile (@filelist) {
                my $fullpath = &getGlobal('FILE', $startupfile);
                if ( -e $fullpath ) {
                    $currentsetting = &B_getValueFromFile('^\s*umask\s+(\d{1,4})',$fullpath);
                    &B_log("DEBUG","UMASK in: $fullpath : $currentsetting");
                    if ($currentsetting eq 'Not Unique') {
                        return INCONSISTENT();
                    } elsif (($lastsetting eq 'Initialized Setting')) {
                        $lastsetting = $currentsetting;
                    }
                    if (($lastsetting ne $currentsetting)) {
                        return INCONSISTENT();
                    }
                }
            }
            &B_log("DEBUG","Umask profiles set at $currentsetting");
            if (($HPUXSpecificUmask ne $currentsetting) and
                (defined($HPUXSpecificUmask)) and
                (defined($currentsetting))) {
                return INCONSISTENT();
            } elsif ((not(defined($HPUXSpecificUmask))) and
                     (&GetDistro =~ "^HP-UX11.(.*)" and $1>20)){
                return STRING_NOT_DEFINED();
            } elsif (not(defined($currentsetting))){
                return STRING_NOT_DEFINED();
            } else {
                return (SECURE_CAN_CHANGE(), $currentsetting);
            }
        }
      };
      $GLOBAL_TEST{'AccountSecurity'}{'umask'} = \&test_umask;

} #End new tests for HP-UX

  sub test_password_strength_linux {

      return SECURE_CANT_CHANGE();

      # This question doesn't make sense if pam.d/passwd isn't present
      my $pamd_passwd_file = &getGlobal('FILE','pamd_passwd');
      unless ( -f $pamd_passwd_file ) {
	  &B_log('WARNING',
		 "$pamd_passwd_file is not present -- contact a Bastille ".
		 "developer if this is an unsupported platform.\n");
	  return SECURE_CANT_CHANGE();
      }

	# Make sure our pam_passwdqc.so line is there
        if (! &B_match_line($pamd_passwd_file,
            'password required\s+pam_passwdqc.so\s+min=disabled,disabled,disabled,disabled,8\s+random=0\n') ) {
            return NOTSECURE_CAN_CHANGE();
        }
        return SECURE_CANT_CHANGE();
  };
$GLOBAL_TEST{'AccountSecurity'}{'password_strength_linux'} = \&test_password_strength_linux;

# Test at/cron
# We consider at/cron secure in two situations (cron as example)
# 1. neither cron.allow nor cron.deny exists
# 2. cron.allow exists
#    cron.allow only contains "root" account
#    cron.allow root:sys
#    cron.allow permission 0400

sub test_at_or_cron_users ($) {
        
        my $at_cron = $_[0];
        
        if ($at_cron !~ /at/ && $at_cron !~ /cron/ ) {
                return NOTSECURE_CAN_CHANGE(); 
        }
        my $deny = $_[0] . ".deny";
        my $allow = $_[0] . ".allow";
        
        my $denyFile = &getGlobal('FILE', $deny);
        my $allowFile = &getGlobal('FILE', $allow);
        
        if (-e $allowFile) {
                # The file owner and group should be root:sys
                unless (&B_check_owner_group($allowFile, 'root', 'sys')) {
                        return NOTSECURE_CAN_CHANGE();
                }
                # The file permission should be "0400".
                unless ( &B_check_permissions($allowFile, 0400) ) {
                        return NOTSECURE_CAN_CHANGE();
                }
                # Check if "root" is the only account in the allow file.
                unless ( &B_match_line_only($allowFile, '^root$')) {
                        return NOTSECURE_CAN_CHANGE();
                }
                # The allow file exists and it's secure
                return SECURE_CANT_CHANGE();
        } else {
                # If no allow file, the deny file should not exist.
                if ( -e $denyFile) {
                        return NOTSECURE_CAN_CHANGE();
                }
                # Neither allow file nor deny file exists, and so it's secure
                        return SECURE_CANT_CHANGE();
        }
}

#
# CIS implmentation cronuser atuser
# 
sub test_cronuser {
    return &test_at_or_cron_users('cron');
};
$GLOBAL_TEST{'AccountSecurity'}{'cronuser'} = \&test_cronuser;

sub test_atuser {
    return &test_at_or_cron_users('at');
};
$GLOBAL_TEST{'AccountSecurity'}{'atuser'} = \&test_atuser;

#
# CIS implmentation crontabs
# 
sub test_crontabs_file {
        my $crontabs_dir = &getGlobal("DIR","crontabs");
        my $ls = &getGlobal("BIN","ls");
        my $null = &getGlobal("FILE", "null");
        my @files = `$ls $crontabs_dir 2>$null`;
        if ( ($? >> 8) != 0 ) {
                &B_log("DEBUG", "# sub test_crontabs_file failed  for backtick " .  "$ls $crontabs_dir 2>$null");
                return INCONSISTENT();
        }
        foreach my $file (@files) {
                chomp $file;
                $file = $crontabs_dir . "/" . $file;
                if ( ! &B_check_owner_group($file, 'root', 'sys') )  {
                        return NOTSECURE_CAN_CHANGE();
                }
                if (! &B_check_permissions($file, 0400) ){
                        return NOTSECURE_CAN_CHANGE();
                }
        }
        return SECURE_CANT_CHANGE();
}
$GLOBAL_TEST{'AccountSecurity'}{'crontabs_file'} = \&test_crontabs_file;

#
# CIS implmentation user_rc_files
# 
sub test_user_rc_files {
        my @homes = &B_find_homes();
        foreach my $home (@homes) {
                if ( -e "$home/.netrc" || -e "$home/.rhosts" || -e "$home/.shosts" ){
                        return NOTSECURE_CAN_CHANGE();
                }
        }
        return SECURE_CANT_CHANGE();
}
$GLOBAL_TEST{'AccountSecurity'}{'user_rc_files'} = \&test_user_rc_files;

#
# CIS implmentation user_dot_files
# 
sub test_user_dot_files {
        # find loginable homes
        my @homes = &B_find_homes();
        my $ls = &getGlobal("BIN","ls");
        foreach my $home (@homes) {
                if ( ! -e $home) {
                        next;
                }
                my $null =&getGlobal("FILE", "null");
                my @dotfiles =`$ls -d $home/.[!.]* 2>&1`;
                
                # /home/dotfile/ has no files lick .dotfile
                if ( ($? >> 8) != 0  && $dotfiles[0] =~ /not found/ ) {
                        next;
                }
                elsif ( ($? >> 8) != 0 ) {
                        &B_log("DEBUG", "# sub test_user_dot_files failed  for backtick " .  "$ls -d $home/.[!.]* 2>$null");
                        return INCONSISTENT();
                }
                foreach my $dot (@dotfiles) {
                        chomp $dot;
                        # $dot is not a link and ...
                        if ( ! -l $dot  && -f $dot ) {
                                if ( &B_permission_test("group","w",$dot) ) {
                                        return NOTSECURE_CAN_CHANGE();
                                }
                                if ( &B_permission_test("other","w",$dot) ) {
                                        return NOTSECURE_CAN_CHANGE();
                                }
                        }
                }
        }
        return SECURE_CANT_CHANGE();
}
$GLOBAL_TEST{'AccountSecurity'}{'user_dot_files'} = \&test_user_dot_files;

#
# CIS implmentation restrict_home
# 
sub test_restrict_home {
        my $retval = 0;
        # find loginable homes
        my @homes = &B_find_homes();
        my $roothome = (getpwnam("root"))[7];
        foreach my $home (@homes) {
                chomp($home);
                # roothome wil lnot be restricted. 
                if ($home eq $roothome) {
                        next;
                }
                #if $home is group writable or other-r or other-w or other-x, then it is not secure
                if ( &B_permission_test("group","w",$home) ) {
                        return NOTSECURE_CAN_CHANGE();
                }
                if ( &B_permission_test("other","r",$home) ) {
                        return NOTSECURE_CAN_CHANGE();
                }
                if ( &B_permission_test("other","w",$home) ) {
                        return NOTSECURE_CAN_CHANGE();
                }
                if ( &B_permission_test("other","x",$home)){
                        return NOTSECURE_CAN_CHANGE();
                }
        }
        return SECURE_CANT_CHANGE();
}
$GLOBAL_TEST{'AccountSecurity'}{'restrict_home'} = \&test_restrict_home;

#
# CIS implmentation lock_account_nopasswd
# 
sub test_lock_account_nopasswd{
        my $logins = &getGlobal("BIN", "logins");
        my $null = &getGlobal("FILE", "null");
        my @entries = `$logins -ox 2>$null`;
        if ( ($? >> 8) != 0 ) {
                &B_log("DEBUG", "# sub test_lock_account_nopasswd failed  for backtick " .  "$logins -ox 2>$null");
                return INCONSISTENT();
        }
        if ( @entries )  {
                foreach my $entry ( @entries ) {
                        chomp($entry);
                        my @data = split(/:/,$entry);
                        if ( $data[7] =~/NP/ ) {
                                return NOTSECURE_CAN_CHANGE();
                        }
                }      
        }
        
        return SECURE_CANT_CHANGE();
}
$GLOBAL_TEST{'AccountSecurity'}{'lock_account_nopasswd'} = \&test_lock_account_nopasswd;

#
# CIS implmentation serial_port_login
# 
sub test_serial_port_login {
        
        my $inittab = &getGlobal("FILE", "inittab");
        
        if ( &B_match_line($inittab, '^[^#].*getty.*tty.*$')
        ) {
                return NOTSECURE_CAN_CHANGE();
        }
        
        #
        # should we also check process getty?
        # isProcessRunning   
        # root  3243     1  0 21:10:36 ?         0:00 /usr/sbin/getty -h tty0p1 9600
        if ( &isProcessRunning('getty -h tty') ) {
                return NOTSECURE_CAN_CHANGE();
        }
        
        #if ( &B_permission_test("other","w" , $inittab)
        #        || &B_permission_test("group","w", $inittab)
        #        || &B_permission_test("","suid", $inittab)
        #        || &B_permission_test("","sgid", $inittab)) {
        #        return NOTSECURE_CAN_CHANGE();
        #}
        #
        #unless (&B_check_owner_group($inittab, "root", "sys")) {
        #        return NOTSECURE_CAN_CHANGE();  
        #}
        
        return SECURE_CANT_CHANGE();
}
$GLOBAL_TEST{'AccountSecurity'}{'serial_port_login'} = \&test_serial_port_login;

# 
# CIS item 3.4 test
#
sub test_gui_login  {

        my $desktop = &B_get_rc("DESKTOP");
        if (  $desktop =~ /CDE/ ) {
                return NOTSECURE_CAN_CHANGE();
        }
        # sub B_is_service_off($;$){}
        #
        #  should we also check process dtlogin and dtrc?
        #  isProcessRunning

        if (&isProcessRunning( '/dtlogin|dtrc/' )) {
                return NOTSECURE_CAN_CHANGE();
        }
        foreach my $service ('xfs', 'audio', 'slsd'){
                if ( (&B_is_service_off($service) != SECURE_CANT_CHANGE) and
                     (&B_is_service_off($service) != NOT_INSTALLED) ) {
                        return NOTSECURE_CAN_CHANGE();
                }
        }

        return SECURE_CANT_CHANGE();
}
$GLOBAL_TEST{'AccountSecurity'}{'gui_login'} = \&test_gui_login;

#
# CIS item root_path test
#
sub test_root_path {
	&B_log("ACTION","# test root_path\n");
	my $global_remediated=0;  # flag: Bastille has already remediated bad global PATH 

	# start with global profile file
        my $files = [ &getGlobal("FILE","profile") ];
        
	my $roothome = (getpwnam("root"))[7];
	# if root's home is not "/".  the the home directory get from getpwnam will like this: /home/root
        # robert found it
        if ( $roothome ne "/" ) {
            $roothome .= "/";
        }
	my $localprofile = $roothome . ".profile";

        if ( -e $localprofile )	{
            push @$files, $localprofile ; 
	    # check local profile for Bastille remediation of bad global PATH
            $global_remediated = &B_match_line( $localprofile, '^# BASTILLE #: static PATH .* /etc/profile'); 
	}
        
        for my $file (@$files) {
                my @path_arr = &B_get_path($file);
                if (@path_arr)  {
                        for my $dir (@path_arr) {
                                if ( $dir eq "."
                                || &B_permission_test("group", "w", $dir)
                                || &B_permission_test("other", "w", $dir)) {
					&B_log("ACTION","# PATH component: $dir from sourcing file: $file is not secure.\n");
					if ( $file eq $localprofile ) { 
                                           return NOTSECURE_CAN_CHANGE();  
					} else { # global profile file
					   return NOTSECURE_CAN_CHANGE()  unless ( $global_remediated );
					}
                                }  
                        }     
                }
                
        }
        return SECURE_CANT_CHANGE();
}
$GLOBAL_TEST{'AccountSecurity'}{'root_path'} = \&test_root_path;

#
# CIS implementation block_system_accounts
#
sub test_block_system_accounts {
        my @userlist = qw | www sys smbnull
                iwww owww sshd
                hpsmh named uucp
                nuucp adm daemon
                bin lp nobody noaccess hpdb useradm|;
        my $false = &getGlobal("BIN","false");
        my $false2 = "/bin/false";
        for my $user (@userlist) {
                if (my ($password, $shell) = (getpwnam($user))[1,8] ) {
                        # if the acount is not blocked then it is not secure
                        if ( ($password !~ /^\*$/) or ($shell !~ /$false|$false2/) ) {
                                return NOTSECURE_CAN_CHANGE();
                        }
                }
        }
        return SECURE_CANT_CHANGE();
}
$GLOBAL_TEST{'AccountSecurity'}{'block_system_accounts'} = \&test_block_system_accounts;

#
# CIS implementation unowned_files
#
sub test_unowned_files {
	my $find = &getGlobal("BIN","find");
	my $null = &getGlobal("FILE", "null");
	
	# optional list of dirs that $find should not descend (via -prune)
	my $avoid_paths="";
       	if (&GetDistro =~ '^HP-UX11.31SRPcont') {
		$avoid_paths="-o -path /stand -o -path /sbin -o -path /usr" ;
	} elsif (&GetDistro =~ '^HP-UX11.31SRPhost') {
		$avoid_paths="-o -path /var/hpsrp" ;
	} else {
		# empty
	}

        my @files  = `$find / \\\( -fstype nfs $avoid_paths \\\) -prune -o \\\( -nouser -o -nogroup \\\) -print  2>$null`;
        # my $find2perl = &getGlobal("BIN","find2perl");
        # my $code = `$find2perl / \( -nouser -o -nogroup \) ! -fstype nfs  -print  2>$null`;
        # eval $code;
        
	if ( ($? >> 8) != 0 ) {
                &B_log("DEBUG", "# test_unowned_files failed for backtick " . "$find / -fstype nfs -prune -o \\\( -nouser -o -nogroup \\\) -print  2>$null"); 
		return  INCONSISTENT()
	}
	if (@files) {
		return NOTSECURE_CAN_CHANGE();
	}
	return SECURE_CANT_CHANGE();
}
$GLOBAL_TEST{'AccountSecurity'}{'unowned_files'} = \&test_unowned_files;

sub mesgn_test($) {
        my $profile = shift;
        my $fullpath = &getGlobal('FILE', $profile);
        if (-e $fullpath ) {
                # "mesg n" should be matched.
                unless ( &B_match_line($fullpath, '^\s*mesg n$')) {
                        return NOTSECURE_CAN_CHANGE();
                }
                # "mesg y" or "mesg g" should not be matched.
                if ( &B_match_line($fullpath, '^\s*mesg\s+[yg]')) {
                        return NOTSECURE_CAN_CHANGE();
                }
        }
        return SECURE_CANT_CHANGE();
}


#
# CIS implementation mesgn
#
# Test mesg n
# "mesg n" should be the default setting for all users
sub test_mesgn {
        # Check four files.
        my @filelist = ('profile', 'csh.login', 'd.profile', 'd.login');
        for my $file (@filelist) {
                unless ( &mesgn_test($file) ) {
                        return NOTSECURE_CAN_CHANGE();
                }
        }
        return SECURE_CANT_CHANGE();
};
$GLOBAL_TEST{'AccountSecurity'}{'mesgn'} = \&test_mesgn;

  sub test_umaskyn {
       	if (&GetDistro =~ '^HP-UX') {
	    my @umaskTestReturn = &{$GLOBAL_TEST{'AccountSecurity'}{'umask'}};
            if ($umaskTestReturn[0] == SECURE_CAN_CHANGE()){
                return RELEVANT_HEADERQ();
            } else {
                return NOTRELEVANT_HEADERQ();
            }
        }

        &B_log("DEBUG","Performing Profile umask test");
        # This logic depends on the incoming CONFIG; not sure this is desired
        # for an "audit," and I don't think we do it anywhere else.
	my $reqdumask = &getGlobalConfig('AccountSecurity', 'umask');
	my @filelist = ('profile', 'rootprofile', 'zprofile', 'csh.login');
	if (&GetDistro =~ '^OSX') {
	    @filelist = ('profile', 'csh.login');
	}

        # Check each startup file for the corect umask setting.
        for my $startupfile (@filelist) {
            my $fullpath = &getGlobal('FILE', $startupfile);
	    if ( -e $fullpath ) {
               	if (! &B_match_line($fullpath, '^\s*umask\s+' . $reqdumask)) {
                    return NOTSECURE_CAN_CHANGE();
                }
	    }
        }
	return SECURE_CAN_CHANGE();

	# The following was here, on the non-HPUX case, but doesn't work on non-HPUX systems...unless
	# Bastille is no longer respecting REQUIRE_DISTRO on HP-UX.  JJB: consider investigating.
        # return &secureIfNoNameService(SECURE_CANT_CHANGE());
  };
$GLOBAL_TEST{'AccountSecurity'}{'umaskyn'} = \&test_umaskyn;



#Linux Question
  sub test_rootttylogins {
	my $tty;

        if ( -e '/etc/securetty' ) {
            # Check for forbidden lines.
            foreach $tty (1, 2, 3, 4, 5, 6, 7, 8, 9, 0) {
	        if (&B_match_line('/etc/securetty', "tty$tty")) {
                    return NOTSECURE_CAN_CHANGE();
                }
                if (&B_match_line('/etc/securetty', "vc/$tty")) {
                    return NOTSECURE_CAN_CHANGE();
                }
            }
        }
        else {
            # If the file /etc/securetty does not exist, root can log in
            # from anywhere!
            return NOTSECURE_CAN_CHANGE();
        }

	# Check that root cannot login in via xdm, gdm, or kdm.
        # TODO: There are more was to prevent root logins, and code should be
        # added to check for these as well.  What is done here is just check
        # what Bastille would have done.
        if ( -e '/etc/bastille-no-login' ) {
            unless (&B_match_line('/etc/bastille-no-login', 'root') ) {
                return NOTSECURE_CAN_CHANGE();
            }
            if ( -e '/etc/pam.d/xdm') {
                unless (&B_match_line('/etc/pam.d/xdm',
                                      'auth\s+required\s+/lib/security/pam_listfile.so\s+onerr=succeed\s+item=user\s+sense=deny\s+file=/etc/bastille-no-login')
                                     ) {
                    return NOTSECURE_CAN_CHANGE();
                }
            }
            if ( -e '/etc/pam.d/gdm') {
                unless (&B_match_line('/etc/pam.d/gdm',
                                      'auth\s+required\s+/lib/security/pam_listfile.so\s+onerr=succeed\s+item=user\s+sense=deny\s+file=/etc/bastille-no-login')
                                     ) {
                    return NOTSECURE_CAN_CHANGE();
                }
            }
            if ( -e '/etc/pam.d/kde') {
                unless (&B_match_line('/etc/pam.d/kde',
                                      'auth\s+required\s+/lib/security/pam_listfile.so\s+onerr=succeed\s+item=user\s+sense=deny\s+file=/etc/bastille-no-login')
                                     ) {
                    return NOTSECURE_CAN_CHANGE();
                }
            }
        }
        return SECURE_CANT_CHANGE();
  };
$GLOBAL_TEST{'AccountSecurity'}{'rootttylogins'} = \&test_rootttylogins ;



#Linux question
  sub test_forbiduserview {
      # Get our config file locations.
      my $kdmrc = &getGlobal('FILE','kdmrc');
      my $gdmconf = &getGlobal('FILE','gdm.conf');

      # If this is an older kdmrc, it'll use a UserView line.
      if (&B_match_line($kdmrc, '^\s*UserView\s*=\s*true')) {
	  return NOTSECURE_CAN_CHANGE();
      }
      # If this is a kdmrc that is new enough for a ShowUsers line, confirm that it is
      # set to 'None', since this is not the default.
      if (&B_match_line($kdmrc,'ShowUsers') ) {
	  unless (&B_match_line($kdmrc,'^\s*ShowUsers\s*=\s*None')) {
	      return NOTSECURE_CAN_CHANGE();
	  }
      }
      # Check on gdm's Browser line.  Older gdm.conf's use 0/1, newer use True/False.
      if ( &B_match_line($gdmconf, '^\s*Browser\s*=\s*1')) {
	  return NOTSECURE_CAN_CHANGE();
      }
      if ( &B_match_line($gdmconf, '^\s*Browser\s*=\s*true')) {
	  return NOTSECURE_CAN_CHANGE();
      }
      return SECURE_CANT_CHANGE();
  };
$GLOBAL_TEST{'AccountSecurity'}{'forbiduserview'} = \&test_forbiduserview;


#linux Question
    sub test_removeaccounts {
	# We need to check if specific extra accounts have been removed on specific
	# operating systems.

        # This question was written as part of the Fort Knox Linux project, where
        # the suggested deleted accounts were:

        # Red Hat Enterprise Linux 3: gopher, games
        # SuSE Enterprise 9: games, uucp"

	# Don't force this on any systems
	if (&GetDistro !~ /RHEL/ and &GetDistro !~ /SESLES/) {
	    return SECURE_CANT_CHANGE();
	}

	my @users_to_check;
	if (&GetDistro =~ /RHEL/) {
	    @users_to_check = ('gopher','games');
	}
	else {
	    @users_to_check = ('games','uucp');
	}
	# Loop through looking for illegal users
	foreach $user (@users_to_check) {
	    if (&B_match_line('/etc/passwd',"^\\s*$user\\s*:")) {
		return NOTSECURE_CAN_CHANGE();
	    }
	}
	return SECURE_CANT_CHANGE();
    };
$GLOBAL_TEST{'AccountSecurity'}{'removeaccounts'} = \&test_removeaccounts;


#linux
    sub test_removegroups {
	# We need to check if specific extra groups have been removed on specific
	# operating systems.

        # This question was written as part of the Fort Knox Linux project, where
        # the suggested deleted groups were:

        # SuSE Enterprise 9: games, modem, xok"

	# Don't force this on any systems
	if (&GetDistro !~ /SESLES/) {
	    return SECURE_CANT_CHANGE();
	}

	my @groups_to_check = ('games','modem','xok');

	# Loop through looking for illegal groups
	foreach $group (@groups_to_check) {
	    if (&B_match_line('/etc/group',"^\\s*$group\\s*:")) {
		return NOTSECURE_CAN_CHANGE();
	    }
	}
	return SECURE_CANT_CHANGE();
    };
$GLOBAL_TEST{'AccountSecurity'}{'removegroups'} = \&test_removegroups;



1;
