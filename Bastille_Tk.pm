#!/usr/bin/perl

# (c) Copyright2000-2005 Jay Beale
# (c) Copyright Hewlett-Packard Development Company, L.P. 2001-2007
# Tk additions copyright (C) 2000 by Paul L. Allen
# Licensed under the GNU General Public License, version 2.
#
# Additional changes, corrections, and feature enhancements are
# licensed under the GNU General Public License.

# This is a Tk interface for Bastille.  It is derived from
# the Bastille-1.1.1 InteractiveBastille.pl script, with the logic
# warped into the events-and-callbacks programming model typical
# of X programming.  It requires the Tk.pm Perl module and at
# least the X client runtime libraries.  The new version of the &Ask
# function is called from the callback attached to the Next button
# to display the next question.
#
# Control flow works like this:
#
# User interface implementation modules for Bastille have one
# externally-callable entry point: the do_Bastille function.  The
# purpose of do_Bastille is to initialize the interface, populate
# the Questions database, and start asking questions.
#
# In this Tk implementation, the contents of the config file is
# used to populate the answers in the Questions database, if there
# is a config file.
#
# &initializeGUI creates the main window and all the widgets.
# It then fills them in and returns.  After the Questions database
# is populated, &Ask is called to show the title page.
# The do_Bastille routine then calls Tk's MainLoop routine, which
# never returns.  Thus turning over control of the interface to the
# callback/event handling functions.
#
# Callback functions are attached to the Listbox and to the Back,
# Next, Default Answer and Detail buttons.  The Listbox shows all the
# modules in the database and allows the user to jump to the beginning
# of any module at any time.  (The callback basically looks up the
# index of the first question in the selected module and calls
# &Ask on it.)
#
# This version uses the underlying Bastille modules and questions
# database with no changes.
#

use Tk;
use Tk::LabFrame;
use Tk::DialogBox;
use Tk::HList;
use IO::Handle;
use Bastille::API;
use File::Basename;
use English;
use POSIX qw(:signal_h :errno_h :sys_wait_h); # For child exit status

#use Thread;
#use Thread::Queue;

# main window widget which all other widgets are tied
my $mw;

# reference to the Hlist widget where module names are shown
my $list;
# list modules by index number for use with the HList widget
my @module_index;
# list of indexes by module for use with the HList widget
my %reverse_module_index;
# reference to the check-mark/no check-mark bitmaps for use with the Hlist widget
my ($completeBitmap,$incompleteBitmap);

# reference to the question label GUI object
my $qe;

# a scrolled text widget where the long and short explanations are viewed
my $tw;

# widgets used to input into the answer_text variable,
#  ae - text-box widget used for user specified input for non-boolean questions
my $ae;
#  ab1,ab2 - Yes, No radio button widgets for boolean questions
my ($ab1,$ab2);
#  spacer - used to push the radio buttons apart.
my $spacer;
# where storage of the current question's answer is stored
my $answer_text;

#Frame Widgets
my ($aframe, $qframe, $lframe, $eframe, $menubar, $file_button, $mode_button, $help_button);

# button widget for the back button calling the ask routine with the questions proper parent
my $backButton;

# initial detail level
my $detail_toggle="high";

# button widget which accepts the current answer text and Asks the current
# questions child
my $okButton;

#Other File-Scoped Variables
my $End_Screen_Index = 0;
my $WrapperChild;


sub do_Bastille {

    &B_log("DEBUG","Entering do_Bastille");
    # Builds the GUI, defining all widgets
    &B_log('DEBUG','Initializing Tk GUI');
    &initializeGUI("Title_Screen");
    # displays the question passed in as the question index, Title_Screen is the first question always.
    &B_log('DEBUG','Displaying First Question');
    &Ask("Title_Screen");
    # Tk Subroutine which never returns and allows callback events to drive program execution
    &B_log('DEBUG','Entering Main Loop');
    &MainLoop;
}


