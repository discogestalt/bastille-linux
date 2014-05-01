# Copyright (C) 2003 Hewlett-Packard Development Company, L.P.
# Licensed under the GNU General Public License, version 2

#use Exporter;
#@ISA = qw ( Exporter );
#@EXPORT = qw( B_create_log_file );


##############################################################################
# Utility functions - these really help to shorten the actual &B_log routine.

##############################################################################
# &B_create_log_file($logdir, $logfile)
# create the log file in the logdir, unless it already exists
##############################################################################
sub B_create_log_file($$) {
   my ($logdir,$logfile)=@_;

   unless ( -e $logdir ) {
      mkpath ($logdir,0,0700);
   }
   unless ( -e "$logdir/$logfile") {
       open LOGFILE,">" . "$logdir/$logfile";
       close LOGFILE;
   }
}

##############################################################################
# &B_write_log($logfile, $text) -
# open the file and write the text to it, taking care of the error message
##############################################################################
sub B_write_log ($$) {
   my ($logfile,$text)=@_;

   if ( open LOG,">>" . $logfile)  {
      print LOG "$text";
      close LOG;
   } else {
      print STDERR "ERROR:   Failed to open log file $logfile: $!\n";
   }
}

##############################################################################
# &B_format_text($text) -
# correctly format a string for output
##############################################################################
sub B_format_text($) {
  my $text = $_[0];
  # one space between words
  $text =~ s/  */ /g;
  # 2 spaces after a period
  $text =~ s/\.  */.  /g;
  # 2 spaces after a colon
  $text =~ s/\:  */:  /g;
  # Make sure there's a <ret> at the end
  $text =~ s/^(.*)\n*$/$1\n/;
  return $text;
}


##############################################################################
# &B_log ($Logtype, $text) prints $text to the appropriate logs.
# If said logs don't exist, they are created.
#
# Valid log types are currently:
#  FATAL- This causes Bastille to crash with a non-zero exit code
#        Output to stderr, action, errorlog, and syslog
#  ERROR - This causes Bastille to complete execution, but with a non-zero exit code
#        Output to stderr, action, errorlog, and syslog
#  WARNING - This outputs a warning to the error and action logs and syslog
#         Output to stderr, action, errorlog, and syslog
#  NOTE - This is sent to stdout and the actionlog
#  ACTION - Send to actionlog only
#  DEBUG - Sent to debug-log if debug mode is active
#
#  Suggestions to add later:
#  BEGINSUB
#  ENDSUB
#  TODO
#
# The idea for Errorlogging was Mike Rash's (mbr).
# The idea for Debuglogging was Javier's (jfs).
# The idea for combining into one common function was HP's
##############################################################################

sub B_log ($$) {
   my ($logtype,$text) = @_;
   my $datestamp = "{" . localtime() . "}";
   my $spaces=" " x 10;
   my $logger = &getGlobal('BIN','logger');

   my $message = &B_format_text($text);
   my $outputstring ='';
   my $dateoutput='';
   # consistently format the type of log
   my $attn = substr($logtype . ":" . $spaces, 0, 9);

   if (length($message) < 40000) {
      use Text::Wrap;
      $Text::Wrap::columns = 80;
      $outputstring = wrap( "", "         ", ($attn, $message));
      $dateoutput = wrap( "", "         ", ($datestamp, $logtype, $message));
   }else{ #Overflow and skip formatting since Text::Wrap is quite inefficient
          #at processing large output
      $outputstring = $attn . $message;
      $dateoutput = $datestamp . $logtype . $message;
   }

   # common error text for when the log can't be opened

   # do this here to prevent bootstrapping problem, where we need to
   # write an error that the errorlog location isn't defined.
   my $logdir="/var/log/Bastille";
   if(&getActualDistro =~ "^HP-UX"){
       $logdir = "/var/opt/sec_mgmt/bastille/log/";
   }

   if ( $GLOBAL_DEBUG ) {
       &B_create_log_file($logdir,"debug-log");
       &B_write_log("$logdir/debug-log", $dateoutput);
   }
   if ($logtype =~ /DEBUG/) { return; };

   if ( $GLOBAL_VERBOSE ) {
      print STDERR "$outputstring";
   }

   &B_create_log_file($logdir,"action-log");
   &B_write_log("$logdir/action-log", $dateoutput);

   if ($logtype =~ /ACTION/) { return; };

   if ($logtype =~ /NOTE/) {
      print STDOUT $outputstring;
      return;
   } else {
      &B_create_log_file($logdir,"error-log");
      &B_write_log("$logdir/error-log", $dateoutput);
      system($logger . ' -t root_bastille -p user.notice ' . "\"$outputstring\"");
      print STDERR $outputstring;

      if(! defined $errorFlag) {
         $errorFlag = 1;
      }

      if ($logtype =~ /FATAL/) {
         exit 1;
      }

   }
}

1;
