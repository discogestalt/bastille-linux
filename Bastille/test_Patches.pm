# Copyright (C) 2006-2007 Hewlett Packard Development Company, L.P.
# Licensed under the GNU General Public License, version 2

use Bastille::API;
use Bastille::API::FileContent;

sub SPCWasRun {
    my $SWAOutput = &getGlobal('BFILE',"required_security_actions");
    my $patchLoc = &getGlobal('BFILE',"required_security_patches");
    if ((-f $SWAOutput ) or (-f $patchLoc )) {
        return 1; #True
    } else {
        return 0; #False
    }
}

sub SPCWillRun {
    my $chrc = &getGlobal("BIN","ch_rc");
    my $SPCLevelStatus = &B_Backtick("$chrc -l -p SPC_LEVEL_CHECK ") ;
    if ( $SPCLevelStatus =~ "yes") { #SPC will run later
        return 1; #true
    } else {
        return 0; #false
    }
}

sub test_spc_run {
    # in case run is queued, we still want the config to say yes
    # to avoid a) drift detection case, and b) use of the config baseline
    # not running spc / swa on the target system.
    if (&SPCWasRun or &SPCWillRun) { 
        return SECURE_CAN_CHANGE();
    } else {
        return NOTSECURE_CAN_CHANGE();
    }
};
$GLOBAL_TEST{'Patches'}{'spc_run'} = \&test_spc_run;

my $spcCronRegex = '(\d+ \d* (?:\* ){3}\(umask \d+; export .*security_patch_check -r|'.
	'\d+ \d* (?:\* ){3}\( .*bastilleSWA\.sh)';
sub test_spc_cron_norun {
    return &SingleReturnForSPC($spcCronRegex);
};
$GLOBAL_TEST{'Patches'}{'spc_cron_norun'} = \&test_spc_cron_norun;
$GLOBAL_TEST{'Patches'}{'spc_cron_run'} = \&test_spc_cron_norun;

my $oldcronTimeRegex='\d+ (\d*) (?:\* ){3}\(umask \d+; export .*security_patch_check -r';
my $newcronTimeRegex='\d+ (\d*) (?:\* ){3}\( .*bastilleSWA\.sh';
sub test_spc_cron_time {
	&twoCronValReturn($newcronTimeRegex, $oldcronTimeRegex)
};
$GLOBAL_TEST{'Patches'}{'spc_cron_time'} = \&test_spc_cron_time;


my $oldproxyRegex='\d+ \d* (?:\* ){3}\(umask \d+;.*export \w+_proxy=(.+);.*security_patch_check -r';
my $newproxyRegex='\d+ (\d*) (?:\* ){3}\(export PROXY=(.+).*bastilleSWA\.sh';
sub test_spc_proxy {
    return &twoCronValReturn($newproxyRegex, $oldproxyRegex);
};
$GLOBAL_TEST{'Patches'}{'spc_proxy'} = \&test_spc_proxy;


sub test_spc_proxy_yn {  
	my $result = &SingleReturnForSPC($newproxyRegex);
	if ($result == NOTSECURE_CAN_CHANGE()){
		return &SingleReturnForSPC($oldproxyRegex);
	} else {
		return $result;
	}
};
$GLOBAL_TEST{'Patches'}{'spc_proxy_yn'} = \&test_spc_proxy_yn;

sub twoCronValReturn($$){
	my $firstRegex = $_[0];
	my $secondRegex = $_[1];
	
	my @result = &getSPCValues($firstRegex);
	if ($result[0] == NOTSECURE_CAN_CHANGE()){
		return &getSPCValues($secondRegex);
	} else {
		return @result;
	}
}
sub SingleReturnForSPC($){
    my $cronRegex = $_[0];
    my @spcValResult = &getSPCValues($cronRegex);
    my $specificResult=$spcValResult[0];

    if ($specificResult == STRING_NOT_DEFINED()) {# "snd" only for "value" strings
        return NOTSECURE_CAN_CHANGE(); 
    } else {
        return $spcValResult[0]; # we don't want the actual command to show up
    }
}

#Given a reguar expression to look for in the crontab,
#return the right exit code, and value

sub getSPCValues($){# removed install check as that causes the value questions to be
                    # skipped even though we do allow SPC cron setup *without SPC present*
    my $regex = $_[0];
    my $spc = &getGlobal("FILE","spc");
    my $crontab = &getGlobal("BIN","crontab");
    my $commandResults = &B_Backtick("$crontab -l root");

    $searchResults = &B_getValueFromString("$regex", "$commandResults");
    if ((defined($searchResults)) and ($searchResults ne "Not Unique")) {
        return (SECURE_CAN_CHANGE(),$searchResults);
    } elsif ($searchResults eq "Not Unique") {
        return INCONSISTENT();
    } else {
        return STRING_NOT_DEFINED();
    }
}

1;
