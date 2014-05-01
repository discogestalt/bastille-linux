# Copyright (C) 2001, 2002, 2006, 2007 Hewlett Packard Development Company, L.P.
# Copyright (C) 2005 Jay Beale
# Licensed under the GNU General Public License, version 2


#This package defines all the tests in a hash, it is more of a "test" driver/definer
#than an API.

package Bastille::TestAPI;
use lib "/usr/lib";

require Bastille::API;
import Bastille::API;

use Exporter;
@ISA = qw ( Exporter );
@EXPORT = qw(  B_run_test
B_match_chunk B_is_executable B_is_suid B_is_sgid
B_check_permissions B_get_user_list B_get_group_list B_parse_fstab B_parse_mtab B_is_rpm_up_to_date
B_TODOFlags
);

use lib "/usr/lib","/usr/lib/perl5/site_perl/","/usr/lib/Bastille";


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
# 2 -- Configurable software is not installed (NOT_INSTALLED)
# 3 -- Configuration change may not fully secure system state (INCONSISTENT)
# 4 -- Question is Manual for User (Pending TODO Items Involved) (MANUAL)
# 5 -- Developers never wrote a test (NOTEST)
# 6 -- Secure, but can still change value, like UMASK and IPFilter(SECURE_CAN_CHANGE())
# 7 -- Non-boolean values where the value is not yet set, and where
#      the presense of an "N" entry in the report would, if used as a config, would
#      change the system value.  This *will* go in the report, but not in the
#      runnable config (STRING_NOT_DEFINED)
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
# See test-plan document for more detail.
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


###########################################################################
# &B_match_chunk($file,$pattern);
#
# This subroutine will return a 1 if the pattern specified can be matched
# against the file specified on a line-agnostic form.  This allows for
# patterns which by necessity must match against a multi-line pattern.
# This is the natural analogue to B_replace_chunk, which was created to
# provide multi-line capability not provided by B_replace_line.
#
# return values:
# 0:     pattern not in file or the file is not readable
# 1:     pattern is in file
###########################################################################

sub B_match_chunk($$) {

    my ($file,$pattern) = @_;
    my @lines;
    my $big_long_line;
    my $retval=1;

    open CHUNK_FILE,$file;

    # Read all lines into one scalar.
    @lines = <CHUNK_FILE>;
    close CHUNK_FILE;

    foreach my $line ( @lines ) {
        $big_long_line .= $line;
    }

    # Substitution routines get weird unless last line is terminated with \n
    chomp $big_long_line;
    $big_long_line .= "\n";

    # Exit if we don't find a match
    unless ($big_long_line =~ $pattern) {
        $retval = 0;
    }

    return $retval;
}

###########################################################################
# &B_check_permissions($$)
#
# Checks if the given file has the given permissions or stronger, where we
# define stronger as "less accessible."  The file argument must be fully
# qualified, i.e. contain the absolute path.
#
# return values:
# 1: file has the given permissions or better
# 0:  file does not have the given permsssions
# undef: file permissions cannot be determined
###########################################################################

sub B_check_permissions ($$){
  my ($fileName, $reqdPerms) = @_;
  my $filePerms;			# actual permissions


  if (-e $fileName) {
    if (stat($fileName)) {
      $filePerms = (stat($fileName))[2] & 07777;
    }
    else {
      &B_log ("ERROR", "Can't stat $fileName.\n");
      return undef;
    }
  }
  else {
    # If the file does not exist, permissions are as good as they can get.
    return 1;
  }

  #
  # We can check whether the $filePerms are as strong by
  # bitwise ANDing them with $reqdPerms and checking if the
  # result is still equal to $filePerms.  If it is, the
  # $filePerms are strong enough.
  #
  if ( ($filePerms & $reqdPerms) == $filePerms ) {
      return 1;
  }
  else {
      return 0;
  }

}


###########################################################################
# B_is_executable($)
#
# This routine reports on whether a file is executable by the current
# process' effective UID.
#
# scalar return values:
# 0:     file is not executable
# 1:     file is executable
#
###########################################################################

