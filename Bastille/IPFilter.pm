# Copyright (C) 2002-2003, 2006 Hewlett Packard Development Company, L.P.
# Licensed under the GNU General Public License, version 2

package Bastille::IPFilter;

use Bastille::API;
use Bastille::API::HPSpecific;
use Bastille::API::FileContent;

use Exporter;
@ISA = qw ( Exporter );
@EXPORT = qw( defineTests run );

unless (&GetDistro !~ "^HP-UX") {
     ($ipf, $ipfstat)=&getIPFLocation;
}

################################################################################

 #####   ######  ###### #  #    #  ######   #####  ######  ####  #####  ####
 #    #  #       #      #  ##   #  #          #    #      #        #   #
 #    #  #####   #####  #  # #  #  #####      #    #####   ####    #    ####
 #    #  #       #      #  #  # #  #          #    #           #   #        #
 #    #  #       #      #  #   ##  #          #    #      #    #   #   #    #
 #####   ######  #      #  #    #  ######     #    ######  ####    #    ####

################################################################################

################################################################################
# The "defineTests" routine is used by both the front and backend to prune
# the questions appropriately.  If a test returns true, that means skip the
# corresponding question.
################################################################################
sub defineTests {


  # for efficiency and to avoid undefined stuff on Linux
  if (&GetDistro !~ "^HP-UX") {
    return;
  }


    sub test_install_ipfilter{
      if (-e  $ipf){
        return SECURE_CANT_CHANGE();
      } else {
          return NOTSECURE_CAN_CHANGE();
      }
    };
    $GLOBAL_TEST{'IPFilter'}{'install_ipfilter'} = \&test_install_ipfilter;

  # Get the current ruleset to compare with the proposed ruleset
  my %allowRulesHash = %{&getAllowRulesHash};


  # only configure ipfilter if it's installed
  if ( -e $ipf ) {
     &B_log("DEBUG","Defining tests for IPFilter module\n");
     &B_log("DEBUG","Defining install_ipfilter test\n");
     # ipfilter is already installed, so don't ask the question
     # (otherwise, test is undefined and question gets asked)
     # This routine is hardcoded so we don't have to pass in $ipfconf

     my $ipfconf = &getGlobal('FILE','ipf.conf');
     open IPFCONF, "<$ipfconf" or &B_log("ERROR","Can't open $ipfconf\n");

     @ipfrules=<IPFCONF>;
     chomp @ipfrules;

     &B_log("DEBUG","Comparing ipf.conf header to proposed Bastille header\n");
     my @header =split('\n',&getRulesHeader);
     my $headerlines = $#header+1;

     my $headermatches=0;
     if ("@header" eq "@ipfrules[0..$#header]") {
        &B_log("DEBUG","ipf.conf header matches\n");
        $headermatches=1;
     }

     &B_log("DEBUG","Comparing ipf.conf footer to proposed Bastille footer\n");
     my @footer =split('\n',&getRulesFooter );
     my $footerstart = $#ipfrules-$#footer;

     my $footermatches=0;
     if ("@footer" eq "@ipfrules[$footerstart..$#ipfrules]") {
        &B_log("DEBUG","ipf.conf footer matches\n");
        $footermatches=1;
     }

     &B_log("DEBUG","match results: header=$headermatches, " .
                              " footer=$footermatches\n");


     # Define the tests for each "block" question.  If these don't exist,
     # the question WILL be asked
     foreach my $protocol (keys %allowRulesHash) {
      &B_log("DEBUG","Adding test for protocol: $protocol \n");
        # The routine will return true (skip the block_ question) if the
        # header and footer parts of the ipf.conf file match our
        # expectations AND the "allow" rule is missing from the ipf.conf file

        # In other words, the question will be asked if there is an allow
        # rule for this specific item OR we're starting from scratch OR
        # header or footer has changed.

        # SCOPE warning:  This only works because $protocol, $ipfconf,
        # and %allowRulesHash are scoped locally with "my".  The anonymous
        # subroutine here is defined with references to those variables,
        # so if they were scoped globally and changed, the new values
        # would be used when the subroutine gets run, rather than their
        # values when they were defined.  $protocol is especially interesting
        # because a reference to this iteration's copy of the value is passed

        $GLOBAL_TEST{"IPFilter"}{"block_" . $protocol} =
          sub {
            my $ipfconf = &getGlobal("FILE","ipf.conf");

            &B_log("DEBUG","Entering test for IPFilter.$protocol");
            if ($headermatches and $footermatches and &isIPFenabled() and
             (not( &B_match_line(
                     "$ipfconf",
                     "^$allowRulesHash{$protocol}" )))) {
              return SECURE_CANT_CHANGE();
             } else {
              return NOTSECURE_CAN_CHANGE();
             }
          };
     }
     $GLOBAL_TEST{'IPFilter'}{'configure_ipfilter'} =
     sub {
      my $ipfilterConf = &getGlobal("FILE","ipf.conf");
      if ((-e $ipfilterConf) and (B_isFileinSumDB($ipfilterConf)) and
          (&B_check_sum($ipfilterConf)) and
          (isIPFenabled)) {
        return SECURE_CAN_CHANGE();
      } else {
        return NOTSECURE_CAN_CHANGE();
      }
     };
     
      $GLOBAL_TEST{'IPFilter'}{'block_netrange'}  =
     sub {
        my $ipfconf = &getGlobal("FILE","ipf.conf");
        # system("cat $ipfconf");
        if ( &isIPFenabled()  ) {
            my $rtn = open *FH, "< $ipfconf";
            if (!$rtn) {
                &B_log("DEBUG","Open $ipfconf failed\n");
                return INCONSISTENT();
            }
            
            my @lines = <FH>;
            my @details;
            while (defined($line = shift @lines)) {
                if ( $line =~ m/^# Allow incoming connections from the following select IP addresses:/) {
                    while( $line !~ /^\s*$/ ) {
                         $line = shift @lines;
                         if( $line =~ /^pass in quick from ([\d\.\/]*) to any $/) {
                              push @details, $1;
                         }
                    }
                    my $currentsetting = join " ",  @details;
                    return (SECURE_CAN_CHANGE(), $currentsetting); 
                }
            }
	    # lack of additional "allowed" IP addresses is not really NOT SECURE, but to be consistent
	    return NOTSECURE_CAN_CHANGE();
          }
          else {
                return NOTSECURE_CAN_CHANGE();
          }
     };
     # Don't know why this was called here? Commented out for now.
     #$GLOBAL_TEST{'IPFilter'}{'block_netrange'}();

     
  } else {
      # The ipf binary was not found which implies that ipfilter is not installed
      # Don't try to configure it.
      foreach my $protocol (keys %allowRulesHash) {
        &B_log("DEBUG","Adding test for protocol: $protocol \n");
        $GLOBAL_TEST{"IPFilter"}{"block_" . $protocol} =
          sub {
	    # return NOT_INSTALLED_NOTSECURE();
	    return NOT_INSTALLED();
          };
      }
      $GLOBAL_TEST{'IPFilter'}{'configure_ipfilter'} =
          # sub { return NOT_INSTALLED_NOTSECURE();};
          sub { return NOT_INSTALLED();};
  }

  sub isIPFenabled(){
    my $ipfilter = &getGlobal("BIN","ipfilter");
    if (-e $ipfilter ) {
      # For now, need to add path as command can't handle null one
      if (system("export PATH=/usr/sbin:/usr/bin; $ipfilter -q > /dev/null") == 0) {
        &B_log("DEBUG","Detected already-enabled IPFilter... continuing");
        return 1; #true
      } else { # ipfilter -q didn't return "true"
        B_log("DEBUG","ipfilter -q returned false, ipfilter not enabled.");
        return 0; #false
      }
    } else {
      &B_log("DEBUG","This IPFilter version is enabled when installed, continuing.");
      return 1; #true
    }
  }

}

