# Copyright (C) 2001-2003, 2006-2007 Hewlett-Packard Development Company, L.P.
# Licensed under the GNU General Public License, version 2
#  $Id: Patches.pm,v 1.39 2008/04/17 00:52:21 fritzr Exp $
package Bastille::Patches;

use Bastille::API;
use Bastille::API::HPSpecific;
use Bastille::API::FileContent;

@ENV="";
$ENV{PATH}="";
$ENV{CDPATH}=".";
$ENV{BASH_ENV}="";

delete $ENV{BASH_ENV};


#######################################################################
##                          Patches Module                            #
#######################################################################
#
# The purpose of this module is to Install Security Patch Check and/or
# configure it.

&InstallSWA;
&SpcRun;
&CronSPC;

sub installSwaTodo {
    my $swa_install_text =
	    "\n---------------------------------\n" .
	    "Software Assistant:\n" .
	    "---------------------------------\n" .
	    "Patching known security vulnerabilities is one of the most\n" .
	    "important steps you can take to secure a system. Software\n" .
	    "Assistant is a tool which analyzes the software installed\n" .
	    "on your system.  It will tell you if any relevant security\n" .
	    "bulletins have been announced by Hewlett Packard whose recommended actions\n" .
	    "have not yet been applied to your system.  Bastille has detected\n" .
	    "that you have not installed this tool.\n\n" .

	    "Please install Software Assistant.  You can get it at:\n" .
	    "   http://www.hp.com/go/swa\n".
	    "or alternatively, go to www.software.hp.com and select the security product category.\n";

	&B_TODO($swa_install_text);
}

sub InstallSWA {
    my $swa = &getGlobal('BIN','swa');
    if ( &GetDistro =~ "^HP-UX" and !( -e $swa ) ) {
	&B_log("DEBUG","# sub InstallSWA\n");
	&installSwaTodo;
    }
}

# To successfully run SWA/SPC in the cron and at Bastille run-time

sub SpcRun {
    my $spc = &getGlobal('FILE','spc');
    my $swa = &getGlobal('BIN','swa');
    
    if ((&getGlobalConfig("Patches","spc_run") eq "Y")) {
        &B_log("DEBUG","# sub SpcRun\n");
	my $proxy = "";
	if(&getGlobalConfig("Patches","spc_proxy_yn") eq "Y") {
	    $proxy = &getGlobalConfig("Patches","spc_proxy");
	}

	if ($proxy ne "") {           # set proxy variable to the user's answer if one exists
	    $proxy = "export PROXY=" . $proxy . "; ";
	}
	if (not((-f $spc) or (-f $swa))) {
	    &installSwaTodo;
	} else {
	    &B_TODO("\n---------------------------------\nApply Security Bulletins:\n" .
		"---------------------------------\n" .
		"Please read the security bulletin information that has been placed\n" .
		"in the following file and apply as appropriate:\n\t" .
		&getGlobal('BFILE',"required_security_actions") . "\n\n" .
		"It is also recommended that you subscribe to the HP Security\n" .
		"Bulletin mailing list\n\n","Patches.spc_run");

	my $bastilleSWA = &getGlobal('BFILE','bastilleSWA');
	my $bultnInfo = &B_Backtick("$proxy $bastilleSWA 2>&1 \n\n");

	&B_create_file(&getGlobal('BFILE',"required_security_actions"));
	&B_blank_file(&getGlobal('BFILE',"required_security_actions"), 'a$b');
	&B_append_line(&getGlobal('BFILE',"required_security_actions"),'a$b',$bultnInfo);
	}
    }
}

sub CronSPC {
    if ((&getGlobalConfig("Patches","spc_cron_run") eq "Y") ||
	(&getGlobalConfig("Patches","spc_cron_norun") eq "Y")) {
        &B_log("DEBUG","# sub CronSPC\n");
	
	my $spc = &getGlobal('FILE','spc');
	my $swa = &getGlobal('BIN','swa');
	if (not((-f $spc) or (-f $swa))) {
	    &installSwaTodo;
	}
	
	my $proxy = "";
	if(&getGlobalConfig("Patches","spc_proxy_yn") eq "Y") {
	    $proxy = &getGlobalConfig("Patches","spc_proxy");
	}

	if ($proxy ne "") {      # set proxy variable to the user's answer if one exists
	    $proxy = "export PROXY=" . $proxy . "; ";
	}


    my $mailprogram = &getGlobal('BIN','mail');
    my $uname = &getGlobal('BIN','uname');
	my $unameInfo = &B_Backtick("$uname -n");
	chomp $unameInfo;
    my $emailAddr='root@localhost';
	my $emailSub="Bulletin Compliance Results for $unameInfo";

	srand; # seed the random number generator (should this use system time?)
               # this is to prevent everyone from trying to access the ftp server
	       # at the same time.
	my $minute = int(rand(60));

	# set up the cron file for root
    my $bastilleSWA=&getGlobal('BFILE','bastilleSWA');
    my $line = "$minute " . &getGlobalConfig("Patches", 'spc_cron_time') .
                   " * * * ($proxy $bastilleSWA 2>&1 | " .
		   	   "$mailprogram -s \"$emailSub\" $emailAddr )";
	# B_Schedule will now replace *all* matches in cron with a *single* replacement	   	   
	&B_Schedule("$spc|$bastilleSWA",$line); 

    }
}

1;
