# Copyright (C) 2001, 2002, 2006-2008 Hewlett Packard Development Company, L.P.
# Copyright (C) 2005 Jay Beale
# Licensed under the GNU General Public License, version 2


#This package defines all the tests in a hash, it is more of a "test" driver/definer
#than an API.

package Bastille::TestDriver;
use lib "/usr/lib";

use Bastille::API;

use Exporter;
@ISA = qw ( Exporter );
@EXPORT = qw(  B_run_test 
);

use lib "/usr/lib","/usr/lib/perl5/site_perl/";  #"/usr/lib/Bastille";


###########################################################################
# define tests

#TODO: Define remaining Linux tests:Firewall, PSAD, PatchDownload, RemoteAccess
# and TMPDIR

###########################################################################
use Bastille::test_AccountSecurity;
use Bastille::test_Apache;
use Bastille::test_BootSecurity;
use Bastille::test_DNS;
use Bastille::test_DisableUserTools;
use Bastille::test_FTP;
use Bastille::test_FilePermissions;
use Bastille::test_HP_UX;
use Bastille::test_Logging;
use Bastille::test_MiscellaneousDaemons;
use Bastille::test_Patches;
use Bastille::test_Printing;
use Bastille::test_SecureInetd;
use Bastille::test_Sendmail;

use Bastille::IPFilter;
&Bastille::IPFilter::defineTests;

###########################################################################
# &B_run_test($$)
#
# Runs the specified test to determine whether or not the question should
# be answered.
# curretly defined return values:
# 0 -- Configurable and not secured (NOTSECURE_CAN_CHANGE()) (compatible with ASKQ)
# 1 -- Secure, no longer configurable (SECURE_CANT_CHANGE()_CANT_CHANGE) (Compatible with SKIPQ)
# 2 -- Configurable software is not installed where the lack makes the system secure, eg telnet (NOT_INSTALLED) 
# 3 -- Configuration change may not fully secure system state (INCONSISTENT)
# 4 -- Question is Manual for User (Pending TODO Items Involved) (MANUAL)
# 5 -- Developers never wrote a test (NOTEST)
# 6 -- Secure, but can still change value, like UMASK and IPFilter(SECURE_CAN_CHANGE())
# 7 -- Non-boolean values where the value is not yet set, and where
#      the presense of an "N" entry in the report would, if used as a config, would
#      change the system value.  This *will* go in the report, but not in the
#      runnable config (STRING_NOT_DEFINED)
# 8 -- Where the missing s/w makes the system less secure eg IPFilter(NOT_INSTALLED_NOTSECURE)
#
# Also, the following exit codes map to the values specified above.  This is done
# so we can be clear that a different result exists, but the behavior
# should map to the behavior defined for the above codes
#
# 0 - NOTRELEVANT_HEADERQ - For a question that whose answer does not affect security
#     but whose "children" (if not "skipped") should be skipped (go to "skip child")
# 6 - RELEVANT_HEADERQ - For a question that whose answer does not affect security
#     but whose "children" (if not "skipped") should *not* be skipped (go to "yes child")
# 5 - DONT_KNOW - If the developer did not have time to understand a given corner
#     case, use this as a "marker" to ensure correct Bastille behavior, while
#     not confusing future developers as to the confidence in the test result.
#     To summarize: use "INCONSISTENT" when the system is in a strange state,
#     use DONT_KNOW, when the test isn't thorough.  Better to admit an issue than
#     hide it...
#
# See for more detail.
###########################################################################
sub B_run_test ($$) {
  my $module = $_[0];
  my $key = $_[1];

  if (exists $GLOBAL_TEST{$module}{$key}) {
    my ($testout,$details) = &{$GLOBAL_TEST{$module}{$key}};
    &B_log("DEBUG","\$GLOBAL_TEST{'$module'}{'$key'} returned $testout" .
           " Details: $details");
    # Make flag and exit-code tweaks based on test-results and flag status
    my $flagName = $module . '.' . $key;
    if (&B_TODOFlags('isSet',$flagName )) {
        if (($testout == SECURE_CANT_CHANGE()) or
            ($testout == SECURE_CAN_CHANGE())) {
          &B_log("ACTION","Clearing todo flag: $flagName as it no longer applies");
          &B_TODOFlags('clear',$flagName); #flag no longer needed, since its secure
        }
        # If there are manual actions left, and the test detects a not-secure
        # state, the manual actions still need completion.
        if ($testout == NOTSECURE_CAN_CHANGE()) {
            $testout = MANUAL();
        }
    }

    if (defined($details)) {
      return ($testout,$details);
    } else {
      return $testout;
    }
  } else {
    &B_log("DEBUG","\$GLOBAL_TEST{'$module'}{'$key'} is not defined, ask question, and flag.\n");
    return NOTEST();
  }
}


1;