################################################################################

                            #####   #    #  #    #
                            #    #  #    #  ##   #
                            #    #  #    #  # #  #
                            #####   #    #  #  # #
                            #   #   #    #  #   ##
                            #    #   ####   #    #

################################################################################

################################################################################
# The "run" routine is the backend implementation
#
#   Adds information to the TODO list on how to obtain ipfilter if not installed
#   Minimal configuration of ipfilter if it is installed
################################################################################
sub run() {

    # Installation information
    if(&getGlobalConfig("IPFilter","install_ipfilter") eq "Y"){
	&B_log("DEBUG","# sub IPFilter (install reminder)\n");
	my $IPFilter_text =
	    "IPFilter (a host-based firewall) is currently available on a\n" .
            "HP-UX Application Software CD-ROM and at http://software.hp.com.\n" .
            "Install IPFilter from the source of your choice and then re-run\n" .
            "Bastille to help you configure it.\n";
	&B_TODO("\n---------------------------------\nIP Filter Reminder:\n" .
		"---------------------------------\n" .
		$IPFilter_text);
        &B_TODOFlags("set","IPFilter.install_ipfilter", #TODOFlag
                     "IPFilter.install_ipfilter");
    }

   # Basic default-deny firewall configuration

   if(&getGlobalConfig("IPFilter","configure_ipfilter") eq "Y"){

     # However, we only configure ipfilter if it is installed.  The
     # question may have been skipped either because ipfilter isn't
     # installed or because the configuration is already in place.
     if ( -e $ipf ) {
       &B_log("DEBUG","# sub IPFilter (configure)\n");
       &enableIPFilter;
       &B_load_ipf_rules( &getRulesHeader .
                          &getCustomRules .
                          &getAllowRules .
                          &getRulesFooter );


       my $ipfconf = &getGlobal('FILE','ipf.conf');
       my $IPFilter_text =
           "A firewall generally makes up your first line of defense against\n" .
           "network attacks.  Based on your choices, Bastille has created\n" .
           "a basic firewall configuration.  You may wish to customize this\n" .
           "configuration with your own rules, which can be placed in\n" .
           "   " . &getGlobal('FILE',"customipfrules") . "\n" .
           "If you add custom rules to this file, please rerun bastille\n" .
           "and answer \"Yes\" to apply the new custom rules.  (Bastille\n" .
           "will ask the rest of the firewall configuration questions too.)\n".
           "Then, verify that the file\n" .
           "   $ipfconf\n" .
           "contains a ruleset which will adequately protect your system\n" .
           "against network attacks.  See ipf(5) for more information.\n\n";
       &B_TODO
       ("\n---------------------------------\n" .
                "Custom IP Filter Configuration:\n" .
		"---------------------------------\n" .
		$IPFilter_text);

     }
   } elsif(&getGlobalConfig("IPFilter","configure_ipfilter") eq "Y"){
       &B_log("ERROR","IPFilter cannot be configured because it isn't installed!\n");
   }
}