sub initializeGUI($$) {

    my $index = $_[0];

    my $frameopts  = ['-side' => 'top', '-padx' => 5, '-pady' => 5, '-ipadx' => 5, '-ipady' => 5, '-fill' => 'x'];
    my $eframeopts  = ['-side' => 'top', '-padx' => 5, '-pady' => 5, '-ipadx' => 5, '-ipady' => 5, '-fill' => 'both',
		       '-expand' => 1];
    my $lframeopts  = ['-side' => 'left', '-padx' => 5, '-pady' => 5, '-ipadx' => 5, '-ipady' => 5, '-fill' => 'y'];
    my $hlistopts  = ['-side' => 'left', '-padx' => 0, '-pady' => 0, '-ipadx' => 0, '-ipady' => 0, '-fill' => 'y'];

    #
    #	The main window
    #
    $mw = MainWindow->new();
    $mw->title("Bastille, Config File: ". &getGlobal('BFILE', 'current_config'));

&B_log("DEBUG","Initialize GUI: Build Menu Bar");
    # A menu bar is really a Frame.
    $menubar = $mw->Frame(-relief=>"raised",
				-borderwidth=>2);



    # Menu that allows loading of an arbitrary config file
    $file_button = $menubar->Menubutton(-text => "File",
    				       -underline => 0);
    my $file_menu = $file_button->Menu();

    $file_button->configure(-menu=>$file_menu);
    $file_menu-> command(-command => \&loadNewConfig,
        -label => "Load Config File...",
        -underline => 0);
    $file_menu-> command(-command => \&saveConfigDialog,
        -label => "Save Config...",
        -underline => 0);
    $file_menu->separator;
    $file_menu-> command(-command => [ sub { exit 0; } ],
        -label => "Exit Without Saving",
        -underline => 1);
    # Menu that allows switching between modes

    $mode_button = $menubar->Menubutton(-text => "Explanation-Detail",
    				       -underline => 0);
    my $mode_menu = $mode_button->Menu();

    $mode_button->configure(-menu=>$mode_menu);

    my $verbose_radio = $mode_menu-> radiobutton(
        -label      => "Verbose Explanations",
        -variable   => \$detail_toggle,
        -command    => \&expn_button,
        -value      => "high");
    $mode_menu-> radiobutton(
        -label      => "Terse Explanations",
        -variable   => \$detail_toggle,
        -command    => \&expn_button,
        -value      => "low");
    # Menu that allows switching between modes


    $help_button = $menubar->Menubutton(-text => "Help",
    				       -underline => 0);
    my $help_menu = $help_button->Menu();

    $help_button->configure(-menu=>$help_menu);

    $help_menu-> command(-command => "exit(0)",
        -label => "About...",
        -underline => 0,
        -command   => \&show_credits);

    # Pack most Menubuttons from the left.
    $file_button->pack(-side=>"left");
    # Mode menu should appear on the left.
    $mode_button->pack(-side=>"left");
    # Help menu should appear on the right.
#    $verbose_radio->select; #This is the default setting
    $help_button->pack(-side=>"right");
    $menubar->pack(-side=>"top", -fill=>"x");

    &B_log("DEBUG","InitializeGUI: Build Frames");
    #	Frames to hold the modules listbox, question, explanation,
    #	answer, and buttons.
    #
    $lframe = $mw->LabFrame(
			    '-label' => "Modules",
			    '-labelside' => "acrosstop")->pack(@$lframeopts);
    $qframe = $mw->LabFrame(
			    '-label' => "Question",
			    '-labelside' => "acrosstop")->pack(@$frameopts);
    $eframe = $mw->LabFrame(
			    '-label' => "Explanation",
			    '-labelside' => "acrosstop")->pack(@$eframeopts);
    $aframe = $mw->LabFrame(
			    '-label' => "Answer",
			    '-labelside' => "acrosstop")->pack(@$frameopts);
    my $bframe = $mw->Frame()->pack(
				 @$frameopts);
    # defining module listbox widget attributes

    $list = $lframe->Scrolled( 'HList',
			       '-drawbranch'    => 0,
			       '-scrollbars' => 'e',
			       '-width'         => 25,
			       '-indent'        => 5,
			       '-selectmode'    => 'single')->pack(@$hlistopts);
    $list->bind("<ButtonRelease-1>", \&hlist_callback);
#    $list->bind("<ButtonPress-1>", \&hlist_callback); uneeded

    $list->pack();
    &B_log("DEBUG","InitializeGUI::Add Pictures");
    $completeBitmap = $lframe->Bitmap('-file' => &getGlobal('BFILE',"complete.xbm"));
    $incompleteBitmap = $lframe->Bitmap('-file' => &getGlobal('BFILE',"incomplete.xbm"));
    $disabledBitmap = $lframe->Pixmap('-file' => &getGlobal('BFILE',"disabled.xpm"));

    #	The question
    #Switched to "Text" widget as "Entry" is now hard to read when disabled.
    $qe  = $qframe->Text('-height' => 1, '-width' => 80)->pack('-fill' => 'x');
    $qe->menu(undef);  #Disable pop-up menu

    #	A scrolled Text widget for the explanation
    #
    $tw = $eframe->Scrolled('Text',
			    '-wrap' => 'word',
			    '-scrollbars' => 'e')->pack('-fill' => 'both','-expand' => 1);
    $tw->menu(undef); #Disable pop-up menu

#	The answer.  Note that there are three widgets defined here,
#	but their pack() methods have not been called.  This allows
#	us to show the text entry widget, the two yes/no radio
#	buttons, or neither, depending on where we are in the Questions
#	database.  (A widget can only appear when it has been packed,
#	and it can be made to disappear by calling its pack method with
#	"forget" as an argument.)
#

    $answer_text = "";
    $ae = $aframe->Entry('-width' => 80,
			 '-textvariable' => \$answer_text);
    $ab1 = $aframe->Radiobutton('-text' => "Yes",
				'-value' => "Y",
				'-variable' => \$answer_text);
    $ab2 = $aframe->Radiobutton('-text' => "No",
				'-value' => "N",
				'-variable' => \$answer_text);
    $spacer = $aframe->Label('-width' => 5);

#	The OK and Back buttons, plus the toggle value for the detail menu
#
    $backButton = $bframe->Button(
	    '-text' => "<- Back",
	    '-command' => \&back_button)->pack(
	    '-expand' => 1,
	    '-side' => 'left');
    $detail_toggle = "high";

    $okButton = $bframe->Button(
	    '-text' => "OK ->",
	    '-command' => \&OK_button)->pack(
	    '-expand' => 1,
	    '-side' => 'right');

#	Build the list of modules.  The @module_index array
#	translates a module number into the first index for
#	that module in the %Question hash.  This allows us to
#	look up the first question of a module based on a mouse
#	click in the modules listbox.  The %reverse_module_index
#	hash converts a module name into a module number, so we
#	can highlight the module we're currently in.
#
    my $mod = "";
    my $ndx = 0;
    my $nq = $index;
    &B_log("DEBUG","InitializeGUI::Enter Module Loop");
    while ($nq ne "RUN_SCRIPT") {

	if ($mod ne $Question{$nq}{'module'}) {
	    unless ($nq eq "End_Screen") {
		$mod = $Question{$nq}{'module'};
		my $shortMod = $Question{$nq}{'shortModule'};
		&B_log("DEBUG","Add Module: $nq , spc_run child: " .
		       $Question{'spc_run'}{'yes_child'});
		my ($incompleteModule, $incompleteKey) = &checkQtree($nq);

		if($incompleteModule eq $shortMod) {
		    $list->add($ndx, '-itemtype' => 'imagetext',
			       '-image' => $incompleteBitmap,
			       '-text' => $shortMod);
		}
		else {
		    $list->add($ndx, '-itemtype' => 'imagetext',
			       '-image' => $completeBitmap,
			       '-text' => $shortMod);
		}
		$module_index[$ndx]{'index'} = $nq;
		$reverse_module_index{$shortMod} = $ndx;
		$module_index[$ndx]{'done'} = 0;
		$ndx++;
		$End_Screen_Index = $ndx;
	    }
	}
	$nq = $Question{$nq}{'yes_child'};
    }
    &B_log("DEBUG","InitializeGUI::Leave Module Loop");

    # determining if any questions are yet unanswered
    &B_log("DEBUG","Checking Q-Tree, First Q: " . &firstQuestion);
    my ($incompleteModule, $incompleteKey) = &checkQtree(&firstQuestion);
    # indicate that all questions have been answered with a check-mark
    # on the end screen module header.
    if($incompleteModule ne "") {
	$list->add($ndx, '-itemtype' => 'imagetext',
		   '-image' => $incompleteBitmap,
		   '-text' => "End Screen");
    } else {
	$list->add($ndx, '-itemtype' => 'imagetext',
		   '-image' => $completeBitmap,
		   '-text' => "End Screen");
    }

    $module_index[$ndx]{'index'} = "End_Screen";
    $reverse_module_index{'End'} = $ndx;
    $module_index[$ndx]{'done'} = 0;

    $mw->focus;
    &change_cursor('top_left_arrow');
}


