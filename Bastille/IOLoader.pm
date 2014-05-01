# Copyright (C) 1999-2005 Jay Beale
# Copyright (C) 2001-2006 Hewlett Packard Development Company, L.P.
# Licensed under the GNU General Public License, version 2
package Bastille::IOLoader;
use lib "/usr/lib";

use Bastille::API;
use Bastille::API::HPSpecific;
use Bastille::API::FileContent;

use Bastille::TestDriver;

use File::Path;
use File::Basename;
use English;

use Exporter;
@ISA = qw ( Exporter );
@EXPORT = qw( Load_Questions compareQandA validateAnswer ReadConfig isConfigDefined
	      validateAnswers getRegExp checkQtree partialSave outputConfig
	      %Question %moduleHead firstQuestion
	      );

@ENV="";
$ENV{PATH}="";
$ENV{CDPATH}=".";
$ENV{BASH_ENV}="";

my %deletedQText;  # variable used to store the question text from
                  # questions that will be deleted but are distro appropriate.
                  #  Used in Load_Questions and outputConfig

#File-scoped variables to handle unfortunate inter-module coupling
my $audit_report_html_lines='';
my $currentModule='';
my $firstQuestion;

sub firstQuestion {
    if ($firstQuestion ne ""){
        return $firstQuestion;
    }else{
        &B_log("ERROR","First Question not yet defined, but requested");
    }
}
###############################################################################
# &Load_Questions does:
#
# 1) Create a question record for the Title screen: no question, no default
#    answer, toggle_yn=0, just a Short Explanation=Title Screen
# 2) Load in each question, one by one, by grabbing the expected records one
#    by one from a file.  Records, within the file, are described below.
# 3) Append a "Done now--gonna run the script" screen as Y/N question...  Needs
#    to have Yes-Child to be Bastille_Finish  QuestionName:  End_Screen
#
# Record format within Questions file:
# - A record is terminated by a blank line which is not part of a quoted
#   string.
# - A new record is began by the LABEL: tag, along with the index for the
#   question.
# - Otherwise, the entries within the record can be in any order at all.
# - Multi-line fields must be quoted in double-quotes..
# - Double quotes are allowed inside a string, but must be escaped, like \".
#
###############################################################################

sub Load_Questions($) {
# sub Load_Questions creates a data structure called %%Questions
  my $UseRequiresRules = $_[0];

  my ($current_module_number,$first_question) = &parse_questions();
  $first_question = &prune_questions($UseRequiresRules,$first_question);
  $firstQuestion = $first_question;
  &B_log("DEBUG","Load Questions, first question: $first_question");
  &validate_questions();

  return ($current_module_number, $first_question);
}

