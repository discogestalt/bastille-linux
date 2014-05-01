# Copyright (C) 2005 Jay Beale
# Copyright (C) 2005 Charlie Long, Delphi Research
# Copyright (C) 2006 Hewlett Packard Development Company, L.P.
# Licensed under the GNU General Public License, version 2


use Bastille::API;
use Bastille::API::ServiceAdmin;
use Bastille::API::FileContent;

if (&GetDistro =~ /HP-UX/) {

$GLOBAL_TEST{'Logging'}{'morelogging'} =
    sub {

	my $syslog = &getGlobal('FILE','syslog.conf');
	my $syslogretval = SECURE_CANT_CHANGE(); 

	#We don't want to ding people for missing err

	# Check /var/log/syslog for three things...
	# Log all messages that are at the "err" severity level and above.
	
	#if (! &B_match_line($syslog,"\.err.*\t")) {
	#	$syslogretval = NOTSECURE_CAN_CHANGE();
	#}
		### Check kern\.
	# Log all kernel messages.
	if (! &B_match_line($syslog,"kern[,.].*\t")) {
		$syslogretval = NOTSECURE_CAN_CHANGE();
	}
		### Check ^[^\#]*auth\.    AND    user\.    AND   daemon\.    
		## Make them OR  and then put a comment in the code that says:
		## TODO: Check whether all three of these are actually necessary.
	# Get information about logins, especially failed ones.
	elsif (! &B_match_line($syslog,"authpriv[,.].*\t")) {
		$syslogretval = NOTSECURE_CAN_CHANGE();
	}
	return $syslogretval;
};

#This logs for process accounting

$GLOBAL_TEST{'Logging'}{"pacct"} =
    sub {
	if (&GetDistro =~ /^SE/) {
	    return ( ! &B_is_service_off('acct') );
	}
	if (&GetDistro =~ "^RH") 
	{
	    # First check if the psacct init.d script is active.
	    if ( ! &B_is_service_off('psacct') ) {
		return SECURE_CANT_CHANGE();
	    }
	    # If it's not, check rc.local for accton.
	    my $rclocal = &getGlobal('FILE','rc.local');
	    if (&B_match_line($rclocal,'accton')) {
		return SECURE_CANT_CHANGE();
	    }
	    # If neither of these is true, ask the question.
	    return NOTSECURE_CAN_CHANGE();
	}
    };

#This checks for Laus.  RedHat Enterprise has taken out of their distro
#so we are not worried about it.  We will use auditd later

$GLOBAL_TEST{'Logging'}{"laus"} =
    sub {
	my $sysctlconf = &getGlobal('FILE',"sysconfig_audit");
	my $sysctl = SECURE_CANT_CHANGE();

	if (&GetDistro !~ /^SESLES/) {
		return SECURE_CANT_CHANGE();
	}
	
	#Doesn't seem to be working with SUSE

        ## Check whether /etc/init.d/audit is on
	#if (&B_is_service_off('audit')) {
	#    return SECURE_CANT_CHANGE();
	#}

	#check /etc/sysconfig/audit for LaUS-related audting
	if (! &B_match_line("$sysctlconf","AUDIT_ALLOW_SUSPEND=1")) {
		$sysctl = NOTSECURE_CAN_CHANGE();
	} 
	elsif (! &B_match_line("$sysctlconf","AUDIT_ATTACH_ALL=0")) {
		$sysctl = NOTSECURE_CAN_CHANGE();
	} 
	# Check for 1024 or better (higher/lower?)
	# Follow-up comment, code doesn't appear to match this comment
	elsif (! &B_match_line("$sysctlconf","AUDIT_MAX_MESSAGES=1024")) {
		$sysctl = NOTSECURE_CAN_CHANGE();
	} 
	elsif (! &B_match_line("$sysctlconf","AUDIT_PARANOIA=0")) {
		$sysctl = NOTSECURE_CAN_CHANGE();
	} 
	
	return $sysctl; 
    };

} # HP-UX "ifdef"

1;