sub Ask($) {
# sub Ask (index to Question{} record)

##############################################################################
#
# &Ask($question_index);
#
# Given an index from the question hash all of the relevant information about
# that question will be displayed.  This includes module name, question,
# explanation, and radio or text input as appropriate.
#
# REQUIRES: %QUESTION
#           &checkQtree
#
##############################################################################

    $in_epilogue = 0;

    # defined as the current index of the QUESTION hash,
    # this value is always initially "Title_Screen" as called by do_Bastille
    $index=$_[0];
#
#	Skip null records.
#
#    if (($Question{$index}{"short_exp"} eq "") &&
#	($Question{$index}{"long_exp"} eq "") &&
#	($Question{$index}{"question"} eq "")) {
  #	    print "Skipping null record: $index\n";
  #	    print Dumper($Question{$index}) . "\n";
#	    $index = $Question{$index}{"yes_child"};
#    }


    #   Load question into local variables
    my $short_exp      =$Question{$index}{"short_exp"};
    my $long_exp       =$Question{$index}{"long_exp"};
    my $question       =$Question{$index}{"question"};
    my $toggle_confirm = $Question{$index}{"toggle_confirm"};
    my $toggle_yn      =$Question{$index}{"toggle_yn"};
    my $yes_epilogue   =$Question{$index}{"yes_epilogue"};
    my $no_epilogue    =$Question{$index}{"no_epilogue"};
    my $yes_child      =$Question{$index}{"yes_child"};
    my $no_child       =$Question{$index}{"no_child"};
    my $proper_parent  =$Question{$index}{"proper_parent"};
    my $answer     =$Question{$index}{"answer"};
    my $module     =$Question{$index}{"module"};

    # Updating HList check box for each module, as it may have changed since this
    # routine was last called.
    for(my $i=0; $i < $#module_index; $i++){
	my $currentKey = $module_index[$i]{'index'};
	my $currentShortMod = $Question{$currentKey}{'shortModule'};
	# checkQtree returns the name of the next incomplete module.
	my ($incompleteModule, $incompleteKey) = &checkQtree($currentKey);
	# if that module is the same as the module of the current index
	if($incompleteModule eq $currentShortMod) {
	    # then the module is incomplete
	    $list->entryconfigure($i, '-image' => $incompleteBitmap);
	}
	else {
	    # otherwise it is marked complete with a check-mark bitmap
	    $list->entryconfigure($i, '-image' => $completeBitmap);

	}
    }

    # Button control setup for this question, some buttons don't make sense
    # for every question, e.g. you can't go back from the first question.
    # If this is the Title Screen, the question that has no real proper parent
    if($Question{$index}{'proper_parent'} eq $index){
	# gray out the back button
	$backButton->configure('-state' => 'disabled');
    }
    else {
	$backButton->configure('-state' => 'normal');
    }

    # reseting HList-Box selection as the module may have changed
    my $modulename = $Question{$index}{'shortModule'};
    $list->selectionClear('0', $reverse_module_index{"End"});
    $list->anchorClear;
    unless ($modulename eq "") {
    	$list->selectionSet($reverse_module_index{$modulename});
    }


    # setting detail button text
    # Perhaps set detail radio button default here


    # Explanation to display in routines -- we use short explanation if
    # long is empty, since long explanation is optional

    my $explanation;
    if (($detail_toggle eq "high") and ($long_exp)) {
    	$explanation="$long_exp\n";
    } elsif ($short_exp) {
    	$explanation="$short_exp\n";
    } else {
        $explanation="";
    }

    # Now, clear the screen fields and insert the new values

    # show the new explanation
    $tw->configure('-state' => 'normal');
    $tw->delete('0.0', 'end');
    $tw->insert('0.0', $explanation);
    $tw->configure('-state' => 'disabled');

    # show the new question text
    #	Trim the default answer from the end of the question, since
    #	it might differ from the one we found in the config file.
    $question =~ s/\[.*\]$//;
    $qe->configure('-state' => 'normal');
    $qe->delete('0.0', 'end');
    $qe->insert('0.0', $question);
    $qe->configure('-state' => 'disabled');


    $answer_text = $answer;
    if ($question eq "") {
#
#	If there is no question, don't show any answer widgets.
#
	$ae->pack('forget');
	$ab1->pack('forget');
	$ab2->pack('forget');
    } else {
#
#	Else, show either the Entry or the Radio Buttons.
#
	if ($toggle_yn) {
	    $ae->pack('forget');
	    $spacer ->pack('-side' => 'right');
	    $ab1->pack('-side' => 'right');
	    $ab2->pack('-side' => 'right');
	} else {
	    $ab1->pack('forget');
	    $ab2->pack('forget');
	    $spacer ->pack('forget');
	    $ae->pack();
	}
    }
}
sub saveAnswerInHash {
    # sucking answer_text, global variable, contents into a local answer variable
    my $answer  = $answer_text;
    # unless the current index is in an epilogue    	# for yes/no questions
	if ($Question{$index}{'toggle_yn'}) {
	    # if the answer if yes
	    if ($answer =~ /[Yy]/)  {
		# set the QUESTION hash answer to Yes, to be used for question output
		# and if we come back to this question this "answer" will appear in answer_text
		$Question{$index}{'answer'} = "Y";
		# set the GLOBAL_CONFIG hash answer to Yes, to be used in the case of a partial save
		$GLOBAL_CONFIG{$Question{$index}{'shortModule'}}{$index} = "Y";
		# set the next index to be the yes child
		$next_index = $Question{$index}{'yes_child'};
		# set the current index to be the proper parent of the next index
		# this ensures a smooth traversal back, using the back button, through
		# the questions.
		$Question{$next_index}{'proper_parent'} = $index;
		# if there is an epilogue for the yes answer then show it.
		if ($Question{$index}{'yes_epilogue'} and not $in_epilogue) {
		    $in_epilogue = 1;
		    &show_epilogue ("yes_epilogue");
		    return;
		}
	    }
	    # if the answer is No
	    elsif ($answer =~ /[Nn]/)  {
		# set the QUESTION hash answer to NO, to be used for question output
		# and if we come back to this question this "answer" will appear in answer_text
		$Question{$index}{'answer'} = "N";
		# set the GLOBAL_CONFIG hash answer to Yes, to be used in the case of a partial save
		$GLOBAL_CONFIG{$Question{$index}{'shortModule'}}{$index} = "N";
		# set the next index to be the no child
		$next_index = $Question{$index}{'no_child'};

		# If the End Screen is not the current index
		if($index ne "End_Screen") {
		    # set the current index to be the proper parent of the next index
		    # this ensures a smooth traversal back, using the back button, through
		    # the questions.
		    $Question{$next_index}{'proper_parent'} = $index;
		}

		# if there is an epilogue for the yes answer then show it.
		if ($Question{$index}{'no_epilogue'} and not $in_epilogue) {
		    $in_epilogue = 1;
		    &show_epilogue ("no_epilogue");
		    return;
		}
	    }
	    else {
		$mw->bell();
		return;
	    }
	}
	# we have a user input answer
	else {
	    # ensure that the user input answer follows the regular expression for
	    # answers to this question as defined in the Question Hash
	    if(&validateAnswer($index,$answer)) {
		# if the answer matched the regular expression then save off the answer
		$Question{$index}{'answer'} = $answer;
		$GLOBAL_CONFIG{$Question{$index}{'shortModule'}}{$index} = $answer;
		# set the next index to be the yes child, it is required that all user input
		# questions have a yes child, and if you've answered the question then
		# the yes child is the route to go.
		$next_index = $Question{$index}{'yes_child'};
		# set the current index to be the proper parent of the next index
		# this ensures a smooth traversal back, using the back button, through
		# the questions.
		$Question{$next_index}{'proper_parent'} = $index;
		# if there is an epilogue for the answer then show it.
		if ($Question{$index}{'yes_epilogue'} and not $in_epilogue) {
		    $in_epilogue = 1;
		    &show_epilogue ("yes_epilogue");
		    return;
		}
	    }
	    else {
		# if the answer did not match the regular expression defined for it,
		# then we will save the answer, so it can be modified as it stands
		$Question{$index}{'answer'} = $answer;
		# but we will delete it from the GLOBAL_CONFIG, this ensures that a
		# module cannot be marked complete until all answers there in match
		# the regular expressions defined for them.
		delete $GLOBAL_CONFIG{$Question{$index}{'shortModule'}}{$index};
		# show the validation error, showing samples of answer syntax
		&show_validateError;
		# ask the question again
		$next_index = $index;
	    }
	}
}