sub parse_questions() {

    # Line loaded in from file and it's non-tag data
    my ($line,$data);
    my @questionFile;
    my $line_number=0; # Line number (within the disk file)

    # Module to which the current question being loaded in belongs and
    # the order that Load_Questions loads it in
    my $current_module;
    my $current_module_number=0;

    # Question (record) that we're in, listed by index(LABEL)
    my $current_index;

    # The first and last questions -- used for Title_Screen and End_Screen
    my $first_question="";
    my $previous_question="";
    my $previous_module = "";

    # Field we're in
    my $current_field;

    # OK, so here's how this goes.  The Questions file looks has a series of
    # records, which have a series of  TAG: value    lines.  A value may span
    # multiple lines if it was begun with a  "  mark, but is usually expected
    # to be a string.  " marks can occur inside records, if escaped:  \"
    # Records end with a blank line and begin with a LABEL: tag.  We get module
    # names from FILE: somename.pm  lines, which should have whitespace around
    # them...

    # Major change: we're parsing questions out of Questions/<module>.txt now,
    # getting our module names from Modules.txt.


    # Get the list of questions files, each corresponding to one module
    unless (open QUESTIONS_MODULES,&getGlobal('BFILE','QuestionsModules')) {
	&B_log("ERROR","Can't open: ". &getGlobal('BFILE','QuestionsModules') .
	       " to get our list of modules.\n");
       exit(1);
    }

    my @module_list = <QUESTIONS_MODULES>;
    close QUESTIONS_MODULES;
    chomp @module_list;

    my $module_path = &getGlobal('BDIR','QuestionsDir') . '/';
    foreach $questions_module (@module_list) {
	$questions_module .= '.txt';

	unless (open QUESTIONS,$module_path . $questions_module) {
	    &B_log("ERROR","Can't open $module_path$questions_module questions file.\n");
	    exit(1);
	}

	# Load the Questions in.
	my @questions_data = <QUESTIONS>;
	close QUESTIONS;

	# To close the current record at the end of a file, we're going to add
	# a blank line.  This is because the code as written expects a single Questions
	# file and thus a blank line between records.  Rather than dramatically change
	# that logic, we'll adapt it more simply by adding the line below.
	push @questions_data,"\n";


       foreach $line (@questions_data) {

	# Increment line number
	$line_number++;

	# If we're currently in a question record...
	if ($current_index) {

	    # If we're currently in a __multi-line__ record (a quoted string),
	    if ($current_field) {
		# See if it's terminated in a quote (i.e. is end of a string?)
		my $end_of_string=0;

		if ($line =~ /^(.*)\"\s*\n*$/) {
		    # Make sure the terminating quote isn't an escaped quote
		    my $templine=$1;
		    unless ($templine =~ /\\$/) {
			$line=$templine;
			$end_of_string=1;
		    }
		}

		#
		### Text Handling
		#

		# Convert escaped quotes \" to real quotes "
		$line =~ s/\\\"/\"/g;

		# Strip out terminating \n's
		unless ($line =~ /^\s*\n+\s*$/) {
		    if ($line =~ /^(.*)\n$/) {
			$line = $1 . " ";
		    }
		}
		else {
		    $line .= "\n";
		}

		# Add the line to the end of the record and ...
		if ($Question{$current_index}{$current_field} =~ /[^\s\n]$/) {
		    $Question{$current_index}{$current_field} .= " ";
		}

		$Question{$current_index}{$current_field}.=$line;
		# Check if the record is over.
		if ($end_of_string) {
		    $current_field="";
	        }
            }
            else {
                # We're _not_ in a multi-line record

		# Did we hit a blank line? Blank lines, not embedded in
		#  " marks, delimit records
		if ($line =~/^\s*$/) {
		    $current_field="";
		    $current_index="";
		}
		else {
		    # Figure out what field to put this data in...
		    ($current_field,$data) = &getFieldData($line,$line_number);

		    # If the data isn't quoted, just finish up...
		    unless ( ($data =~ /^\"/ ) or ($data =~ /[^\\]\"$/) ){

			# Convert escaped quote marks
			$data =~ s/\\\"/\"/g;


			# If this is the REQUIRE_DISTRO field, expand any macros
			if ($current_field eq 'require_distro') {
			    $data = &OS_macro_expand($data);
			}

			$Question{$current_index}{$current_field}=$data;
#			&B_log("DEBUG","Adding (0) Field: Question{".
#				   $current_index."}{".$current_field."}=".$data);
			$current_field="";
		    }
		    else {
			# Make sure this looks like a real quoted string
			if ($data !~ /^\s*\"/) {
			    &B_log("FATAL","Mis-quoted line\n\n$line\n\n" .
				   "         Line number $line_number\n");
			}

			# Strip off initiating quote mark
		        if ($data =~ /^\s*\"(.*)$/) {
			    $data=$1;
			}

			# If this thing has a terminating quote mark, it is a
			# single-line quoted record, probably used to preserve
			# leading or trailing whitespace.
			if ($data =~ /[^\\]\"$/) {

			    if ($data =~ /^(.*)([^\\])\"$/) {
				$data=$1 . $2;

				# Convert escaped quote marks
				$data =~ s/\\\"/\"/g;

				$Question{$current_index}{$current_field}=$data;
#				&B_log("DEBUG","Adding (1) Field: Question{".
#				   $current_index."}{".$current_field."}=".$data);
				$current_field="";
			    }
			}
			# Otherwise, it is the beginning of a multi-line record
			else {

			    # Strip off end \n's
			    unless ($data =~ /^\s*\n+\s*$/) {
				if ($data =~ /^(.*)\n$/) {
				    $data=$1 . " ";
				}
			    }

			    # Convert escaped quote marks
			    $data =~ s/\\\"/\"/g;

			    # Now, actually copy the data in
			    $Question{$current_index}{$current_field}=$data;
#			    &B_log("DEBUG","Adding (2) Field: Question\{".
#				   $current_index."}{".$current_field."}=".$data);
			}

		    }

		}
	    }
	}
	# OK, so we're not in a record (Question) at all...
	else {

	    # Are we starting a new one, on another blank line, or getting a
	    # module name?
	    if ($line =~ /^LABEL:\s*(.*)$/) {

		# We have found a new record...
		$current_index=$1;

		# Prune whitespace from the name
		if ($current_index=~/^(.*)\s+$/) {
		    $current_index =$1;
		}
		&B_log("DEBUG","Parsing Question: $current_index");
		$Question{$current_index}{"module"}=$current_module;
		$Question{$current_index}{"shortModule"} = (split(/.pm/,$current_module))[0];

		$current_field="";  # This is not a multi-line record

                # Record the name of the record so sanity checks can be done
		# later
		$recordnames[@recordnames]=$current_index;

		#
		# Put together properties for Questions so that each question ties to the one
		# before it and the one after it unless proper_parent, yes_child or no_child
		# are explicitly listed.  For proper_parent, we just set a default and let it
		# get clobbered in the parsing process.  For children, we check their existence.
		#

                # If this is the first record (question), treat it differently.
		# Make the necessary link from Title_Screen record and don't try to set children
		# entries in the parent.
		unless ( $first_question ) {
		    $first_question=$current_index;
		    $Question{$current_index}{"proper_parent"} = $current_index;
		}
		# ...otherwise proceed as normal
		else {

		    $Question{$current_index}{'proper_parent'} = $previous_question;
		    unless ($Question{$previous_question}{'yes_child'}) {
			$Question{$previous_question}{'yes_child'}=$current_index;
		    }
		    unless ($Question{$previous_question}{'no_child'}) {
			$Question{$previous_question}{'no_child'}=$current_index;
		    }
		}

		# Save the value of the current index so the End_Screen can
		# find the right parent and children can be set correctly
		$previous_question=$current_index;

	    }
	    elsif ($line =~ /^FILE:\s*(.*)$/) {
		# Record the module we're leaving.
		$previous_module = $current_module;

		# Started a new module name...
		$current_module_number++;
		$current_module=$1 . " Module $current_module_number";

	    }
	    elsif ($line =~ /^\s*$/) {
		# A blank line
		# do nothing
	    }
	    else {
                &B_log("FATAL","Invalid question record found at line $line_number " .
                          "of the merged contents of the Questions directory.  ".
                          "Expecting FILE: or LABEL:\n\n" .
                          "  Found \n\n$line\n" .
                          "  instead.  This is a fatal error, exiting...\n");
	    }
	}
       } #foreach line of a given module
    } #loop through modules
    &B_log("DEBUG","SPC Child leaving parse is: ". $Question{'spc_run'}{'yes_child'} );
    return ($current_module_number, $first_question);
} #parse_questions


################################################################################
# &getFieldData($line,$line_number);
#
# Given a line and line number this subroutines the Questions current field
# type and the data in that field.
################################################################################
sub getFieldData($$) {

    my $line = $_[0];
    my $line_number = $_[1];

    my $current_field="";
    my $data = "";

    if ($line =~ /^SHORT_EXP:(.*)$/) {
	$current_field="short_exp";
    }
    elsif ($line =~ /^LONG_EXP:(.*)$/) {
	$current_field="long_exp";
    }
    elsif ($line =~ /^QUESTION:(.*)$/) {
	$current_field="question";
    }
    elsif ($line =~ /^QUESTION_AUDIT:(.*)$/) {
	$current_field="question_audit";
    }
    elsif ($line =~ /^DEFAULT_ANSWER:(.*)$/) {
	$current_field="answer";
    }
    # What I wouldn't give for a case/switch in Perl...
    elsif ($line =~ /^YES_EXP:(.*)$/) {
	$current_field="yes_epilogue";
    }
    elsif ($line =~ /^NO_EXP:(.*)$/) {
	$current_field="no_epilogue";
    }
    elsif ($line =~ /^CONFIRM_TEXT:(.*)$/) {
	$current_field="confirm_text";
    }
# Removed REQUIRE_FILE, since now unused, and functionality
# available via internal tests.
    elsif ($line =~ /^REQUIRE_DISTRO:(.*)$/) {
	$current_field="require_distro";
    }
    elsif ($line =~ /^YN_TOGGLE:(.*)$/) {
	$current_field="toggle_yn";
    }
    elsif ($line =~ /^YES_CHILD:(.*)$/) {
	$current_field="yes_child";
    }
    elsif ($line =~ /^NO_CHILD:(.*)$/) {
	$current_field="no_child";
    }
    elsif ($line =~ /^SKIP_CHILD:(.*)$/) {
	$current_field="skip_child";
    }
    elsif ($line =~ /^PROPER_PARENT:(.*)$/) {
	$current_field="proper_parent";
    }
    elsif ($line =~ /^REG_EXP:(.*)$/) {
	$current_field="reg_exp";
    }
    elsif ($line =~ /^EXPL_ANS:(.*)$/) {
	$current_field="expl_ans";
    }
    else {
	# UH OH!!! We've found a line (inside a record)
	# that isn't recognized
	&B_log("ERROR","The following line (inside " .
	       "a record) is not recognized.\n\n$line\n\n".
	       "          Line number: $line_number\n");
	exit(1);
    }

    # OK, we know what field to assign this data to...
    $data =$1;

    $data =~ s/^\s+//; # Strip off any initiating white space
    $data =~ s/\s+$//; # Strip off any terminating white space...

    return ($current_field, $data);

}

sub distroIsAppropriate($) {
    my $require_distro=$_[0];

    my @require_distro_array;
    (@require_distro_array) = split(/\s+/,$require_distro);

    my $distro_is_appropriate=0;

    foreach my $distro ( @require_distro_array ) {
	# check for exception distros first
        if ( $distro  =~ /^not_(\S+)/ ) {
            last  if ( &GetDistro =~ $1);
	    # exception distros (not_distro) must precede all normal distros
	}
        if ($distro eq &GetDistro ) {
            $distro_is_appropriate=1;
            last; # Speed up evaluation.
        }
    }
    return $distro_is_appropriate;
}


sub prune_questions ($$) {
    my $UseRequiresRules = $_[0];
    my $first_question = $_[1];

    #######################################################################
    # Walk through $Question hash, eliminating questions that don't apply
    # to this system.  Use required_distro and test function to figure out
    # which questions to prune.  Prune by moving the parent/child pointers
    # to skip around the question.  - JJB 3/2001
    #
    # Additionally, log the information found  during the pruning to help
    # administrators and auditors discover the current state of the system's
    # hardening measures. -   JJB 4/2005
    #
    # With 3.0, this function also writes reports and calculates security scores.
    #
    # New Test-Return States Allowed in Existing Return Field
    #   See "TestingImprovement.odf" Document
    #-- RWF 5/2006
    ######################################################################


    #We'll use the TODO Flags to help make decisions about whether to prune or
    #report on a given question
    &B_TODOFlags("load");  # Add TODO-status data to the question hash

    # If we don't have a weights file, then don't print out the scoring stuff
    # Scores only have meaning if the site has agreed to the standard against
    # which they are being scored.

    my $useWeights=0;
    if (&Load_Scoring_Weights()) {
        $useWeights=1;
    }

    &OpenAuditReport($useWeights);

    # Start score computation
    my $score=0;
    my $weight=0;

    # Walk through the items/questions.

    foreach my $key (@recordnames) {
      # Perform tests:
      # Note REQUIRE_* was broken with the auditing changes,
      # so pulled the logic, since remaining REQUIRE_* tests were
      # already removed from the Questions files.
      #
      # If the distro is correct and the relevant test passes,
      # show the question.  Otherwise, skip to the skip_child
      #
      # Example:
      # REQUIRE_DISTRO: RH6.0 HP-UX11.31
      #
      # should return true iff we are on a RH6.0 or HP-UX11.31 machine
      my $question_specific_test;

      &B_log('DEBUG',"Beginning master prune loop on key: $key\n");

      if (&distroIsAppropriate($Question{$key}{"require_distro"})) {
	  # Note: UseRequiresRules doesn't work exactly like you'd expect
	  #       because in some cases "not" is implemented
	  #       using the SKIP_CHILD.  Hence, some questions are never
	  #       reached unless you SKIP another question
	  #       When this happens, change the question to use a negated
	  #       test instead of using SKIP.
	  &B_log('DEBUG',"Now making prune determination for: $key \n");
	  if ( $UseRequiresRules eq 'Y') {
#
            # Here we use the anonymous subroutines defined for each individual
            # question, which are much more flexible than just the REQUIRE_FILE
            # and REQUIRE_SUID routines.
#	      # NOTE: the anonymous subroutine stuff can get a little
#	      # weird.  What we're doing here is defining a code-block
#	      # that will be run a little later on.  The value of
#	      # $require_is_suid will be determined at the time the
#	      # code block gets run, which is run later on.  It's
#	      # still in the same scope, so it will use the same value.
#
#	      # The "return"s will return out of the anonymous sub, but not
#	      # out of the current subroutine

	      $question_specific_test =
	      sub { &B_run_test($Question{$key}{'shortModule'},$key); };

	      # run test.  If the question does not fit, then juggle pointers.

		&B_log('DEBUG',"Running tests for: $key");
		  # NOTE: here is where we actually run those anonymous
		  # subroutines defined above.
		  my @result = (&{$question_specific_test});
		  # Store results
 		  if (@result >= 1) { #Check array in scalar context to see if populated
		    $Question{$key}{'result'} = shift(@result);
		    &B_log("DEBUG","Added result $Question{$key}{'result'}");
		    if (@result == 1){  # Store Additional, Optional Field
			$Question{$key}{'result_value'} = shift(@result);
			&B_log('DEBUG',"Added result value " .
			       $Question{$key}{'result_value'} . " to $key");
		    }
		  } else {
		    $Question{$key}{'result'} = NOTEST();
		  }
		    # Create a page about the hardening item for the text/html
                    # reports if the item is audited. TODO modularize this better
		    if (&isAuditedQuestion($key)) {
			&PrintAuditPage($key);
		    	$weight += $Question{$key}{'weight'};
			if (defined($Question{$key}{'result_value'})){
                            &PrintAuditLine($key,
                                        $Question{$key}{'result'},
                                        $useWeights,
					$Question{$key}{'result_value'});
                        } else {
                            &PrintAuditLine($key,
                                        $Question{$key}{'result'},
                                        $useWeights);
                        }

		    } else {
			&B_log('DEBUG',"Will not include " . $key . " in audit ".
			       "report since no audit question.");
		    }
                    # Always print out to the runnable "config"
                    &printAuditResultToConfig($key,$Question{$key}{'result'},
                                              $Question{$key}{'result_value'});
		    # Add this item to the score if it has
		    # a question.  This restriction gets us past items that are not
		    # actually questions, items that, say, introduce a concept.
		    # Note that now test routines can return an optional "value"
		    # so the report can give greater detail, ex: umask value,
		    # etc.

# The following section deals with the interactive GUI and final scoring.
# We've already output the individual "audit lines" in the reports above.
		    if (($Question{$key}{'result'} == NOT_INSTALLED()) or
			 ($Question{$key}{'result'} == SECURE_CANT_CHANGE()) or
                         ($Question{$key}{'result'} == SECURE_CAN_CHANGE())){
			if (&isAuditedQuestion($key)) {
			    $score += $Question{$key}{'weight'};
			    &B_log("DEBUG","Question $Question{$key}{'shortModule'}.".
				   $key ." will be skipped because of test ".
				   "results.  Result:". $Question{$key}{'result'});
                            #Leave the secure, configurable q's in the q-list
			}
			if ($Question{$key}{'result'} != SECURE_CAN_CHANGE()) {
			    $first_question = &skipQuestion($key, $first_question);
			}
		    } elsif ($Question{$key}{'result'} == NOT_INSTALLED_NOTSECURE()){
			$first_question = &skipQuestion($key, $first_question);
		    }
	  }
      } else {
	$first_question = &skipQuestion($key, $first_question); # If distro is not appropriate
      }
    } #End master test loop over all records
    &B_TODOFlags("save");  # All done with the TODO Flags

    ##############################################
    #   Delete irrelevant questions.             #
    ##############################################
    foreach my $key (keys %Question) {

	if($Question{$key}{'deleteme'} eq "Y"){
	    delete $Question{$key};
	}
	else {
	    $Question{$key}{"default_answer"}=$Question{$key}{'answer'};
	}
    }

    #note score and weight are zero if no weights file
    &CloseAuditReport($score,$weight,$useWeights);

    if ($GLOBAL_AUDITONLY) {
	&announceOrDisplayReport;
    } else {
	&B_log("DEBUG","prune questions returns: $first_question");
	return $first_question;
    }
} # end pruning subroutine



#Two ways we know if the question is audited:
#1) No Audit Question Defined, or
#2) No test defined
sub isAuditedQuestion($){
    my $key = $_[0];
    &B_log("DEBUG","Determining if audit for $Question{$key}{'question_audit'}");
    #If audit question contains "word" characters and has a defined test
    if (($Question{$key}{'question_audit'} =~ /\w+/) and
        ($Question{$key}{'result'} != NOTEST())) {
	&B_log("DEBUG","$key is Audited");
	return 1; #TRUE
    } else {
	&B_log("DEBUG","$key is Not Audited");
	return 0; #FALSE
    }
}

sub announceOrDisplayReport {
    #Note that thes files are called "assessment on HP-UX vs. audit on Linux
    #via the getGlobal routines.
	my $audit_directory = &getGlobal('BDIR','assess');
	my $audit_log_file = &getGlobal('BFILE','audit_log_file');
	my $audit_report_file_html = &getGlobal('BFILE','audit_report_file_html');
	my $audit_report_file_text = &getGlobal('BFILE','audit_report_file_text');
	my $possible_browser_path='';

	&B_log ("NOTE","Bastille Hardening Assessment Completed.\n  " .
                "You can find a report in HTML format at:\n".
                ".   $audit_report_file_html\n\n".
                "You can find a report in text format at:\n".
                ".   $audit_report_file_text\n\n".
                'You can find a "config" file that will, on the same HP-UX version, '.
		'similar installed-application set, and configuration, lock-down the Bastille-relevant '.
		'items that Bastille had completely locked-down on this system below (see '.
		'html or text report for full detail).  '.
		'In cases where the systems differ, the config file may be either '.
		'a) contain extra questions not relevant to the destination system, '.
		'or b), be missing questions needed on the remote system.  Bastille will '.
		'inform you in the first case, and in the second case error.  It will then '.
		'give you an opportunity to answer the missing questions or remove the extra ones in the '.
		'graphical interface:'."\n" . ".   $audit_log_file\n\n");

	# Secret code for not having browser pop up
	my $nobrowserfile = getGlobal("BFILE","nobrowserfile");
	if ( -e $nobrowserfile)  {
	    return 1;
	}
	if ( $GLOBAL_AUDIT_NO_BROWSER ) {
	     #Gets rid of "single-use" warning... still need to clean this up though
	    my $tossvar = $GLOBAL_AUDIT_NO_BROWSER;
	    return 1;
	}

	#################
	# Open a browser
	#################

        sub findAndUseBrowser(@) {
            my @browsers = @_;

            # Give the user back some PATH information
            if (&GetDistro =~ "HP-UX"){
                $ENV{'PATH'} = "/bin:/usr/bin:/opt/bin";
            } else {
                $ENV{'PATH'} = "/bin:/usr/bin:/usr/local/bin:/opt/bin";
            }

            my $audit_report_file_html = &getGlobal('BFILE','audit_report_file_html');
            my $found_browser = "";

            foreach my $possible_browser (@browsers) {
		&B_log("DEBUG","Checking Browser $possible_browser");
                my $whichOutput = `which $possible_browser`;
                # If proposed binary is absolute path and executable
		if ((($possible_browser =~ /^\// ) and ( -x $possible_browser))) {
                    $found_browser = $possible_browser;
                #If binary is relative path and executable
                } elsif (($whichOutput !~ /^.*\/which: no/) and (-x $whichOutput)) {
                    $found_browser = $whichOutput;
                }

                if ($found_browser ne "" ) {
		    &B_log("NOTE", "Launching $possible_browser to display report.");
		    if (system("$possible_browser file://$audit_report_file_html")) {
			&B_log("DEBUG","Browser call unsuccessful.");
                        return 0; # Reverse sense, since zero exit-code is "good"
                    } else {
                        return 1;
                    }
		}
	    }
        }

	# Check for X
        my @graphical_browsers_full_path;
        my @graphical_browsers_no_path;

	if ( $ENV{DISPLAY} ne '' ) {
	    @graphical_browsers_full_path =
		('/usr/bin/mozilla','/opt/mozilla/mozilla','/usr/bin/firefox','/usr/bin/netscape',
		 '/usr/local/bin/mozilla','/usr/local/bin/firefox','/opt/local/bin/firefox',
		 '/opt/local/bin/mozilla','/sw/bin/mozilla','/sw/bin/firefox');
	    @graphical_browsers_no_path = ('mozilla','firefox','netscape');
        } else {
            &B_log("WARNING","\$DISPLAY is not set, so can not use a graphical browser, attempting text browser.\n");
            @graphical_browsers_full_path = ();
	    @graphical_browsers_no_path = ();
        }
	    my @nongraphical_browsers_full_path = ('/usr/bin/links','/usr/bin/w3m','/usr/bin/lynx');
	    my @nongraphical_browsers_no_path = ('links','w3m','lynx');

	    # Try browsers
            if ((&findAndUseBrowser(@graphical_browsers_full_path)) or
                (&findAndUseBrowser(@graphical_browsers_no_path)) or
                (&findAndUseBrowser(@nongraphical_browsers_full_path)) or
                (&findAndUseBrowser(@nongraphical_browsers_no_path))){
                return 1;
	    } else {
                &B_log("WARNING","No appropriate browser found to display report.\n");
                return 0;
            }
} # end Announce or Display Report

sub validate_questions () {
    ##############################################
    #   Run sanity checks on questions database  #
    ##############################################

    foreach my $key (keys %Question) {

	my ($parent,$yes_child,$no_child);

	$parent=$Question{$key}{"proper_parent"};
	$yes_child=$Question{$key}{"yes_child"};

	my $current_module = $Question{$key}{'shortModule'};
	my $parent_module = $Question{$parent}{'shortModule'};

        my $no_child_to_print="";

	if ($Question{$key}{"toggle_yn"}) {
	    $no_child=$Question{$key}{"no_child"};
            $no_child_to_print=$no_child;
	}

	&B_log("DEBUG","LABEL: $key\n".
	          "Yes-child: $yes_child\n".
	          "No-child:  $no_child_to_print\n".
	          "Parent:    $parent\n".
	          "Short expression:\n".
	          $Question{$key}{"short_exp"}.
	          "Long expression:\n".
	          $Question{$key}{"long_exp"}.
	          "Question:\n".
	          $Question{$key}{"question"}.
	          "\nDefault: ". $Question{$key}{"default_answer"}."\n\n");

        my $problemfound=0;
        unless ($parent) {
	    &B_log("ERROR","Problem found in Question database. $key doesn't have a parent!\n" .
                      "         This is likely to cause problems later.\n");
            $problemfound=1;
        }

        unless (exists ($Question{$parent})) {
	    &B_log("ERROR","Problem found in Question database. $key\'s parent \"$parent\"\n" .
                      "         does not exist!  This is likely to cause problems later.\n");
            $problemfound=1;
        }

	# Allows for header/footer question wrap to come later. IE Title_Screen End_Screen
	if(exists $Question{$key} && $Question{$key}{"yes_child"} !~ "End_Screen"){
            unless (exists ($Question{$yes_child})) {
	        &B_log("ERROR","Problem found in Question database. $key\'s yes_child \"$yes_child\"\n" .
                          "         does not exist!  This is likely to cause problems later.\n");
                $problemfound=1;
            }
	}

        unless ($yes_child) {
	        &B_log("ERROR","Problem found in Question database. $key has no yes child.\n" .
                          "         This is likely to cause problems later.\n");
                $problemfound=1;
        }

	if (exists $Question{$key} && $Question{$key}{"toggle_yn"}) {
            unless ($no_child) {
	        &B_log("ERROR","Problem found in Question database. $key has no no_child.\n" .
                          "         This is likely to cause problems later.\n");
                $problemfound=1;
            }

	    # Allows for header/footer question wrap to come later. IE Title_Screen End_Screen
	    if(exists $Question{$key} && $Question{$key}{"no_child"} !~ "End_Screen"){
                unless (exists ($Question{$no_child})) {
	            &B_log("ERROR","Problem found in Question database. $key\'s no_child \"$no_child\"\n" .
                              "         does not exist!  This is likely to cause problems later.\n");
                    $problemfound=1;
                }
	    }

            unless ( $Question{$key}{"question"} ) {
	            &B_log("ERROR","Problem found in Question database. y/n question $key\n" .
                              "         has no Question!  This is likely to cause problems later.\n");
                    $problemfound=1;
            }

	}

        if ($problemfound) {
           &B_log("FATAL","Earlier problems are preventing correct Bastille execution.  Exiting.\n");
        }

	# finds the first question in each module.
	if($parent_module ne $current_module){
	    # moduleHead is a global that will be sent to Interactive for progress indication
	    $moduleHead{$current_module} = ""; # cheap fix to rid perl -w warning
	    $moduleHead{$current_module} = $key;
	}

    }

}

sub OS_macro_expand($) {
    my $data = $_[0];
    my $supported_versions;
    # Replace macros with their (by design) hard-coded values,
    # making sure to respect recursively defined macros.
    if ($data =~ /\bLINUX\b/) {
	my $supported_distros = 'RH MN RHEL RHFC DB SE';
	$data =~ s/\bLINUX\b/$supported_distros/;
    }
    if ($data =~ /\bRH\b/) {
	# Note that Red Hat expands to classic Red Hat (RH), RHEL and RHFC (Fedora / Fedora Core).
	# Each of these is then expanded in a future if-block, allowing this to stay very readable.
	$supported_versions = 'RH6.0 RH6.1 RH6.2 RH7.0 RH7.1 RH7.2 RH7.3 RH8.0 RH9.0 RH9 RHEL RHFC';
	$data =~ s/\bRH\b/$supported_versions/;
    }
    if ($data =~ /\bRHEL\b/) {
	$supported_versions = 'RHEL6 RHEL5 RHEL4 RHEL3 RHEL2';
	$data =~ s/\bRHEL\b/$supported_versions/;
    }
    if ($data =~ /\bRHEL4\b/) {
	$supported_versions = 'RHEL4AS RHEL4ES RHEL4WS';
	$data =~ s/\bRHEL4\b/$supported_versions/;
    }
    if ($data =~ /\bRHEL3\b/) {
	 $supported_versions = 'RHEL3AS RHEL3ES RHEL3WS';
	$data =~ s/\bRHEL3\b/$supported_versions/;
    }
    if ($data =~ /\bRHEL2\b/) {
	$supported_versions = 'RHEL2AS RHEL2ES RHEL2WS';
	$data =~ s/\bRHEL2\b/$supported_versions/;
    }
    if ($data =~ /\bRHFC\b/) {
	# We want Fedora Core to look like a Red Hat
	# product for compatibility tests, since it is.
	$supported_versions = 'RHFC1 RHFC2 RHFC3 RHFC4 RHFC5 RHFC6 RHFC7 RHFC8 RHFC9 RHFC10 RHFC11 RHFC12 RHFC13 RHFC14 RHFC15 RHFC16';
	$data =~ s/\bRHFC\b/$supported_versions/;
    }
    if ($data =~ /\bMN\b/) {
	$supported_versions = 'MN6.0 MN6.1 MN6.2 MN7.0 MN7.1 MN7.2 MN8.0 MN8.1 MN8.2 MN10.1';
	$data =~ s/\bMN\b/$supported_versions/;
    }
    if ($data =~ /\bDB\b/) {
	$supported_versions = 'DB2.2 DB3.0';
	$data =~ s/\bDB\b/$supported_versions/;
    }
    if ($data =~ /\bSE\b/) {
	$supported_versions = 'SE7.2 SE7.3 SE8.0 SE9.0 SE9.1 SE9.2 SE9.3 SESLES';
	$data =~ s/\bSE\b/$supported_versions/;
    }
    if ($data =~ /\bSESLES\b/) {
	$supported_versions = 'SESLES8 SESLES9 SESLES10';
	$data =~ s/\bSESLES\b/$supported_versions/;
    }
    if ($data =~ /\bTB\b/) {
	$supported_versions = 'TB7.0';
	$data =~ s/\bTB\b/$supported_versions/;
    }
    if ($data =~ /\bHP-UX\b/) {
	$supported_versions = 'HP-UX11.11 HP-UX11.23 HP-UX11.31 HP-UX11.31SRPhost HP-UX11.31SRPcont';
	$data =~ s/\bHP-UX\b/$supported_versions/;
    }
    if ($data =~ /\bOSX\b/) {
	$supported_versions = 'OSX10.2 OSX10.3 OSX10.4';
	$data =~ s/\bOSX\b/$supported_versions/;
    }
    return ($data);
}

###########################################################################
# &ReadConfig reads in the user's choices from the UI, stored in the file
# specified in the argument.
###########################################################################
sub ReadConfig($) {

    my $configfile = $_[0];

    my $validfile=1;

    %GLOBAL_CONFIG=();
    if (open CONFIG, $configfile) {
	while (my $line = <CONFIG>) {
	    chomp $line;
	    # Skip commented lines...
	    unless ($line =~ /^\s*\#/) {
		if ($line =~ /^\s*(\w+).(\w+)\s*=\s*\"(.*)\"/ ) {
		    $GLOBAL_CONFIG{$1}{$2}=$3;

		    if (exists $Question{$2}) {
			# This is only used by the front end to populate the
			# "defaults".  It will cause problems with the back end
			# if we accidentally create a %Question entry based on
			# the config file for a question that didn't exist
			$Question{$2}{'answer'} = $3;
		    }
		}  # if the line contains non-whitespace
		elsif($line !~ /^\s*$/) {
		    &B_log("WARNING","The following line in the configuration file is invalid:\n" .
			      "$line\n" .
			      "The line will be disregarded.\n\n");
                    $validfile=0;
		}
	    }
	}
        close CONFIG;
        return $validfile; # Returns false if the config file is invalid
    }

    # Failed to open config
    return 0;
}

##############################################
# sub skipQuestion -- Prune the question out of the tree
# This is rudimentary pointer mangling.  There are serious speed-ups
# that we can make by thinking more about tree traversals -- this
# is the "simple" implementation intended to introduce the
# functionality.  Let's speed it up later.
#
# - JJB 3/2001
##############################################
sub skipQuestion ($$) {
    my $key = $_[0];
    my $first_question = $_[1];

    &B_log('DEBUG',"Skipping ". $key ." in question pruning.\n ");

    my $parent=$Question{$key}{"proper_parent"};
    my $child;

    # Choose the next question to go to carefully
    if ($Question{$key}{"yes_child"} eq $Question{$key}{"no_child"}) {
        $child = $Question{$key}{"yes_child"};
    }

    # if there is a skip child, use it
    if (defined $Question{$key}{"skip_child"}) {
        $child = $Question{$key}{"skip_child"};
    }

    #Now do the pruning.
    if ($child) {
    # insure that first question is a valid question
	if("$key" eq "$first_question"){
	    $first_question = $child;
	}
	my $loop_over_key;
	&B_log("DEBUG","Pruning Key: " . $key);
	foreach $loop_over_key (keys(%Question)) {
	    # Any questions which have the phantom question as a child
	    # should now point to the phantom's child instead.
	    if ($Question{$loop_over_key}{"yes_child"} eq $key) {
	        $Question{$loop_over_key}{"yes_child"}=$child;
	    }
	    if ($Question{$loop_over_key}{"no_child"} eq $key) {
	        $Question{$loop_over_key}{"no_child"}=$child;
	    }
	    # This gets tricky...think about this one deeply before
	    # emailing me on this.  - JJB
	    if ($Question{$loop_over_key}{"proper_parent"} eq $key) {
	        $Question{$loop_over_key}{"proper_parent"}=$parent;
	    }
	}
	if(&distroIsAppropriate($Question{$key}{"require_distro"})) {
	    $deletedQText{$key} = $Question{$key}{'question'};
	}
	$Question{$key}{'deleteme'} = "Y";
	} else {
	    &B_log("ERROR","Question $key couldn't be skipped because Bastille\n" .
	           "         couldn't figure out which question to skip to!\n");
	}
    return $first_question;
}

######################################################################
# compareQandA($first_question)
#      This subroutine takes the pruned questions hash and the
#      GLOBAL_CONFIG hashes and does an index compare of the two
#      This program is meant to be run just before the back end
#      It is designed to insure multi-system support.  That is,
#      it tests the config file for question validity on the current
#      machine before the back end will run.
#
#      This function returns:
#        0 for WARNING questions were not answered or questions were
#          answered that do not apply to the current system.
#        1 for correct match of questions and answers.
#
#      REQUIRES %Question
#      REQUIRES %GLOBAL_CONFIG
#      REQUIRES &ActionLog
#      REQUIRES &ErrorLog
#
######################################################################

sub compareQandA($$) {
###
    my $first_question = $_[0];
    my $force = $_[1];
    my $returnValue = "";
    my $sumNotAsked = 0;
    my $warnFlag = 0;

    # this checks to see if any questions were not answered that should
    # have been.
    my ($moduleNotAnswered,$questionNotAnswered) = &checkQtree($first_question);


    # if checkQtree returns a question that has not been answered
    if ($questionNotAnswered ne "" && ! $force) {
	&B_log("FATAL","A fatal error has occurred. Not all of the questions\n" .
		  "that pertain to this system have been answered.  Rerun\n" .
		  "the interactive portion of Bastille on this system.\n" .
		  "MODULE.QUESTION=$moduleNotAnswered.$questionNotAnswered\n");
	exit(1);
    }

    # This section checks to see if a question was answered that does
    # not make sense on this machine.
    for my $module ( keys %GLOBAL_CONFIG ) {
	for my $key (keys %{$GLOBAL_CONFIG{$module}}){
	    # check to see if the question should be answered
	    if( (!(exists $Question{$key}) ) || ($Question{$key}{"mark"} ne "OK") ){
		# This prunes the answer out if the question should
		# not have been answered
		my $parent = $Question{$key}{'proper_parent'};
		my $parentMod = $Question{$parent}{'shortModule'};

		# This logic tells us if other values in the config will be affected by removing this answer
		if($Question{$parent}{'toggle_yn'} eq "1")  {

		    if($Question{$parent}{'no_child'} ne $Question{$parent}{'yes_child'}) {

			if($Question{$parent}{'no_child'} eq $key && $GLOBAL_CONFIG{$parentMod}{$parent} eq "Y"){
			    $warnFlag = 1;
			}
			elsif($Question{$parent}{'yes_child'} eq $key && $GLOBAL_CONFIG{$parentMod}{$parent} eq "N"){
			    $warnFlag = 1;
			}
		    }
		}
		if(! $force) {
		    delete $GLOBAL_CONFIG{$module}{$key};
		    &B_log("DEBUG", "$module\.$key was removed (not applicable).\n");
		    # checking to see if this answer is appropriate for this OS.
		    if(! exists $deletedQText{$key} ) {
			# Warn the user that this question will not run on
			# their system as it is was not designed for their OS.
####&B_log("WARNING","$module\.$key was removed (not applicable).\n");
		    }

		    $sumNotAsked++;
		}
	    }

	}
    }

    # Logging this subroutines actions.

    if($sumNotAsked > 0){

	&B_log("DEBUG","$sumNotAsked question(s) were answered that do not pertain to this system.\n" .
	       "Answered questions that do not pertain to this machine have\n" .
	       "been removed.\n");

	if($warnFlag){
	    &B_log("NOTE","The configuration file appears to contain invalid or extra entries.\n" .
		   "Bastille will continue but you should rerun the interactive\n" .
		   "portion of Bastille to correct the invalid portions of the\n" .
		   "configuration file, or remove extra questions not necessary for this system.\n\n");
	}

	$returnValue = 0;
    }

    # return 1 for success and 0 for Warnings that were reported.
    return $returnValue;
}

######################################################################
#  &validateAnswer($question,$answer)
#     This subroutine takes the in the LABEL of a question and the
#     answer that is being proposed.  Both in string form
#     It then checks the proposed answer against a regular expression
#     that is listed in the Questions files as REG_EXP and in the Question
#     hash as $Question{$question}{"reg_exp"}.
#     If the reg_exp matches the proposed question then 1 is returned
#     otherwise 0 is returned.
#     An exception to this rule is if the reg_exp field is not present
#     then an 1 is returned suggesting that any answer will do.
#
#     REQUIRES %Questions
#     REQUIRES &ErrorLog
#     REQUIRES &getRegExp
#
######################################################################
sub validateAnswer($$) {

    my $question = $_[0];
    my $answer = $_[1];

    my $pattern = &getRegExp($question);

    if( defined($pattern)){
	return ( $answer =~ /$pattern/ ); # Return True iff answer is matched by pattern
    }
    elsif( exists $Question{$question} ) {
	return 1;
    }
    else {
	&B_log("ERROR","Could not find \"$question\" in the Questions hash\n");
	return 0;
    }


}

######################################################################
#  &validateAnswers
#     This subroutine checks the proposed answers against a regular
#     expressions that are listed in Questions files as REG_EXP and in
#     the Question hash as $Question{$question}{"reg_exp"}.
#     If the reg_exp matches for all the proposed answers then 1 is
#     returned otherwise a non-zero exit is performed and the user
#     is asked to rerun Interactive Bastille.
#
#     This subroutine is to be used in the back end as a qualifier to
#     running the code.
#
#     REQUIRES %GLOBAL_CONFIG
#     REQUIRES %Questions
#     REQUIRES &validateAnswer
#     REQUIRES &ActionLog
#     REQUIRES &ErrorLog
#
######################################################################

sub validateAnswers {

    for my $module ( keys %GLOBAL_CONFIG ){
	for my $question (keys %{ $GLOBAL_CONFIG{$module} } ){

	    my $answer = $GLOBAL_CONFIG{$module}{$question};
	    if(! &validateAnswer($question,$answer)){
		my $error = "A fatal error has occurred. On the following\n" .
		      "line of Bastille's config, the specified answer does\n" .
		      "not match the following Perl regular expression.\n" .
		      "config: $module.$question=$answer\n" .
		      "Regular Expression: \"". &getRegExp($question) . "\"\n" .
		      "Please run the interactive portion of Bastille again\n" .
		      " and fix the error.\n";
		&B_log("ERROR", $error );
		exit(1);
	    }
	}
    }

   &B_log("DEBUG","Validated config file input\n");
    return 1;
}

######################################################################
#  &getRegExp($question)
#     This subroutine is a lookup function that for a given question
#     label will return a regular expression that is defined.
#     If no regular expression is defined for that question then
#     this subroutine will return undefined.
#
#     REQUIRES: %Questions
#
######################################################################

sub getRegExp($) {

    my $question = $_[0];

    if( exists $Question{$question}{"reg_exp"} ) {
	return $Question{$question}{"reg_exp"};
    }
    else {
	return undef;
    }
}

######################################################################
#  &checkQtree($first_question);
#    This subroutine checks to see if all applicable Questions
#    have been asked on this system.  If it finds a discontinuity
#    in the pruned questions tree vs the GLOBAL_CONFIG hash it will
#    return the ($offending_module,$offending_key).  Otherwise it
#    will return NULL stings.  i.e. ("","")
#
#    This subroutine also marks the questions that have answers in
#    the GLOBAL_HASH.  This allows &compareQandA to actively delete
#    GLOBAL_HASH keys if they are not appropriate for the current
#    machine.
#
#    REQUIRES: %Questions
#    REQUIRES: %GLOBAL_CONFIG
#
######################################################################

sub checkQtree($) {

    my $first_question = $_[0];
    my $current_question = $first_question;

    if ($current_question eq "") {
        &B_log("FATAL","Internal Error: Can not continue without valid question to check");
    }

    &B_log("DEBUG","SPC Child Entering CheckQTree is: ".
	   $Question{'spc_run'}{'yes_child'} );
    while( $current_question ne "End_Screen" ) {
	&B_log("DEBUG","checkQtree::Checking: $current_question");
	my $module = $Question{$current_question}{"shortModule"};

	# check and see if this record is a question...
	if( $Question{$current_question}{"question"} ne "" ) {
	    # This question should have an answer...
	    if( ! (exists $GLOBAL_CONFIG{$module}{$current_question})){
		# This question has no answer and should...
		return ($module,$current_question);
	    }
	    elsif($Question{$current_question}{"toggle_yn"} == 1) {
		# this is a yes or no question
		if($GLOBAL_CONFIG{$module}{$current_question} eq "Y"){
		    $Question{$current_question}{"mark"} = "OK";
		    $current_question=$Question{$current_question}{"yes_child"};
		}
		else {
		    $Question{$current_question}{"mark"} = "OK";
		    $current_question=$Question{$current_question}{"no_child"};
		}

	    }
	    else {
		$Question{$current_question}{"mark"} = "OK";
		$current_question=$Question{$current_question}{"yes_child"};
	    }
	}
	else {
	    $current_question=$Question{$current_question}{"yes_child"};
	}

    }
    # all of the questions that should be answered are.
    return ("","");
}
######################################################################
#  &outputConfig;
#
#    This subroutine writes out a configuration
#    file.  It uses Global_Config as a data source and will write
#    out all defined values excepting End_Screen.
#
#    REQUIRES: %GLOBAL_CONFIG
#    REQUIRES: %Question
#    REQUIRES: %deletedQText
#
######################################################################

# When does a previously answered question get written out to the
# config file?

#Always write out answers to questions which the user just answered.
#
#For answers which were retrieved from the config file, there are the
#following cases:
#
#Case                        write    GUI behavior       back end behavior
#                            answer?  (questions)        (if answer is missing)
#----------------------------------------------------------------------------
# Pruned (can't get to in GUI):
#  Configured Securely              Y      don't ask          don't warn
#  Missing software
#    - Security related             Y      ask different Q    ensure other Q
#                                          (install foo?)     is answered
#    - non-security related         Y      don't ask          don't warn
#
#  distro not applicable            Y      warn (not asking   warn (not doing
#                                          foo)               foo)
# Not pruned:
#  Question depends on Y/N
#    from another question          N      ask Q if user      warn (invalid
#                                          changes answer     config)
sub outputConfig {

    my %CONFIG;

    my $config = &getGlobal('BFILE', "current_config");

#   Needs to use a tree traversal as well as the proper distro deletion items
    my $index="Title_Screen";

    while ($index ne "End_Screen") {

	if ($Question{$index}{"question"} ne "" && exists $Question{$index}{"answer"}) {

	    # If the answer is just a space (the way the &Prompt_Input sub
	    # designates a blank line, strip it.
	    if ($Question{$index}{"answer"} =~ /^\s+$/) {
		$Question{$index}{"answer"} = "";
	    }

	    my $module = $Question{$index}{"shortModule"};

	    # adding this question to the config hash which will be written out
	    $CONFIG{$module}{$index} = $Question{$index}{"answer"};


	}
	if ($Question{$index}{"toggle_yn"} == 0) {
	    $index=$Question{$index}{"yes_child"};
	}
	else {
	    if ($Question{$index}{"answer"} =~ /^\s*Y/i) {
		$index=$Question{$index}{"yes_child"};
	    }
	    elsif ($Question{$index}{"answer"} =~ /^\s*N/i) {
		$index=$Question{$index}{"no_child"};
	    }
	    else {
                &B_log("ERROR","Internal Bastille error on question $index.  Answer\n" .
                          "to y/n question is not 'Y' or 'N'.\n");
	    }
	}
    }

    # We already got the answers which the user just put in, so now we start
    # looping through the GLOBAL_CONFIG looking for deleted questions that
    # have been answered (possibly due to an OS switch or the action
    # already having been performed and it does not make sense to attempt to
    # perform the action) i.e. the configurable software is not installed.
    foreach my $module_cursor (keys %GLOBAL_CONFIG) {
	foreach my $question (keys %{$GLOBAL_CONFIG{$module_cursor}}) {
	    if((defined $GLOBAL_CONFIG{$module_cursor}{$question}) && ($module_cursor ne "End")){
		# if the question is defined in the deletedQText hash then
                # it is distro appropriate and therefore should be saved
                # to maintain state across Bastille back end/front end runs.
		if( defined $deletedQText{$question} ){
		    $CONFIG{$module_cursor}{$question} = $GLOBAL_CONFIG{$module_cursor}{$question};
		}
	    }
	}
    }

    # create the config directory if it doesn't exist
    if( ! -d dirname(&getGlobal ("BFILE", "current_config"))) {
	mkpath(dirname(&getGlobal ("BFILE", "current_config")),0,0700);
    }

    # it is finally time to print the config file out.
    unless (open FORMATTED_CONFIG,"> $config") {
        &B_log("ERROR","Couldn't not write to " . $config  ."\n");
        exit(1);
    }

    foreach my $other_module_cursor (sort keys %CONFIG) {
	foreach my $question_cursor (sort keys %{$CONFIG{$other_module_cursor}}) {
	    if((defined $CONFIG{$other_module_cursor}{$question_cursor}) && ($other_module_cursor ne "End")){
		# if the question is defined in the Question hash then
		if( defined $Question{$question_cursor}{'question'} ) {
		    print FORMATTED_CONFIG "# Q:  $Question{$question_cursor}{question}\n";
		    print FORMATTED_CONFIG "$other_module_cursor\.$question_cursor=\"$GLOBAL_CONFIG{$other_module_cursor}{$question_cursor}\"\n";
		}
		# if the question is defined in the deletedQText hash then
                # it is distro appropriate and therefore should be saved
                # to maintain state across Bastille back end/front end runs.
		elsif( defined $deletedQText{$question_cursor} ){
		    print FORMATTED_CONFIG "# Q:  $deletedQText{$question_cursor}\n";
		    print FORMATTED_CONFIG "$other_module_cursor\.$question_cursor=\"$GLOBAL_CONFIG{$other_module_cursor}{$question_cursor}\"\n";
		}

	    }
	}
    }

    close(FORMATTED_CONFIG);


}



######################################################################
#  &partialSave;
#
#    This subroutine writes out an incomplete configuration
#    file.  It uses Global_Config as a data source and will write
#    out all defined values excepting End_Screen.
#
#    REQUIRES: %GLOBAL_CONFIG
#    REQUIRES: %Question
#    REQUIRES: %deletedQText
#
######################################################################

sub partialSave {
    my $config = &getGlobal('BFILE', "current_config");
    unless (open FORMATTED_CONFIG,"> $config") {
        &B_log("ERROR","Couldn't not write to " . $config  ."\n");
        exit(1);
    }

    foreach my $module (sort keys %GLOBAL_CONFIG) {
	foreach my $question (sort keys %{$GLOBAL_CONFIG{$module}}) {
	    if((defined $GLOBAL_CONFIG{$module}{$question}) && ($module ne "End")){
		# if the question is defined in the Question hash then
		if( defined $Question{$question}{'question'} ) {
		    print FORMATTED_CONFIG "# Q:  $Question{$question}{question}\n";
		    print FORMATTED_CONFIG "$module\.$question=\"$GLOBAL_CONFIG{$module}{$question}\"\n";
		}
		# if the question is defined in the deletedQText hash
                # then it is distro appropriate and therefore should be
                # saved to maintain state across Bastille back end/front end runs.
		elsif( defined $deletedQText{$question} ){
		    print FORMATTED_CONFIG "# Q:  $deletedQText{$question}\n";
		    print FORMATTED_CONFIG "$module\.$question=\"$GLOBAL_CONFIG{$module}{$question}\"\n";
		}
	    }
	}
    }

    close(FORMATTED_CONFIG);

}



######################################################################
#  &isConfigDefined($)
#
#    This subroutine returns a 1 in the given Module exists in
#    the GLOBAL_CONFIG hash.  A 0 is returned otherwise.
#
#    REQUIRES: %GLOBAL_CONFIG
#
######################################################################

sub isConfigDefined($) {

    my $module=$_[0];
    if(exists $GLOBAL_CONFIG{$module}) {
	B_log("DEBUG", "$module exists in the GLOBAL_CONFIG hash");
	return 1;
    }
    else {
	B_log("DEBUG", "$module does not exist in the GLOBAL_CONFIG hash");
	return 0;
    }
}

######################################################################
# &Load_Scoring_Weights()
#
# This routine loads the weights that Bastille will use to score the
# system during its assessment/auditing phase.
#
######################################################################

sub Load_Scoring_Weights {

    my $total_weight = 0;
    my $tossvar = $GLOBAL_AUDITONLY; # temporary workaround to single-use warning
    # Get the list of questions files, each corresponding to one module
    if ((open QUESTIONS_WEIGHTS,&getGlobal('BFILE','QuestionsWeights') and
	 ($GLOBAL_AUDITONLY))) {
	&B_log("NOTE","Weights file present at: " .
	       &getGlobal('BFILE','QuestionsWeights') .
	       ", so Bastille will score system ");
    } else {
	return 0; #False
    }

    # Load in the weights file entirely.
    my @lines = <QUESTIONS_WEIGHTS>;

    # Load in the name of the weights file.
    my $line = shift @lines;
    if ($line =~ /^Weights\s*:\s*(.*)\s*$/ ) {
	$weights_name = $1;
    }
    else {
	unshift @lines,$line;
    }

    # Load in the raw, non-calibrated weights.
    foreach $line (@lines) {
	next if ($line =~ /^\s*\#/);
	next if ($line =~ /^\s*$/);

	if ($line =~ /^\s*(\w+)\s*\.\s*(\w+)\s*=\s*(\d+)\s*$/) {
	    my $key = $2;
	    my $weight = $3;
	    $Question{$key}{'weight'} = $weight;
	    $total_weight += $weight;
	}
	else {
	    &B_log("WARNING","The following weight line cannot be parsed:\n$line\n");
	}
    }
    close QUESTIONS_WEIGHTS;

    return 1;

    # Calibrate the weights.

#Commenting out dead code below -rwf
#    my $calibration_factor = ( 10 / $total_weight );
#
#    foreach $key (keys(%Question)) {
#	$Question{$key}{'weight'} *= $calibration_factor;
#	$Question{$key}{'weight'} = sprintf "%2.2f",$Question{$key}{'weight'};
#    }
}

sub PrintAuditPage {
    my $key = $_[0];
    my $audit_directory = &getGlobal('BDIR','assess');
    my $questionSubdir = &getGlobal('BDIR','QuestionData');
    my $questiondata = $audit_directory . "/" . $questionSubdir ;

    return unless ($GLOBAL_AUDITONLY);

    # Write a page for the question itself.
    unless ( -d $audit_directory ) {
	mkdir ($audit_directory,0700);
    }
    unless ( -d $questiondata ) {
	mkdir ($questiondata,0755);
    }
    my $question=$Question{$key}{'question'};
    if ($Question{$key}{'question_audit'}) {
        $question = $Question{$key}{'question_audit'};
    }
    my $explanation=$Question{$key}{'short_exp'};
    if ($Question{$key}{'long_exp'}) {
	$explanation=$Question{$key}{'long_exp'};
    }

    if (open QUESTIONPAGE,">$questiondata/$key.html") {
	print QUESTIONPAGE "<HTML>\n<HEAD><TITLE>" . $question . "</TITLE></HEAD>\n<BODY>\n";
	print QUESTIONPAGE "<TABLE cellspacing=1 cellpadding=1 border=4 frame=border><TR><TD><PRE>" . $question . "</PRE></TD></TR>\n";
	print QUESTIONPAGE "<TR><TD>" . $explanation . "</TD></TR>\n";
	print QUESTIONPAGE "</TABLE>\n</BODY>\n</HTML>\n";
	close QUESTIONPAGE;
    }
    else {
	B_log("ERROR","Could not open $questiondata/$key.html");
    }

    # Continue to write the report and log.
}

sub formattedScore($$){
    my $score=$_[0];
    my $weight=$_[1];

    my $formatted_score;
    if ($weight == 0 ) {
        $formatted_score = "0.00";
    } else {
        $formatted_score = sprintf "%2.2f",($score/$weight*100); #Changed to percentage per usability feedback
        $formatted_score .= "% (100% possible)";
    }
    return $formatted_score;
}

sub htmlPreamble($$$){

    my $score=$_[0];
    my $weight=$_[1];
    my $useWeights = $_[2];

    my $bastImage=getGlobal('BFILE','bastille.jpg');
    my $audit_report_html_preamble = '';
    my $tooltipFile=getGlobal('BFILE','wz_tooltip.js');
    #yes AssesReportFunctions is misspelled, but consistently :-)
    my $expansionFile=getGlobal('BFILE','AssesReportFunctions.js');
    my $javaContractFunction='';

    # Add introductory text/formatting to the reports.
    $audit_report_html_preamble .= <<END_HTML;
<HTML>
<HEAD>
<TITLE>Bastille Hardening Assessment Report</TITLE>
END_HTML

    # Add Javascript for the expansion/contraction functionality.
    $audit_report_html_preamble .=  &JavascriptExpansionHeader();
    # Add our inline stylesheet
    $audit_report_html_preamble .= &InlineStyleSheet;


    $audit_report_html_preamble .= <<END_HTML;
</HEAD>
<BODY>
END_HTML

    $audit_report_html_preamble .= qq~<script language="JavaScript" type="text/javascript" src="$tooltipFile"></script>\n~;
    $audit_report_html_preamble .= '<img src="' . $bastImage .'">';

    $audit_report_html_preamble .= <<END_HTML;
<CENTER>
<H3>Bastille Hardening Assessment Report</H3>
</CENTER>
END_HTML

    if ( -e $expansionFile ) {
	 $javaContractFunction .= qq~
           <hr><div>
           <a href="javascript:sweeptoggle('contract')">Contract all Modules</a>
           | <a href="javascript:sweeptoggle('expand')">Expand all Modules</a>
           </div>~;
    }


    if ($useWeights) {
        $audit_report_html_preamble .=
	qq~<TABLE cellspacing=1 cellpadding=1 border=4 frame=border class="score"><TR><TD class="scoreword">~ .
	    "<b>Score</b></TD><TD><b>Weights File</b></TD></TR><TR><TD class=\"scorenumber\">" .
	&formattedScore($score,$weight) . "</TD><TD> $weights_name </TD></TR>\n</TABLE>\n";
    }

    # Load in our Javascript library used for the mouseover descriptions
    $audit_report_html_preamble .= qq~</TABLE>\n </DIV>\n
        <script language="JavaScript" type="text/javascript" src="$tooltipFile"></script>\n~ .
	"</BODY>\n</HTML>\n";
        return $audit_report_html_preamble;
}


# This function opens all the report filehandles and puts some initial text
# in the text report.  TODO: Move this into LogAPI functions, and leverage
# existing LogAPI better.


sub OpenAuditReport($) {

    my $useWeights = $_[0];

    return unless ($GLOBAL_AUDITONLY);

    # Open the Audit report files - text and html.
    my $audit_directory = &getGlobal('BDIR','assess');
    my $audit_log_file = &getGlobal('BFILE','audit_log_file');
    my $audit_report_file_html = &getGlobal('BFILE','audit_report_file_html');
    my $audit_report_file_text = &getGlobal('BFILE','audit_report_file_text');

    unless ( -d $audit_directory ) {
	mkdir $audit_directory,0700;
	chmod 0700,$audit_directory;
    }
    unless ((open AUDIT_LOG,">$audit_log_file") and
            (open AUDIT_REPORT_HTML,">$audit_report_file_html") and
            (open AUDIT_REPORT_TEXT,">$audit_report_file_text")){
        &B_log("FATAL","Could not open ". $audit_log_file .
               ", " . $audit_report_file_html . ", or " .
               $audit_report_file_text . "for writing.  Can not produce report.");
    }

    my ($textLineHeader, $textWordHeader);

    if ($useWeights) {
        $textLineHeader = '+' . '-' x 33 . '+' .  '-' x 42 . '+' . '-' x 16 . '+' .
            '-' x 8 . '+' . '-' x 7 . "+\n";
        $textWordHeader = '| Item' . ' ' x 28 . '| Question' . ' ' x 33 .
            '| Result(Detail) | Weight | Score |'."\n";
    } else {
        $textLineHeader = '+' . '-' x 33 . '+' .  '-' x 42 . '+' . '-' x 16 . '+'."\n";
        $textWordHeader = '| Item' . ' ' x 28 . '| Question' . ' ' x 33 .
            '| Result(Detail) |'."\n";
    }

    print AUDIT_REPORT_TEXT "Bastille Hardening Assessment Report\n" .
      $textLineHeader . $textWordHeader . $textLineHeader;
}

######################################################################################################
# &PrintAuditLine prints a line in a table corresponding to the Bastille item $key,
# which is a question index from the %Questions hash.  It prints this line to several files, and
# thus in several formats: html, text and machine-parseable text.  The $test_result tells the
# routine whether this item is hardened or not.
#
######################################################################################################

sub PrintAuditLine ($$$;$){
    my $key = $_[0];
    my $test_result = $_[1];
    my $useWeights = $_[2];
    my $details = $_[3];


    return unless ($GLOBAL_AUDITONLY);

    my %test_result_text = (NOTSECURE_CAN_CHANGE() => "No",
                         SECURE_CANT_CHANGE() => "Yes*",
                         NOT_INSTALLED() => "N/A: S/W Not Installed",
                         INCONSISTENT() => "System In Inconsistent State",
                         MANUAL() => "User Action Pending",
			 NOTEST() => "N/A, Doesn\'t Affect System",
                         SECURE_CAN_CHANGE() => "Yes*",
			 STRING_NOT_DEFINED() => "Not Defined",
			 NOT_INSTALLED_NOTSECURE() => "Needed S/W Missing");

    &B_log("DEBUG","PrintAuditLine called for $key with result: $test_result on key $key ".
           "useWeights: $useWeights, and details: $details");

    my $configFileResult = &getConfigFileResult($test_result,$details);

    # The label gives the question context.
    my $module =  $Question{$key}{'shortModule'};
    my $label = "$module : $key";
    my $questionSubdir = &getGlobal('BDIR','QuestionData');

    #   Let's put a module line in every time we switch modules.
    #   This allows us not to put a module name on every question.
    if ($module ne $currentModule) {
	if ($currentModule ne "") {
	    $audit_report_html_lines .= "</table>\n";
	    $audit_report_html_lines .= "</div>\n";
	}
	$audit_report_html_lines .=
            qq~<h3 onClick="expandcontent(this, '$module')" style="cursor:hand; cursor:pointer"><span class="showstate"></span>$module</h3>\n~ .
	    qq~<div id="$module" class="switchcontent" style="display: block">\n~ .
	    "<TABLE border=4 frame=border>\n" ;
	    if ($useWeights) {
                $audit_report_html_lines .=
                  qq~<TR><TD class="item">Item</TD><TD class="question">Question</TD><TD class="state">State</TD><TD class="weight">Weight</TD><TD class="scorecontrib">Score Contrib</TD></TR>\n~;
            } else {
                $audit_report_html_lines .=
                  qq~<TR><TD class="item">Item</TD><TD class="question">Question</TD><TD class="state">State</TD></TR>\n~;

            }
	$currentModule = $module;
    }
    $label = $key;

    #########################
    $question = $Question{$key}{'question_audit'};


    # Generate a result and a score-contribution number.
    my $result = $test_result_text{$test_result};
    my $score_contribution = "0.00";
    if ($configFileResult !~ /^(?:N|0|-1)$/) {
        $score_contribution = $Question{$key}{'weight'};
    }

    #Add non-boolean results to report
    if (defined($details)) {
	$result = "Set To: $details";
    }


    my $score_contribution_formatted = sprintf "%-2.2f",$score_contribution;

    # Create a version of the question that shows an explanation on mouseover.
    my $shortexp = &escape_quotes_or_apostrophes( $Question{$key}{'short_exp'} );

    my $weightScoreLines='';
    if ($useWeights) {
        $weightScoreLines = "<td>" . $Question{$key}{'weight'} . "</td>" .
          "<td>" . $score_contribution_formatted . "</td>";
          # Print this information out in a text-only format.
          printf AUDIT_REPORT_TEXT "| %-31.31s | %-40.40s | %-14.200s | %-2.2f   | %-2.2f  |\n",
                $label,$question,$result,$Question{$key}{'weight'},$score_contribution_formatted;
    } else {
        printf AUDIT_REPORT_TEXT "| %-31.31s | %-40.40s | %-14.200s |\n",
                $label,$question,$result;
    }

    # Print a row in the HTML table for this item.
    $audit_report_html_lines .= "<tr>" . "<td>$label</td>" .
    qq~<td><a href="$questionSubdir/$key.html" onmouseover="return escape('$shortexp')">$question</a></td>~ .
    "<td>" . $result . "</td>" . $weightScoreLines . "</tr>\n";



}

sub printAuditResultToConfig($$$) {
    my $key = $_[0];
    my $test_result = $_[1];
    my $details = $_[2];

    # Print the answer out for the machine-parseable log.
    #skip string value questions if we don't have an answer
    if ($test_result != STRING_NOT_DEFINED()) {
	print AUDIT_LOG $Question{$key}{'shortModule'} . '.' . $key . "=\"" .
	&getConfigFileResult($test_result,$details) . "\"\n";
    }
}

sub getConfigFileResult($$) {
    my $test_result = $_[0];
    my $details     = $_[1];

    my $config_file_result = "N";

    if (($test_result == SECURE_CANT_CHANGE()) or ($test_result == NOT_INSTALLED()) or
        ($test_result == SECURE_CAN_CHANGE())) {
        $config_file_result = 'Y';
    }
    if (defined($details)) {
        $config_file_result=$details;
    }
    return $config_file_result;
}


sub escape_quotes_or_apostrophes {
    my $content = $_[0];

    $content =~ s/'/\\'/g;
    $content =~ s/`/\\`/g;
    $content =~ s/\"/&quot;/g;
    $content =~ s/\n/<br>/g;
    return $content;
}

sub JavascriptExpansionHeader {

    my $header = '';

    my $scriptfile = &getGlobal('BFILE','AssesReportFunctions.js');
    if ( -e $scriptfile ) {
	$header = '<script type="text/javascript">\n' .
	`cat $scriptfile` .
	'\n</script>';
    }
    return $header;
}

sub InlineStyleSheet {
    my $sheet;
    # Fixed cell cut-off and too-wide pages by making these "suggestions"
    # vs. fixed table layout
    $sheet = <<ENDSHEET;
<style type="text/css">
    body {
        color: black;
	background-color: white;
	font-family: Georgia, "Times New Roman",Times, serif;
      }
    h3 {
	font-family: Helvetica, Geneva, Arial,SunSans-Regular, sans-serif;
    }
    table {
      width: 100%;
    }
    table.score {
      width: 20%;
    }
    TD {
      width: 10%;
    }
    TD.item {
      width: 15%;
    }
    TD.question {
      width: 50%;
    }
    TD.state {
      width: 5%;
    }
    TD.weight {
      width: 5%;
    }
    TD.scorecontrib {
      width: 5%;
    }
    TD.scoreword {
      width: 6%;
    }
    TD.scorenumber {
      width: 14%;
    }

</style>

ENDSHEET
    return $sheet;
}

sub CloseAuditReport ($$$){

    ##############################################
    # Wrap up auditing report.
    ##############################################
    my $score = $_[0];
    my $weight = $_[1];
    my $useWeights = $_[2];

    my $tooltipFile=getGlobal('BFILE','wz_tooltip.js');

    return unless ($GLOBAL_AUDITONLY);
    
    my $footnote="* Yes generally means Bastille determined that the described action was taken\n".
                            "  to make the system more secure.  \n".
                            "- Note also that the formatted-text and HTML reports do not include items for which\n".
                            "  status cannot be automatically determined.";

    print AUDIT_REPORT_HTML &htmlPreamble($score, $weight, $useWeights);
    print AUDIT_REPORT_HTML $audit_report_html_lines;

    if ($useWeights){
        print AUDIT_REPORT_TEXT '+' . '-' x 33 . '+' .  '-' x 42 . '+' . '-' x 16 . '+' . '-' x 8 . '+' . '-' x 7 . "+\n";
        print AUDIT_REPORT_TEXT "Score: " . &formattedScore($score,$weight) . "\n\n";
    } else {
        print AUDIT_REPORT_TEXT '+' . '-' x 33 . '+' .  '-' x 42 . '+' . '-' x 16 . "+\n\n";
    }
    
    print AUDIT_REPORT_TEXT "$footnote";
    
    #todo:make sure the  table end-tag generated correctly in the 1st place
    print AUDIT_REPORT_HTML "</table></div><pre>$footnote</pre>"; 

    close AUDIT_REPORT_TEXT;
    close AUDIT_REPORT_HTML;
    close AUDIT_LOG;
}

1;



