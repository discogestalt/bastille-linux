# Copyright (C) 2002-2003,2006 Hewlett Packard Development Company, L.P.
# Licensed under the GNU General Public License, version 2


use Bastille::API;
use Bastille::API::ServiceAdmin;
use Bastille::API::FileContent;

  sub test_sendmaildaemon{
      my $rtn = &B_is_service_off('sendmail');

      if ( ($rtn == NOTSECURE_CAN_CHANGE()) and (&GetDistro !~ /^RH/) ) {
	  my $sysconfig_file = &getGlobal('FILE','sysconfig_sendmail');
	  if (&B_match_line($sysconfig_file,'^\s*DAEMON\s*=\s*NO\b')) {
	      $rtn = SECURE_CANT_CHANGE();
	  }
      }

      return $rtn;
  };
$GLOBAL_TEST{'Sendmail'}{'sendmaildaemon'} = \&test_sendmaildaemon;

  sub test_sendmailcron{
          my $sendmail = &getGlobal('BIN','sendmail');
	  # Don't ask the question if sendmail isn't present on the system.
	  unless ( -e $sendmail ) {
 	      return NOT_INSTALLED();
	  }
          # Don't ask the question if the sendmail configuration file is not
          # present on the system (e.g. for SUSE with postfix).
          unless ( -e &getGlobal('FILE', 'sendmail.cf')) {
              return NOT_INSTALLED();
          }
	  my $crontab =  &getGlobal('BIN','crontab');
          # Don't ask the question if crontab isn't present on the system.
          unless ( -e $crontab ) {
              return NOT_INSTALLED();
          }

	  # get cronjobs for the root user
	  my @cronjobs = `$crontab -l 2>/dev/null`;

	  # look at each cronjob in the cron listing
	  foreach my $job (@cronjobs) {
	      # if a cronjob matches the sendmail -q command then
	      if($job =~ "$sendmail\\s+\-q") {
		  # found a cronjob for sendmail queue processing
		  # don't ask the question
		  return SECURE_CANT_CHANGE();
	      }
	  }
	  # unable to find a cronjob for sendmail queue processing


	  ## Check if sendmail is being run in queue cleanup mode
	  ## On Red Hat and SuSE systems, this is done by checking
	  ## /etc/sysconfig/sendmail's DAEMON= line for a sleep time
	  my $sysconfig_sendmail = &getGlobal('FILE','sysconfig_sendmail');
	  if ( defined($sysconfig_sendmail) and -e $sysconfig_sendmail ) {
		if (&B_match_line($sysconfig_sendmail,'^\s*DAEMON\s*=\s*\S+')) {
                	return SECURE_CANT_CHANGE();
		}
          }
	  else {
		#
		# When we can't just read /etc/sysconfig/sendmail, look for
		# an appropriate entry in the ps-listing,like:
		#
		# sendmail: Queue runner@01:00:00 for /var/spool/mqueue
		#
		my $ps_line = &getGlobal('BIN','ps') . ' -ef';
		if (open PS,$ps_line) {
			my @lines = <PS>;
			close PS;
			chomp @lines;

			if (grep /sendmail:\s+Queue runner\@.* for .*\/mqueue/,@lines) {
				return SECURE_CANT_CHANGE();
			}
			if (grep /sendmail\s+-q/,@lines) {
				return SECURE_CANT_CHANGE();
			}
		}
	  }

	  # Otherwise, just ask the question.
	  return NOTSECURE_CAN_CHANGE();
  };
$GLOBAL_TEST{'Sendmail'}{'sendmailcron'} = \&test_sendmailcron;

  sub test_vrfyexpn {
      my $sendmail_cf = &getGlobal('FILE',"sendmail.cf");
      # Don't ask the question if the sendmail configuration file is not
      # present on the system.
      unless (-e $sendmail_cf) {
          return NOT_INSTALLED();
      }

      # B_return_matched_line returns all lines that matched the pattern when
      # called in list context.
      my @privacyLines = &B_return_matched_lines($sendmail_cf,
                                                '\s*O\s*PrivacyOptions');
      my $optionList = '';

      # Build the list of privacy options.  Usually there is only one line,
      # but in case there are more than one line, each line is parsed and
      # the options added to the list, separated by commas.
      foreach my $line (@privacyLines)
      {
          $line =~ /PrivacyOptions\s*=\s*(.*)/;
          $optionList .= $1 . ',';
      }

      chop $optionList;			# remove trailing comma

      my @options = split(',', $optionList);
      my $hardened = 0;			# scoring

      # Look at each option, and give points for those that increase security.
      # If the option "public" is found, all points are removed and no
      # further investigation is done.  In case the are options which undo
      # previous options (none are documented for sendmail at this time),
      # add more tests and decrease the score.
      foreach my $anOption (@options) {
          if ($anOption eq 'goaway') {
              $hardened += 2;		# goaway implies novrfy and noexpn
          }
          elsif ($anOption eq 'novrfy') {
              $hardened++;
          }
          elsif ($anOption eq 'noexpn') {
              $hardened++;
          }
          elsif ($anOption eq 'public') {
              $hardened = 0;		# public should just not be used
              last;
          }
      }  # foreach my $anOption...

      # A score of 2 or above indicates that novrfy and noexpn have been set.
      if ($hardened >= 2) {
          return SECURE_CANT_CHANGE();
      }
      else {
          return NOTSECURE_CAN_CHANGE();
      }
  };
$GLOBAL_TEST{'Sendmail'}{'vrfyexpn'} = \&test_vrfyexpn;

1;