# This is the callback for the OK button
#
sub OK_button {

    &B_log("DEBUG","Entering Ok Callback with next index: $next_index, index:$index");
    # unless the current index is in an epilogue
    unless (($in_epilogue) or
            ($index eq "End_Screen")) {
	&saveAnswerInHash;
    }


    # If the user is attempting to exit the program then check to see how to
    # proceed
    if ($index eq "End_Screen") {

	my ($incompleteModule, $incompleteKey) = &checkQtree(&firstQuestion);
	# if all questions have been successfully answered
	if($incompleteModule eq "") {
	    &apply_config;
	    return;
	} else {
	    # otherwise they will be asked to partial-save or go back and finish.
	    $next_index = &notFinished($incompleteModule,$incompleteKey);
	}
    } elsif($next_index eq "End_Screen") {
	$okButton->configure('-text' => 'Save/Apply ->');
    }
    &Ask($next_index);
}

sub loadNewConfig {
    my $types = [['Config Files','*config'],['All Files','*']];
    my $configdir = dirname(&getGlobal ("BFILE", "current_config"));
    my $default_config = basename(&getGlobal ("BFILE", "current_config"));

    my $load_file;
    if ($load_file = $mw->getOpenFile(-filetypes=>$types,
				    -initialdir=>$configdir,
				    -initialfile=>$default_config,
				    -title=>"Load...")) {
	&setGlobal('BFILE','current_config',$load_file);
	$mw->title("Bastille, Config File: ". &getGlobal('BFILE', 'current_config'));
	if (&ReadConfig($load_file)){
            &Ask("Title_Screen");
	    return 1;
	} else {
	    my $FileWin = $mw->Toplevel;
	    my @topts = ('-padx' => 5, '-pady' => 5, '-side' => 'top');
	    my @bopts = ('-padx' => 5, '-pady' => 5, '-side' => 'left', '-expand' => 1);

	    $FileWin->title("Warning");
	    $FileWin->Label(
	   '-text' => "There were parsing problems with the file (see title-bar) you selected.\n" .
		   "Please read the standard error warning messages to ensure you didn't lose\n" .
		   "important data, and examine the file to ensure it is not corrupt.\n")->pack(@topts);
	    $FileWin->Button(
	   '-text' => "OK",
	   '-command' => [sub {$mw->deiconify;
			    $FileWin->destroy;
			    $okButton->configure('-text' => 'OK ->');
			    }])->pack(@bopts);
	    $FileWin->grab;
	    return 0;
	}

	# Reset hlist to show new status
	$list-> selectionClear;
	$list -> selectionSet(0,0);
	&hlist_callback;
    }
}

