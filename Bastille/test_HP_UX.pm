# Copyright (C) 2002-2003,2006, 2008 Hewlett Packard Development Company, L.P.
# Licensed under the GNU General Public License, version 2

use Bastille::API::HPSpecific;
use Bastille::API::ServiceAdmin;
use Bastille::API::FileContent;

# These tests are specific to the HP_UX module

    sub test_stack_execute {
      # checking to see if the executable_stack bit
      # is set to zero

	my $exportpath=&getGlobal('BIN',"umask") ." 077; export PATH=/usr/bin;";
	my $kmtune = &getGlobal('BIN', "kmtune");       #kmtune's path
	my $kctune = &getGlobal('BIN', "kctune");       #kctune's path
	my @kmq;     # will hold executable stack query information
	my @kmexecq; #

	# get the current kernel parameter information...
        if ( -x "$kctune") {
	    @kmq=`$exportpath $kctune -q executable_stack -P current,next_boot`;
            # @kmq will contain values of executable stack in this format:
            # current 0
            # next_boot       0

            # Put the whole thing into an array
	    @kmexecq = split /\s+/, "@kmq";
        } else {
	    @kmq = `$exportpath $kmtune -q executable_stack`;
            # @kmq will contain values of executable stack in this format:
            #Parameter             Current Dyn Planned             Module
            #============================================================
            #executable_stack            0  Y  0

            # Put only the first matching line into an array (assuming there will be only one)
	    my @greppedkmq = grep(/executable_stack/, @kmq);
	    @kmexecq = split /\s+/, $greppedkmq[0];
        }

        # in both of the above cases, the results are in the same places in the
        # array
	if(($kmexecq[1] eq 0) and ($kmexecq[3] eq 0)){
	    #executable stack protection is  set
	    return SECURE_CANT_CHANGE();
	} elsif (($kmexecq[1] eq 1) and ($kmexecq[3] eq 0)) {
            # Protected execution available after next reboot
	    return MANUAL();
	} else {
            # Either not secure, or headed that way after next reboot.
            return NOTSECURE_CAN_CHANGE();
        }
  };
$GLOBAL_TEST{'HP_UX'}{'stack_execute'} = \&test_stack_execute;


  sub test_restrict_swacls {

      my $swagentd = &getGlobal('BIN',"swagentd");
      my $ps = &getGlobal('BIN',"ps");

      # is swagentd running
      my $isRunning= &isProcessRunning($swagentd);

      if($isRunning) {
	  my $swacl = &getGlobal('BIN','swacl');
	  my @host_swacl = `$swacl -l host`;
	  foreach my $definition (@host_swacl){
              # look for at least one non-'-' in any_other
              # by default this is a -r---
	      chomp $definition; #otherwise, \n matches as "non-dash" in regex
	      if($definition =~ /^any_other:.*[^-]+.*$/) {  # we have a winner
		  return NOTSECURE_CAN_CHANGE();
	      }
	  }

	  my @root_swacl = `$swacl -l root`;
	  foreach my $definition (@root_swacl){
              # look for at least one non-'-' in any_other
              # by default this is a -r---
	      chomp $definition; #otherwise, \n matches as "non-dash" in regex
	      if($definition =~ /^any_other:.*[^-]+.*$/) {  # we have a winner
		  return NOTSECURE_CAN_CHANGE();
	      }
	  }

	  return SECURE_CANT_CHANGE();
      } elsif (&B_TODOFlags('isSet','HP_UX.restrict_swacls')) {
        return MANUAL();
      } else {
        return INCONSISTENT();
      }

  };
$GLOBAL_TEST{'HP_UX'}{'restrict_swacls'} =\&test_restrict_swacls;

sub test_ndd{

    # get all current values (-A) starting with any of the given names
    my %diskParams = &readNDD;
    my $ndd_call = &getGlobal('BIN','ndd');


    my $retval = SECURE_CANT_CHANGE();
    for my $newNDDKey (keys %newNDD){
        my $nddGetValue = &B_Backtick("$ndd_call -get /dev/$newNDD{$newNDDKey}[0] $newNDDKey");
        chomp $nddGetValue;
        if (($nddGetValue ne $newNDD{$newNDDKey}[1]) or
            ( $diskParams{$newNDDKey}[1] ne $newNDD{$newNDDKey}[1])) {
            &B_log("DEBUG","ndd:$newNDDKey value:$nddGetValue != ". $newNDD{$newNDDKey}[1]);
            $retval = NOTSECURE_CAN_CHANGE();  # if the machine already has the proper ndd values
        }                      # then mark nddComplete.
    }
    return $retval;
};