################################################################################
#  HELPER ROUTINES - these routines are used by both the run and defineTests
#                    parts of this file.
################################################################################

################################################################################
# The "get" routines simply store and return data to be used by both "run"
# and "defineTests"
################################################################################

sub enableIPFilter() {
  #This Function ensures that IPFilter is enabled on versions where that's not guaranteed
  my $ipfilter = &getGlobal("BIN","ipfilter");
  if (not(&isIPFenabled)) {
       B_log("NOTE","Bastille is about to enable IPFilter.  As the network stack ".
             "is rebuilt, all network interfaces, and the Bastille GUI, if used, ".
             "may freeze for 10-15 seconds.  If session is disconnected, refer ".
             "to Bastille logs to verify completion of lockdown, see ".
             "bastille(1m) for log location.");
      # For now, need to add path as command can't handle null one
      if (&B_System('export PATH=/usr/sbin:/usr/bin; ' . $ipfilter . " -e",
                    'export PATH=/usr/sbin:/usr/bin; ' . $ipfilter . " -d")) {
        &B_log("ACTION","Successfully enabled IPFilter");
      } else {
        &B_log("ERROR","IPFilter not successfully enabled, no firewall ".
               "protection is in place, see ipf(1m).  Command used: $ipfilter");
      }
    }
} # enableIPFilter

sub getAllowRulesHash {
   # These are macros to shorten the code below so I can line the rules up
   # and still keep everything on a relatively small line
   my $PIQP="pass in quick proto";
   my $FA="from any";
   my $TA="to any";
   my $KS="keep state";
   my $KF="keep frags";
   my $FS="flags S";
   my $PE="port =";

   #############################################################################
   my %allowRulesHash = (
    # encrypted, authenticated management protocols
    'SecureShell'    =>"$PIQP tcp $FA            $TA $PE 22     $FS $KS $KF\n",
    'wbem'           =>"$PIQP tcp $FA            $TA $PE 5989 $FS $KS $KF\n",

    'webadmin'       =>"$PIQP tcp $FA            $TA $PE 1188   $FS $KS $KF\n",
    'webadminautostart'=>"$PIQP tcp $FA          $TA $PE 1110   $FS $KS $KF\n",

    #cfengine daemon
    'cfservd'        =>"$PIQP tcp $FA            $TA $PE 5308   $FS $KS $KF\n",
    #Server Discovery for SIM (and others)
    'ping'          =>"$PIQP icmp $FA            $TA icmp-type 8\n",


    # HP host-based intrusion detection ports
    'hpidsagent'     =>"$PIQP tcp $FA        $TA $PE hpidsagent $FS $KS $KF\n",
    'hpidsadmin'     =>"$PIQP tcp $FA        $TA $PE hpidsadmin $FS $KS $KF\n",

    # There's no question for this one, but it's the right port according
    # to Craig Rantz at Gates.  isee is Instant Support Enterprise Edition
    'isee'           =>"$PIQP tcp $FA        $TA $PE 2367  $FS $KS $KF\n",

    # DNS server protocols
    'DNSquery'       =>"$PIQP udp $FA            $TA $PE domain     $KS\n",

    # For a DNS zone transfer, tcp is used
    'DNSzonetransfer'=>"$PIQP tcp $FA $TA $PE domain $FS $KS $KF\n",


    # clear-text protocols
    'bootp'          =>"$PIQP udp $FA $PE bootpc $TA $PE bootps     $KS\n",
    'tftp'           =>"$PIQP udp $FA            $TA $PE tftp\n",
    'snmpGetSet'     =>"$PIQP udp $FA            $TA $PE snmp       $KS\n",
    'snmpTraps'      =>"$PIQP udp $FA            $TA $PE snmp-trap  $KS\n",

   );

   return \%allowRulesHash;
}