sub saveConfigDialog {
    my $types = [['Config Files', '*config']];
    my $configdir = dirname(&getGlobal ("BFILE", "current_config"));
    my $config = basename(&getGlobal ("BFILE", "current_config"));

    my $save_file;
    if ($save_file = $mw->getSaveFile(-filetypes=>$types,
				    -initialdir=>$configdir,
				    -initialfile=>$config,
				    -title=>"Save As...")){

	&saveAnswerInHash; #Save last entry, but don't apply config if on last screen

	&setGlobal('BFILE','current_config',$save_file);
	&partialSave;
	$mw->title("Bastille, Config File: ". &getGlobal('BFILE', 'current_config'));
    }
}

sub show_epilogue {
    my $field = $_[0];

    $ae->pack('forget');
    $ab1->pack('forget');
    $ab2->pack('forget');

    $qe->configure('-state' => 'normal');
    $tw->configure('-state' => 'normal');
    $qe->delete('0.0', 'end');
    $answer_text = "";
    $tw->delete('0.0', 'end');
    $tw->insert('0.0', $Question{$index}{$field});
    $qe->configure('-state' => 'disabled');
    $tw->configure('-state' => 'disabled');
}

# Generate the command args we should use for subsequent run
sub getCommandArgs {
    my $commandLine = $CLI; # Captures original command-line
                                   # from InteractiveBastille
    &B_log("DEBUG","Command arguments in getCommandArgs:" . $commandLine);
    $commandLine =~ s/-f\s+\S+//; # Eliminate config loaded at cli so we can
                                  # load the latest loaded/saved config
    #Eliminate other options that we shouldn't pass on.
    #Note that replacing strings that are contained in other strings
    #has to be last in order.
    $commandLine =~ s/(-x)|(-c)|(--assessnobrowser)|(--assess)//g;
    $commandLine =~ s/(-h)|(-l)|(-b)|(--report)|(-r)|(-a)//g;
    #add back in the current config file.
    $commandLine .= " -f " . &getGlobal('BFILE',"current_config");
    &B_log("DEBUG","After Processing:" . $commandLine);
    return $commandLine;

}