$GLOBAL_TEST{'HP_UX'}{'ndd'} = \&test_ndd;

sub readNDD {
    my $ch_rc = &getGlobal('BIN','ch_rc');
    my $index = 0;
    my $transName = &B_getValueFromString('(\w+)', &B_Backtick("$ch_rc -l -p TRANSPORT_NAME[$index]"));
    my $nddname   = &B_getValueFromString('(\w+)', &B_Backtick("$ch_rc -l -p NDD_NAME[$index]"));
    my $nddvalue  = &B_getValueFromString('(\d+)', &B_Backtick("$ch_rc -l -p NDD_VALUE[$index]"));
    my %mynddEntries=();

    while ( (defined($transName)) and ($transName ne "Not Unique") and
          (defined($nddname)) and ($nddname ne "Not Unique") and
          (defined($nddvalue)) and ($nddvalue ne "Not Unique")){
        $mynddEntries{$nddname}=[$transName, $nddvalue];
        $index++;
        $transName = &B_getValueFromString('(\w+)', &B_Backtick("$ch_rc -l -p TRANSPORT_NAME[$index]"));
        $nddname   = &B_getValueFromString('(\w+)', &B_Backtick("$ch_rc -l -p NDD_NAME[$index]"));
        $nddvalue  = &B_getValueFromString('(\d+)', &B_Backtick("$ch_rc -l -p NDD_VALUE[$index]"));
    }
    return %mynddEntries;
}


#
# CIS implementation tcp_isn
#
sub test_tcp_isn {
    my $ndd = &getGlobal("BIN", "ndd");
    my $on = `$ndd -get  /dev/tcp tcp_isn_passphrase`;
    if ( $on =~ /0/ ) {
        return NOTSECURE_CAN_CHANGE();
    }
    if ( ! -e &getGlobal("BIN", "S339tcpisn") ) {
        return NOTSECURE_CAN_CHANGE();
    }
    return SECURE_CANT_CHANGE();
};
$GLOBAL_TEST{'HP_UX'}{'tcp_isn'} = \&test_tcp_isn;

#
# CIS implementation screensaver_timeout
#
sub test_screensaver_timeout {
    my @files = glob("/usr/dt/config/*/sys.resources");
    use File::Basename;
    foreach my $file (@files) {
        chomp $file;
        $file =~ s|^/usr/|/etc/|;
        if ( ! -e $file ) {
            return NOTSECURE_CAN_CHANGE();
        }
        if ( ! &B_match_line($file ,'dtsession\*saverTimeout:\s+\d+' )) {
            return NOTSECURE_CAN_CHANGE();
        }
        if ( ! &B_match_line($file ,'dtsession\*lockTimeout:\s+\d+')) {
            return NOTSECURE_CAN_CHANGE();
        }
    }
    return SECURE_CANT_CHANGE();
}
$GLOBAL_TEST{'HP_UX'}{'screensaver_timeout'} = \&test_screensaver_timeout;

#
# CIS implementation gui_banner
#
sub test_gui_banner {
    my @files = glob("/usr/dt/config/*/Xresources");
    my $banner="Authorized users only. All activity may be monitored and reported.";
    use File::Basename;
    foreach my $file (@files) {
        chomp $file;
        $file =~ s|^/usr/|/etc/|;
        if ( ! -e $file ) {
            return NOTSECURE_CAN_CHANGE();
        }
        if ( ! &B_match_line($file,'Dtlogin\*greeting\.labelString: ' . $banner)){
            return NOTSECURE_CAN_CHANGE();
        }
        if ( ! &B_match_line($file,'Dtlogin\*greeting\.labelString: ' . $banner)) {
            return NOTSECURE_CAN_CHANGE();
        }
    }
    return SECURE_CANT_CHANGE();
}
$GLOBAL_TEST{'HP_UX'}{'gui_banner'} = \&test_gui_banner;


1;