sub getRulesHeader {

  my $header=<<EOF;
# Copyright 2006, Hewlett Packard Company
#
# WARNING: This file was generated automatically and will be replaced
# the next time you run bastille.  DO NOT EDIT IT DIRECTLY!!!
#
#IPFilter configuration file

# block incoming packets with ip options set
block in log quick all with ipopts

EOF

  return $header;
}

sub getRulesFooter {

  my $footer=<<EOF;
#Block any incoming connections which were not explicitly allowed
block in log all
EOF

  return $footer;
}

sub getCustomRules {

  my $customrulesfile=&getGlobal('FILE',"customipfrules");
  if ( -e $customrulesfile) {
    open CUSTOM, "<$customrulesfile" or &B_log("ERROR","Can't open $customrulesfile");
    my @customrules=<CUSTOM>;

    my $customruleswithcomments=<<EOF;

#####################################################################
# The following rules were inserted from the file
# $customrulesfile
# and should be edited there rather than here.  Re-running bastille
# will create a new ipf.conf file including any custom rules from
# that file.
#
#   DO NOT EDIT THIS FILE DIRECTLY!!!
#
#   RULES INSERTED FROM $customrulesfile
#   ARE BELOW.  THESE MAY BE OVERWRITTEN IF YOU RERUN BASTILLE!!!
#
#    #      #      #      #      #      #      #      #      #
#    #      #      #      #      #      #      #      #      #
#    #      #      #      #      #      #      #      #      #
#    #      #      #      #      #      #      #      #      #
#  # # #  # # #  # # #  # # #  # # #  # # #  # # #  # # #  # # #
#   ###    ###    ###    ###    ###    ###    ###    ###    ###
#    #      #      #      #      #      #      #      #      #

@customrules

#    #      #      #      #      #      #      #      #      #
#   ###    ###    ###    ###    ###    ###    ###    ###    ###
#  # # #  # # #  # # #  # # #  # # #  # # #  # # #  # # #  # # #
#    #      #      #      #      #      #      #      #      #
#    #      #      #      #      #      #      #      #      #
#    #      #      #      #      #      #      #      #      #
#    #      #      #      #      #      #      #      #      #
#
#   RULES INSERTED FROM $customrulesfile ABOVE
#
#####################################################################

EOF

    return $customruleswithcomments;
  }

}

sub getAllowRules {
    my %allowRulesHash = %{&getAllowRulesHash};
    my $allowrules=<<EOF;
#####################################################################
#  The following rules explicitly allow/block certain types of connections
#

EOF

     # allow a list of specified IP to access our host
     my $network = &getGlobalConfig("IPFilter","block_netrange");
     $allowrules .= "# Allow incoming connections from the following select IP addresses:\n";
     if ( $network !~ /N/) {
          my @list= split /\s+/, $network;
          my $rule = "";
          for my $ip (@list) {
               $rule .= "pass in quick from $ip to any \n";
          }
          $allowrules .= $rule;
     }
     $allowrules .= "\n";
     
    foreach my $protocol (keys %allowRulesHash) {
       if (&getGlobalConfig("IPFilter","block_" . $protocol) eq "N") {
          $allowrules .= "# Allow $protocol incoming connections\n" .
                         $allowRulesHash{$protocol} . "\n";
       } else {
          $allowrules .= "# do NOT allow $protocol incoming connections\n" .
                         "# " . $allowRulesHash{$protocol} . "\n";
       }
    }
    
    return $allowrules;
}



1;