sub clean_mw { #Reconfigures Main Window for output and credit display.

    my $last_element=();
    my $element=0;

    $qe->configure('-state' => 'normal');
    $qe->delete('0.0', 'end');
    $qe->configure('-state' => 'disabled');
    $ab1->pack('forget');
    $ab2->pack('forget');
    $file_button->configure('-state' => 'disabled');
    $mode_button->configure('-state' => 'disabled');
    $help_button->configure('-state' => 'disabled');
    $eframe->configure('-label' => 'Program Output');
    $backButton->configure('-state' => 'disabled');
    $okButton->configure('-state' => 'disabled',
			 '-text' => 'Exit ->',
			 '-command' => [sub {exit(0)}]);
    $tw->configure('-state' => 'normal');
    $tw->delete('0.0', 'end');
    $tw->insert('0.0',"Bastille is applying your configuration, this may take a few minutes:\n\n\n");
    $tw->configure('-state' => 'disabled');
    &change_cursor('watch');
   $list->itemConfigure($element, 0, '-image' => $disabledBitmap);
    while ($element=$list->info('next',$element)) {
#	$list->itemConfigure($element,0,'-state'=>'disabled');
    $list->itemConfigure($element, 0, '-image' => $disabledBitmap);
#				      '-relief' => 'flat');
#			 '-activebackground' => 'grey85',
#			 '-highlightbackground'=>'grey85',
#			 '-highlightforeground' => 'grey85',
#			 '-highlightthickness'=> 0,
#			 '-selectborderwidth' => 0);
    }
    $list->configure('-foreground' => 'grey64',
#		     '-showactive' => 0,
#		     '-activebackground' => 'grey85',
		     '-selectborderwidth' => 0,
		     '-selectbackground' => 'grey85',
		     '-selectforeground' => 'grey64',
#		     '-highlightthickness' => 0,
		     '-highlightbackground'=>'grey85',
#		     '-highlightforeground'=>'grey64',
		     '-highlightcolor'=>'grey85');
#		     '-relief'=>'flat');
#		     '-state' => 'disabled');
    $list->bind("<ButtonRelease-1>", undef);

}

###################################################################
#  &notFinished($module,$key);                                    #
#    This subroutine displays a window that tells the user that   #
#    they have not finished answering all questions and will have #
#    to before the back end will run.  Three options are given:   #
#    Finish answering question, Exit without saving, and save and #
#    exit.                                                        #
#                                                                 #
#   REQUIRES:  &Ask($key);                                        #
#                                                                 #
###################################################################
sub notFinished($$) {
    my ($module,$key) = @_;

    &B_log("DEBUG","notFinished Dialog");
    &makeDialog($key,"You have not answered all of the questions that pertain to your system.\n" .
		   "In order for Bastille to apply changes you must answer all of the\n" .
		   "questions that are relevant to your system.\n");
}

########################
# makeDialog
# creates a popup window for whatever warning
# message we need.  Abstracted from notFinished
#Takes the current question key (or new one if that should
# need to be changed, and the dialog text as arguments
#
#######################