sub B_is_executable($)
{
    my $name = shift;
    my $executable = 0;

    if (-x $name) {
	$executable = 1;
    }
    return $executable;
}

###########################################################################
# B_is_suid($)
#
# This routine reports on whether a file is Set-UID and owned by root.
#
# scalar return values:
# 0:     file is not SUID root
# 1:     file is SUID root
#
###########################################################################

sub B_is_suid($)
{
    my $name = shift;

    my @FileStatus = stat($name);
    my $IsSuid = 0;

    if (-u $name) #Checks existence and suid
    {
        if($FileStatus[4] == 0) {
            $IsSuid = 1;
        }
    }

    return $IsSuid;
}

###########################################################################
# B_is_sgid($)
#
# This routine reports on whether a file is SGID and group owned by
# group root (gid 0).
#
# scalar return values:
# 0:     file is not SGID root
# 1:     file is SGID root
#
###########################################################################

sub B_is_sgid($)
{
    my $name = shift;

    my @FileStatus = stat($name);
    my $IsSgid = 0;

    if (-g $name) #checks existence and sgid
    {
        if($FileStatus[5] == 0) {
            $IsSgid = 1;
        }
    }

    return $IsSgid;
}

###########################################################################
# B_get_user_list()
#
# This routine outputs a list of users on the system.
#
###########################################################################

sub B_get_user_list()
{
    my @users;
    open(PASSWD,&getGlobal('FILE','passwd'));
    while(<PASSWD>) {
        #Get the users
        if (/^([^:]+):/)
        {
            push (@users,$1);
        }
    }
     return @users;
}

###########################################################################
# B_get_group_list()
#
# This routine outputs a list of groups on the system.
#
###########################################################################

sub B_get_group_list()
{
    my @groups;
    open(GROUP,&getGlobal('FILE','group'));
    while(my $group_line = <GROUP>) {
        #Get the groups
        if ($group_line =~ /^([^:]+):/)
        {
	    push (@groups,$1);
        }
    }
     return @groups;
}


###########################################################################
# B_parse_fstab()
#
# Search the filesystem table for a specific mount point.
#
# scalar return value:
# The line form the table that matched the mount point, or the null string
# if no match was found.
#
# list return value:
# A list of parsed values from the line of the table that matched, with
# element [3] containing a reference to a hash of the mount options.  The
# keys are: acl, dev, exec, rw, suid, sync, or user.  The value of each key
# can be either 0 or 1.  To access the hash, use code similar to this:
# %HashResult = %{(&B_parse_fstab($MountPoint))[3]};
#
###########################################################################

sub B_parse_fstab($)
{
    my $name = shift;
    my $file = &getGlobal('FILE','fstab');
    my ($enable, $disable, $infile);
    my @lineopt;
    my $retline = "";
    my @retlist = ();

    unless (open FH, $file) {
	&B_log('ERROR',"B_parse_fstab couldn't open fstab file at path $file.\n");
	return 0;
    }
    while (<FH>) {
        s/\#.*//;
        next unless /\S/;
        @retlist = split;
        next unless $retlist[1] eq $name;
        $retline  .= $_;
        if (wantarray) {
            my $option = {		# initialize to defaults
            acl    =>  0,		# for ext2, etx3, reiserfs
            dev    =>  1,
            exec   =>  1,
            rw     =>  1,
            suid   =>  1,
            sync   =>  0,
            user   =>  0,
            };

            my @lineopt = split(',',$retlist[3]);
            foreach my $entry (@lineopt) {
                if ($entry eq 'acl') {
                    $option->{'acl'} = 1;
                }
                elsif ($entry eq 'nodev') {
                    $option->{'dev'} = 0;
                }
                elsif ($entry eq 'noexec') {
                    $option->{'exec'} = 0;
                }
                elsif ($entry eq 'ro') {
                    $option->{'rw'} = 0;
                }
                elsif ($entry eq 'nosuid') {
                    $option->{'suid'} = 0;
                }
                elsif ($entry eq 'sync') {
                    $option->{'sync'} = 1;
                }
                elsif ($entry eq 'user') {
                    $option->{'user'} = 1;
                }
            }
            $retlist[3]= $option;
        }
        last;
    }

    if (wantarray)
    {
        return @retlist;
    }
    else
    {
        return $retline;
    }

}