sub makeDialog ($$){
    my ($key, $dialogText) = @_;
    my @tw_opts = ('-padx' => 5, '-pady' => 5, '-side' => 'top');
    my @but_opts = ('-padx' => 5, '-pady' => 5, '-side' => 'left', '-expand' => 1);

    &B_log("DEBUG","Creating Text window.");
    $unfinishedwin = $mw->Toplevel;
    $unfinishedwin->title("Warning");
    $unfinishedwin->Label(
        '-text' => "$dialogText")->pack(@tw_opts);
    $unfinishedwin->Button(
        '-text' => "OK",
        '-command' => [sub {$mw->deiconify;
			    &Ask($key);
			    $unfinishedwin->destroy;
			    $okButton->configure('-text' => 'OK ->');
			    }])->pack(@but_opts);
    $unfinishedwin->grab;
}

sub apply_config {
    use Config;
    unless ($Config{d_sigaction}) {  #Check to see if signals are well-behaved
	&B_log("WARNING","This OS does not have well-behaved signals, this may" .
	  "result in interface display irregularities, or freezing.");
    }
    &B_log("DEBUG","Bastille_Tk Setting Up Configuration Run");

    my $config = &getGlobal('BFILE', "current_config");
    &outputConfig;
    &B_log("DEBUG","Bastille_Tk Config Output Completed");
    
    #Check for --os flag
    my $editedCLI = &getCommandArgs;
    if (" $editedCLI" =~ /\s--os\s/) {
        &makeDialog("End_Screen","Current Config File Saved, but Not Applied.  \n ".
                  "Reason: --os was used, so the config file may not apply to system.  \n".
                  "Please use bastille -b -f <file> to apply the config to the system, or rerun \n".
                  "Bastille in interactive mode without the --os flag to ensure proper \n".
                  "filtering.  In the future, you can also use File::Save to save your \n".
                  "config file without seeing this dialog box.\n");
        return 0; #Go back to the GUI
    }

    if (open(BACKEND_PIPE, "-|")) {
	#Parent Code
        &B_log("DEBUG","Parent back from fork.");
#        if (not(defined(open(BACKEND_PIPE, "< $filePipe")))) {
#            &B_log("ERROR","Unable to upen communication file: $filePipe" .
#                   ".  Lockdown status my not display in parent window.");
#        }
#        &B_log("DEBUG","Back from post-fork pipe open");
	&clean_mw; #Cleans up main window
	$mw->fileevent(\*BACKEND_PIPE, 'readable', [ sub {
		my ($read_status, $buffer, $childpid);
		$read_status= sysread(BACKEND_PIPE, $buffer, 4096);
		if (defined($read_status) and ($read_status != 0)) {
                    &B_log("DEBUG","Pipe Read: $buffer");
		    $tw->configure('-state' => 'normal');
		    $tw->insert('end', $buffer);
		    $tw->configure('-state' => 'disabled');
		} elsif ($read_status==0){
                    &B_log("DEBUG","Null Read");
		    $childpid = waitpid(-1,WNOHANG);
                    # if child is terminated via a normal exit or signal, clean up.
		    if ((WIFEXITED($CHILD_ERROR)) or (WIFSIGNALED($CHILD_ERROR))){
                        B_log("DEBUG","Child Died");
			$tw->insert('end', "\n\nThanks from the Bastille Team:\n" .
				    &readCredits);
			$okButton->configure('-state' => 'normal');
#			$backButton->configure('-state' => 'normal');
			$tw->configure('-state' => 'disabled');
			&change_cursor('top_left_arrow');
			close(BACKEND_PIPE);
                    }
                }
        }]);
    } else {
	#Backend Child Code
        my $BackEndParams = &getCommandArgs;
        &B_log("DEBUG","Child firing up back-end with config: $config.");
        &B_log("DEBUG","Backend arguments: " . $BackEndParams );
        my $backend = &getGlobal('BFILE',"BastilleBackEnd");
#        my $stty = &getGlobal('BIN',"stty");
#Add sigttou trap to keep bastille from hanging.
	exec("trap \'\' SIGTTOU ; $backend ". $BackEndParams ." 2>&1");
    }
} #apply config

sub readCredits() {
    # read the credits file into a string variable
    open CREDITS, &getGlobal('BFILE',"credits");
    @creditsarray = <CREDITS>;
    close CREDITS;
    return " " . join(" ", @creditsarray);
}
sub change_cursor($) {

    my $cursor_type = $_[0];

    $mw ->configure('-cursor' => $cursor_type);
    $tw ->configure('-cursor' => $cursor_type);
    $qe ->configure('-cursor' => $cursor_type);
    $ae ->configure('-cursor' => $cursor_type);
    $list ->configure('-cursor' => $cursor_type);
}

sub show_credits {
    # create a new window for the credits
    $credwin = MainWindow->new();
    $credwin->title("Credits");

    # Create a frame on the new window for the credits text
    my $textFrameOpts  = ['-side' => 'top', '-padx' => 5, '-pady' => 5, '-ipadx' => 5, '-ipady' => 5, '-fill' => 'x'];
    my $textFrame = $credwin->LabFrame('-label' => "Contributors",
				       '-labelside' => "acrosstop")->pack(@$textFrameOpts);
    # create a scrolled text widget for the credits text on the text frame
    $credtxt = $textFrame->Scrolled('Text',
				    '-wrap' => 'word',
				    '-width'=> '80',
				    '-scrollbars' => 'e')->pack('-fill' => 'both','-expand' => 1);
    # add the credit text to the new text widget
    $credtxt->configure('-state' => 'normal');
    $credtxt->delete('0.0', 'end');
    $credtxt->insert('0.0', &readCredits);
    $credtxt->configure('-state' => 'disabled');

    # create a new frame on the credits window for the close button
    my $buttonFrameOpts  = ['-side' => 'top', '-padx' => 5, '-pady' => 5, '-ipadx' => 5, '-ipady' => 5, '-fill' => 'x'];
    my $buttonFrame = $credwin->LabFrame()->pack(@$buttonFrameOpts);
    # create the close button widget
    $buttonFrame->Button(
	    '-text' => "Close",
	    '-command' => [ sub { $credwin->destroy; }])->pack(
	    '-expand' => 1,
	    '-side' => 'left');
    # put the newly created window into screen focus.
    $credwin->focus;
}


# This is the callback for the Back button
#
sub back_button {
    my $answer  = $answer_text;
    unless ($in_epilogue) {
	if ($Question{$index}{'answer'} ne $answer){
	    delete $GLOBAL_CONFIG{$Question{$index}{'shortModule'}}{$index};

	    if ($Question{$index}{'toggle_yn'}) {
		if ($answer =~ /[Yy]/)  {
		    $Question{$index}{'answer'} = "Y";
		}
	    elsif ($answer =~ /[Nn]/)  {
		$Question{$index}{'answer'} = "N";
	    }
	    }
	    else {
		$Question{$index}{'answer'} = $answer;
	    }
	}
    }
    if ($index eq "End_Screen") {
	$okButton->configure('-text' => 'OK ->');
    }

    if ($in_epilogue) {
        &Ask($index);
    } else {
        &Ask($Question{$index}->{'proper_parent'});
    }

}

#Removed "default" button, since he concept of "default" is odd now that we test.
#sub default_button {
#    my $answer = $Question{$index}{'default_answer'};
#    $Question{$index}{'answer'} = $answer;
#    delete $GLOBAL_CONFIG{$Question{$index}{'shortModule'}}{$index};
#    &Ask($index);
#}

# This is the callback for the Details radio buttons.
#

sub expn_button {
    my $explanation;

    if ($in_epilogue) {
        return;
    }

    if (($detail_toggle eq "high") and ($Question{$index}{'long_exp'})) {
        $explanation = $Question{$index}{'long_exp'};
    } elsif ($Question{$index}{'short_exp'}) {
        $explanation = $Question{$index}{'short_exp'};
    } else  {
        $explanation = "";
    }

    $tw->configure('-state' => 'normal');
    $tw->delete('0.0', 'end');
    $tw->insert('0.0', $explanation);
    $tw->configure('-state' => 'disabled');
}

# This is the listbox callback
#
sub hlist_callback {
    my ($sel) = $list->info("selection");
    if($sel ne ""){
	$list->selectionClear('0', $reverse_module_index{"End"});
	$list->selectionSet($sel);
	$list->anchorClear;
	&Ask ($module_index[$sel]{'index'});
	if($sel == $End_Screen_Index) {
	    $okButton->configure('-text' => 'Save/Apply ->');
	} else {
	    $okButton->configure('-text' => 'OK ->');
	}
    }
}


sub show_validateError {

    my $vRegExp = &getRegExp($index);
    my @tw_opts = ('-padx' => 5, '-pady' => 5, '-side' => 'top');
    my $exampleString = "";
    if(exists $Question{$index}{"expl_ans"} &&  $Question{$index}{"expl_ans"} ne "") {
	my $example = $Question{$index}{"expl_ans"};
	$exampleString = "An example of an acceptable answer is:\n\t$example\n\n";
    }
    elsif(exists $Question{$index}{"default_answer"} && $Question{$index}{"default_answer"} ne "") {
	$example = $Question{$index}{"default_answer"};
	$exampleString = "An example of an acceptable answer is:\n\t$example\n\n";
    }

    my $vErrorWin = $mw->DialogBox;
    $vErrorWin->title("Input Error:");
    $vErrorWin->Label( '-text' =>
			  "\nThis question requires an answer with a specific\n" .
			  "format.\n\n" . $exampleString  .
		          "See the question explanation for more details.",
		       '-justify' => 'left' )->pack(@tw_opts);
    $vErrorWin->Show();
}


1;