###########################################################################
# B_parse_mtab()
#
# This routine returns a hash of devices and their mount points from mtab,
# simply so you can get a list of mounted filesystems.
#
###########################################################################

sub B_parse_mtab
{
    my $mountpoints;
    open(MTAB,&getGlobal('FILE','mtab'));
    while(my $mtab_line = <MTAB>) {
        #test if it's a device
        if ($mtab_line =~ /^\//)
        {
           #parse out device and mount point
           $mtab_line =~ /^(\S+)\s+(\S+)/;
           $mountpoints->{$1} = $2;
        }
     }
     return $mountpoints;
}


###########################################################################
# B_is_rpm_up_to_date()
#
#
###########################################################################

sub B_is_rpm_up_to_date(@)
{
    my($nameB,$verB,$relB,$epochB) = @_;
    my $installedpkg = $nameB;

    if ($epochB =~ /(none)/) {
	$epochB = 0;
    }

    my $rpmA   = `rpm -q --qf '%{VERSION}-%{RELEASE}-%{EPOCH}\n' $installedpkg`;
    my $nameA  = $nameB;
    my ($verA,$relA,$epochA);

    my $retval;

    # First, if the RPM isn't installed, let's handle that.
    if ($rpmA =~ /is not installed/) {
	$retval = -1;
	return $retval;
    }
    else {
	# Next, let's try to parse the EVR information without as few
	# calls as possible to rpm.
	if ($rpmA =~ /([^-]+)-([^-]+)-([^-]+)$/) {
	    $verA = $1;
	    $relA = $2;
	    $epochA = $3;
	}
	else {
	    $nameA  = `rpm -q --qf '%{NAME}' $installedpkg`;
	    $verA  = `rpm -q --qf '%{VERSION}' $installedpkg`;
	    $relA  = `rpm -q --qf '%{RELEASE}' $installedpkg`;
	    $epochA  = `rpm -q --qf '%{EPOCH}' $installedpkg`;
	}
    }

    # Parse "none" as 0.
    if ($epochA =~ /(none)/) {
	$epochA = 0;
    }

    # Handle the case where only one of them is zero.
    if ($epochA == 0 xor $epochB == 0)
    {
	if ($epochA != 0)
	{
	    $retval = 1;
	}
	else
	{
	    $retval = 0;
	}
    }
    else
    {
	# ...otherwise they are either both 0 or both non-zero and
	# so the situation isn't trivial.

	# Check epoch first - highest epoch wins.
	my $rpmcmp = &cmp_vers_part($epochA, $epochB);
	#print "epoch rpmcmp is $rpmcmp\n";
	if ($rpmcmp > 0)
	{
	    $retval = 1;
	}
	elsif ($rpmcmp < 0)
	{
	    $retval = 0;
	}
	else
	{
	    # Epochs were the same.  Check Version now.
	    $rpmcmp = &cmp_vers_part($verA, $verB);
	    #print "epoch rpmcmp is $rpmcmp\n";
	    if ($rpmcmp > 0)
	    {
		$retval = 1;
	    }
	    elsif ($rpmcmp < 0)
	    {
		$retval = 0;
	    }
	    else
	    {
		# Versions were the same.  Check Release now.
		my $rpmcmp = &cmp_vers_part($relA, $relB);
		#print "epoch rpmcmp is $rpmcmp\n";
		if ($rpmcmp >= 0)
		{
		    $retval = 1;
		}
		elsif ($rpmcmp < 0)
		{
		    $retval = 0;
		}
	    }
	}
    }
    return $retval;
}

#################################################
#  Helper function for B_is_rpm_up_to_date()
#################################################

#This cmp_vers_part function taken from Kirk Bauer's Autorpm.
# This version comparison code was sent in by Robert Mitchell and, although
# not yet perfect, is better than the original one I had. He took the code
# from freshrpms and did some mods to it. Further mods by Simon Liddington
# <sjl96v@ecs.soton.ac.uk>.
#
# Splits string into minors on . and change from numeric to non-numeric
# characters. Minors are compared from the beginning of the string. If the
# minors are both numeric then they are numerically compared. If both minors
# are non-numeric and a single character they are alphabetically compared, if
# they are not a single character they are checked to be the same if the are not
# the result is unknown (currently we say the first is newer so that we have
# a choice to upgrade). If one minor is numeric and one non-numeric then the
# numeric one is newer as it has a longer version string.
# We also assume that (for example) .15 is equivalent to 0.15

sub cmp_vers_part($$) {
   my($va, $vb) = @_;
   my(@va_dots, @vb_dots);
   my($a, $b);
   my($i);

   if ($vb !~ /^pre/ and $va =~ s/^pre(\d+.*)$/$1/) {
      if ($va eq $vb) { return -1; }
   } elsif ($va !~ /^pre/ and $vb =~ s/^pre(\d+.*)$/$1/) {
      if ($va eq $vb) { return 1; }
   }

   @va_dots = split(/\./, $va);
   @vb_dots = split(/\./, $vb);

   $a = shift(@va_dots);
   $b = shift(@vb_dots);
   # We also assume that (for example) .15 is equivalent to 0.15
   if ($a eq '' && $va ne '') { $a = "0"; }
   if ($b eq '' && $vb ne '') { $b = "0"; }
   while ((defined($a) && $a ne '') || (defined($b) && $b ne '')) {
      # compare each minor from left to right
      if ((not defined($a)) || ($a eq '')) { return -1; } # the longer version is newer
      if ((not defined($b)) || ($b eq '')) { return  1; }
      if ($a =~ /^\d+$/ && $b =~ /^\d+$/) {
         # I have changed this so that when the two strings are numeric, but one or both
         # of them start with a 0, then do a string compare - Kirk Bauer - 5/28/99
         if ($a =~ /^0/ or $b =~ /^0/) {
            # We better string-compare so that netscape-4.6 is newer than netscape-4.08
            if ($a ne $b) {return ($a cmp $b);}
         }
         # numeric compare
         if ($a != $b) { return $a <=> $b; }
      } elsif ($a =~ /^\D+$/ && $b =~ /^\D+$/) {
         # string compare
         if (length($a) == 1 && length($b) == 1) {
            # only minors with one letter seem to be useful for versioning
            if ($a ne $b) { return $a cmp $b; }
         } elsif (($a cmp $b) != 0) {
            # otherwise we should at least check they are the same and if not say unknown
            # say newer for now so at least we get choice whether to upgrade or not
            return -1;
         }
      } elsif ( ($a =~ /^\D+$/ && $b =~ /^\d+$/) || ($a =~ /^\d+$/ && $b =~ /^\D+$/) ) {
         # if we get a number in one and a word in another the one with a number
         # has a longer version string
         if ($a =~ /^\d+$/) { return 1; }
         if ($b =~ /^\d+$/) { return -1; }
      } else {
         # minor needs splitting
         $a =~ /\d+/ || $a =~ /\D+/;
         # split the $a minor into numbers and non-numbers
         my @va_bits = ($`, $&, $');
         $b =~ /\d+/ || $b =~ /\D+/;
         # split the $b minor into numbers and non-numbers
         my @vb_bits = ($`, $&, $');
         for ( my $j=2; $j >= 0; $j--) {
            if ($va_bits[$j] ne '') { unshift(@va_dots,$va_bits[$j]); }
            if ($vb_bits[$j] ne '') { unshift(@vb_dots,$vb_bits[$j]); }
         }
      }
      $a = shift(@va_dots);
      $b = shift(@vb_dots);
   }
   return 0;
}

1;
