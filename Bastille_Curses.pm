#!/usr/bin/perl

##########################################################################
#
# This is the code implementing the Bastille-1.1.1 curses interface.
#
# In Bastille-1.1.1, this code was in the InteractiveBastille.pl script
# and carried the following copyright:
#
# Copyright (C) 2000 Jay Beale
# Licensed under the GNU General Public License, version 2
#
# The do_Bastille function is a wrapper around the main program logic
# from the InteractiveBastille.pl script.  When it is called, the
# Curses interface runs.  Other than turning this code into a perl
# module and adding the do_Bastille wrapper, there have been no
# changes.

##########################################
## Bastille Text User Interface         ##
##########################################

#
# TO DO:
#
#  1) Use the newly-release Curses::Widgets 1.1 to get better text windows
#  2) Finish documenting program
#  3) Rewrite &Ask subroutine: either use Curses::Forms or just make cleaner

# This use is needed to give the TUI/GUI access to the GLOBAL_ hashes.

use Bastille::API;   

sub do_Bastille {

    use Curses;
    use Curses::Widgets;

    # Number_Modules is the number of modules loaded in by Load_Questions
    $Number_Modules=0;

    #
    # Highlighted button is the button currently chosen in the button bar
    #     We preserve this from question to question...
    #
    $highlighted_button=1;

    # These variables contain the state of and text for the detail button
    $detail_toggle="high";
    $detail_button{"low"}="< Explain More >";
    $detail_button{"high"}="< Explain Less >";

    # Set up the Curses environment
    $window = new Curses;

    # Confirm that we have a full 80 columns...
    if ($COLS < 80) {
        endwin;
        print "\n\n**************************************************************\n";
        print "Please run this in an 80 column environment, preferably from a\n";
        print "text console! You can get a text console by hitting\n";
        print "\n            <CTRL>-<ALT>-<F2>\n";
        print "\nand can return to your graphical display, usually, by hitting\n";
        print "\n            <CTRL>-<ALT>-<F7>";
        print "\n\n**************************************************************\n";
        &ErrorLog("ERROR:   Not in 80 columns...\n");
        exit(1);
    }

    start_color;

    # Increment determines spacing between buttons
    $increment=$COLS/4;

    # Get to the real work of asking questions...
    &Draw_Title;
    # Draw instructions
    # $window->addstr(24,25,"TAB to switch between windows");
    # $window->refresh;

    $next_question_index="Title_Screen";
    while ($next_question_index ne "RUN_SCRIPT") {
        $next_question_index=&Ask($next_question_index);
    }

    # Output answers to the script and display
    &checkAndSaveConfig(&getGlobal('BFILE', "config"));

    # Run Bastille

    &Run_Bastille_with_Config;


    # Display Credits

    open CREDITS,"/usr/share/Bastille/Credits";
    while (my $creditline=<CREDITS>) {
        $credits .= $creditline;
    }
    close CREDITS;
    $window->erase;

    txt_field( 'window'       => $window,
    	   'ypos'         => 0,
    	   'xpos'         => 0,
    	   'lines'        => $LINES - 2, 
    	   'cols'         => $COLS - 2,
    	   'content'      => $credits,
    	   'border'       => 'blue',
    	   'draw_only'    => 0,
    	   'title'        => "Bastille Credits     (press TAB to go on)",
    	   'pos'          => 1,
    	   'regex'	  => "\n\t"
    	   );

    endwin;

}

sub Ask {
# sub Ask (index to Question{} record)

##############################################################################
#
# More comments coming here, from Design Doc...
#
# WEIRD CASES:
#
#  1 If a record has no short_exp explanation, none is shown.  This is bad?
#  2 If a record has no question, no question is asked, but the explanation
#    is still displayed.  If this is the case, the default_answer is still
#    entered into the configuration, if it exists.
#  3 If a question has no answer, it doesn't create any blank lines or such
#    in the output file, as it will be skipped in &Output_Config_Files.  For
#    this reason, &Prompt_Input, which is only called when the record contains
#    a user-answerable question, pads a space to the end of any 0-length input.
#    Not to worry: Output_Config_Files replaces said space with 0-length input
#    NOTE: we couldn't just only print the answer field when a real question
#          existed -- this would improperly handle case 2.
#    
###############################################################################

    #
    # Load question into local variables
    #
    my $index=$_[0];
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
    my $answer         =$Question{$index}{"answer"};
    my $module         =$Question{$index}{"module"};

    
    #
    # Set up other local variables
    #

    # Index to next question -- returned by this routine -- loop until we
    # have an index
    my $return_index="";

    # Highlighted button stores the button currently hightlighted -- set this
    # to 1 whenever we enter a question
    # my $highlighted_button=1;


    # Widgets 1.1 feature
    # Current position in the Scrollable explanation box
    #my $current_scroll_position=0;

    while (not $return_index) {

	# Button pressed at end
	my $button_pressed="";
	
	# Input window exited via enter key instead of tab key
	my $exited_with_enter=0;

	#
	# Explanation to display in routines -- we use short explanation if 
	# long is empty, since long explanation is optional
	
	my $explanation;
	if (($detail_toggle eq "high") and ($long_exp)) {
	    if ($question) {
		$explanation="Q: $question\n$long_exp\n\n$question";
	    }
	    else {
		$explanation="$long_exp\n\n$question";
	    }
	}
	elsif ($short_exp) {
	    if ($question) {
		$explanation="Q: $question\n$short_exp\n\n$question";
	    }
	    else {
		$explanation="$short_exp\n\n$question";
	    }
	}
	else {
	    # Special case: when there is no explanation, this is a question
	    # used either to show an epilogue or to (more likely) get some
	    # default answer into the data stream

	    $explanation="";
	}

	#
	# Draw the screen before accepting input
	#
	# This basically does the following, making it easier to continue
	# redrawing the screen on every window switch...
	# &Draw_Explanation($explanation);
	# if ($question) { 
	#     &Draw_Prompt($answer,$toggle_yn);
	# }
	# &Draw_Buttons;

	&Redraw_Screen($module,$explanation,$question,$answer,$toggle_yn);

	#
	# Redraw windows with user input allowed and accept input
	#

	# Change from 1.0.4.pre1 -> 1.0.4.pre2  -- switched window order
	#if ($explanation) {
	#    &Scroll_Explanation($module,$explanation);
	#    &Redraw_Screen($module,$explanation,$question,$answer,$toggle_yn);
	#}
	if ($question) {
	    ($answer,$exited_with_enter)=&Prompt_Input($answer,$toggle_yn);
	    &Redraw_Screen($module,$explanation,$question,$answer,$toggle_yn);
	}
	else {
	    if ($answer) {
		$button_pressed="Next";
	    }
	}
	
	# Skip the buttons if we exited the input with the Enter key
	if ($exited_with_enter) {
	    $button_pressed="Next";
	}
	elsif ($question or $explanation)  {
	    $button_pressed=&Allow_Buttons;
	    &Redraw_Screen($module,$explanation,$question,$answer,$toggle_yn);
	}

	# Was the detail level of the explanations toggled?
	if ($button_pressed eq "Detail") {
	    # Switch the detail level
	    if ($detail_toggle eq "high") {
		$detail_toggle="low";
	    }
	    else {
		$detail_toggle="high";
	    }

	    # Reload the explanation
	    if (($detail_toggle eq "high") and ($long_exp)) {
		$explanation="$long_exp\n\n$question";
	    }
	    elsif ($short_exp) {
		$explanation="$short_exp\n\n$question";
	    }

	}
	
	# Did the user hit the Back Button?
	if ($button_pressed eq "Back") {
	    $return_index=$proper_parent;
	}

	# Did the user hit the next button on an answered question?
	# Ahhh, we allow blank responses to questions -- make this less
	# icky later by using radio buttons/lists for yes/no...
	#
#	if (($button_pressed eq "Next") and ($answer)) {
	if  ($button_pressed eq "Next") {

	    # If not a Y/N question, use the Yes Child and Epilogue
	    unless ($toggle_yn) {		
		$return_index=$yes_child;
		
		if ($yes_epilogue) {
		    $window->erase;
		    &Draw_Title;
		    &Display_Epilogue($yes_epilogue);
		}
	    }
	    # Otherwise, use the epilogue appropriate to the answer
	    else {
		if ($answer=~/^\s*Y/i) {
		    $return_index=$yes_child;

		    $window->erase;
		    &Draw_Title;
		    &Display_Epilogue($yes_epilogue);
		}
		elsif ($answer =~/^\s*N/i) {
		    $window->erase;
		    &Draw_Title;
		    $return_index=$no_child;
		    &Display_Epilogue($no_epilogue);
		}
	    }
	}

	# Now, if the user hit Prev/Next, store the answer so it's there
	# when we come back to it...
	if ($return_index) {
	    if ($answer) {
		$Question{$index}{"answer"}=$answer;
                $GLOBAL_CONFIG{$Question{$index}{'shortModule'}}{$index} = $answer;

	    }
	}
	else {
	    &Scroll_Explanation($module,$explanation);
	    &Redraw_Screen($module,$explanation,$question,$answer,$toggle_yn);
	}

	# Deal with text-screen questions: questions w/ no question and
        # explanation which still have an epilogue

	if ((not $explanation) and (not $question)) {
	    $return_index=$yes_child;
	    &Display_Epilogue($yes_epilogue);
	}

    }
		
    $return_index;
}

sub Redraw_Screen {
# sub Redraw_Screen($module,$explanation,$question,$answer,$toggle_yn)
    
    my ($module,$explanation,$question,$answer,$toggle_yn)=@_;

    # Erase the screen.
    $window->erase;

    &Draw_Title;
    &Draw_Key_Instructions;

    if ($explanation) {
	&Draw_Explanation($module,$explanation);
    }
    if ($question) { 
	&Draw_Prompt($answer,$toggle_yn);
    }
    if ($question or $explanation) {
	&Draw_Buttons;
    }
}

# Window drawing functions...

sub Draw_Title {
# Draw the title bar   

    my $windowname = "Bastille";

    txt_field( 'window' => $window, 
	       'ypos'   => 0, 'xpos'   => 0,
	       'lines'  => 1,
	       'cols'   => $COLS-2, 
	       'content'=> "                                  $windowname",
	       'border' => 'blue', 
	       'draw_only' => 1,
	       );
}

sub Draw_Key_Instructions {

    select_colour($window,"yellow");
    $window->addstr(24,0,"TAB to switch Windows                               Arrow Keys to switch Buttons");
    $window->attrset(0);

    1;
}
    
    

sub Draw_Explanation {
# Draw the explanation

    my ($module,$explanation)=@_;
    my $title;

    if ($module) {
	$title=$module . " of $Number_Modules";
    }

    txt_field( 'window'       => $window,
	       'ypos'         => 3,
	       'xpos'         => 0, # $COLS - 5,
	       'lines'        => $LINES - 11, 
	       'cols'         => $COLS - 2,
	       'content'      => $explanation,
	       'border'       => 'blue',
	       'draw_only'    => 1,
	       'title'        => $title,
	       'pos'          => 0,
# Widgets 1.1 feature
#	       'pos'          => $current_scroll_position,
	       # 'function'     => \&clock
	       );
}

sub Draw_Prompt {
# Draw the Answer area

    my ($current_answer,$toggle_yn)=@_;    
    my %yes_no_list =("0","Yes","1","No");
    my $default_entry=0;

    # Is this a yes/no question or not? If yes, use a button list...
    if ($toggle_yn) {
	if ($current_answer=~/^\s*Y/i) {
	    $default_entry=0;
	}
	elsif ($current_answer=~/^\s*N/i) {
	    $default_entry=1;
	}
	    
	my ($key, $answer)=list_box( 'window'    => $window,
				     'ypos'     => $LINES-6,
				     'xpos'     => 36,
				     'lines'     => 2,
				     'cols'      => 5,
				     'border'    => 'blue',
				     'selected'  => $default_entry,
				     'list'      => \%yes_no_list,
				     'draw_only' => 0
				     );

    }
    # If it's not a yes/no question, create an answer blank...
    else {

	txt_field( 'window'        => $window,
		   'ypos'          => $LINES-6,
		   'xpos'          => 1,
		   'lines'         => 2,
		   'cols'          => $COLS-4,
		   'content'       => "Answer: $current_answer",
		   'border'        => 'blue',
		   'draw_only'     => 1,
		   'pos'           => 8,
		   );
    }
}

sub Draw_Buttons {

# Use of the widget removed for now, since draw_only doesn't work here
#($input,$selected) = buttons(    'window'       => $window,
#                                 'buttons'       => ["Back","Next",
#					$detail_button{$detail_toggle}],
#				 'ypos'          => $LINES-2,
#				 'xpos'          => ($increment)-2,
#				 'spacing'       => $increment/4,
#				 'active_button' => 1,
#				 'draw-only'     => 1,
#				 );
# Emulate!
    select_colour($window,"blue");
    $window->addstr($LINES-2,($increment)-4,"< Back >");
    $window->addstr($LINES-2,($increment*2)-11,"< Next >");
    $window->addstr($LINES-2,($increment*3)-18,$detail_button{$detail_toggle});
    $window->attrset(0);
    $window->refresh;
}

sub Scroll_Explanation {
# Allow user to scroll the explanation

    my ($module,$explanation)=@_;
    my $title;

    if ($module) {
	$title=$module . " of $Number_Modules";
    }

    noecho;
    # Widgets 1.1 feature
    #($key, $rtrnd_note,$current_scroll_position) = 
    ($key,$rtrnd_note) =  txt_field( 'window'       => $window,
				     'ypos'         => 3,
				     'xpos'         => 0, # $COLS - 5,
				     'lines'        => $LINES - 11, 
				     'cols'         => $COLS - 2,
				     'content'      => $explanation,
				     'border'       => 'red',
				     'draw_only'    => 0,
                                     # Widgets 1.1 only -- no edit in window
				     #'edit'         => 0,
				     #'cursor_disable' => 0,
				     'title'        => $title,
				     'pos'          => $current_scroll_position,
				     # 'function'     => \&clock
				     );
}

sub Display_Epilogue {
    ###
#######  See about using text widget, but blanking the buttons and answer for
#######  this...
    ###

    my $text=$_[0];
    
    if ($text) {
	$text = " "x27 . "<Press TAB to go on>\n\n" . $text;

	($key, $rtrnd_note) = txt_field( 'window'       => $window,
					 'ypos'         => 3,
					 'xpos'         => 0,
					 'lines'        => $LINES-5,
					 'cols'         => $COLS-2,
					 'content'      => $text,
					 'border'       => 'red',
					 'pos'          => 1,
					 'regex'        => "\n\t",
					 );
#    	msg_box('message' => $text);
    }
}

sub Prompt_Input {
# sub Prompt_Input($current_answer, $toggle_yn)
#
# $current_answer -- the answer to place in the window for user to edit
# $toggle_yn      -- 1 if this is a y/n question, 0 otherwise

###############################################################################
# WEIRD CASES:
#
#  1 If a record has no short_exp explanation, none is shown.  This is bad?
#  2 If a record has no question, no question is asked, but the explanation
#    is still displayed.  If this is the case, the default_answer is still
#    entered into the configuration, if it exists.
#  3 If a question has no answer, it doesn't create any blank lines or such
#    in the output file, as it will be skipped in &Output_Config_Files.  For
#    this reason, &Prompt_Input, which is only called when the record contains
#    a user-answerable question, pads a space to the end of any 0-length input.
#    Not to worry: Output_Config_Files replaces said space with 0-length input
#    NOTE: we couldn't just only print the answer field when a real question
#          existed -- this would improperly handle case 2.
#    
###############################################################################

# Allow user to input an answer

    my ($current_answer,$toggle_yn)=@_;

    # Default item to have highlighted
    my $default_entry=0;

    # List of buttons for the y/n listbox widget
    my %yes_no_list =(0,"Yes",1,"No");

    # Input variables for the widgets
    my ($key,$answer);

    # Used to keep track of how widget was exited
    my $exited_with_enter=0;

    # Is this a yes/no question or not? If yes, use a button list...
    if ($toggle_yn) {
	if ($current_answer=~/^\s*Y/i) {
	    $default_entry="0";
	}
	elsif ($current_answer=~/^\s*N/i) {
	    $default_entry="1";
	}
	    
	($key, $answer)=list_box(    'window'    => $window,
				     'ypos'      => $LINES-6,
				     'xpos'      => 36,
				     'lines'     => 2,
				     'cols'      => 5,
				     'border'    => 'red',
				     'selected'  => $default_entry,
				     'list'      => \%yes_no_list,
				     );
	if ($answer==0) {
	    $answer="Y";
	}
	else {
	    $answer="N";
	}

	if ($key eq "\n") {
	    $exited_with_enter=1;
	}
    }
    # If it's not a yes/no question, create an answer blank...
    else {
	($key, $answer) = txt_field( 'window'        => $window,
					'ypos'          => $LINES-6,
					'xpos'          => 1,
					'lines'         => 2,
					'cols'          => $COLS-4,
					'content'       => "Answer: $current_answer",
					'border'        => 'red',
					'draw_only'     => 0,
					'pos'           => 8,
					);

	# If exited with enter, set flag
	if ($key eq "\n") {
	    $exited_with_enter=1;
	}

	# Prune off the prompt which is retained by the txt_field widget
	if ($answer =~ /^Answer:\s*(.*)/) {
	    $answer=$1;
	}

	# If answer is only a comment, blank it.
	if ($answer =~ /^\s*\#/ ) {
	    $answer=" ";
	}

	# If the $answer field is zero-length, add a space...  Read about
	# this above...

	if ($answer =~ /^$/) {
	    $answer=" ";
	}

	# If the entered answer is multi-lined, this won't do...  We prune
	# out all but the first non-blank line (plus any comment lines)
#	if ($answer =~ /\n/) {
#	    my $line,$pruned_answer;
#	    foreach $line (split($answer,)) {
#		if ($line =~ 
#
#	    }
#	}
    }

    return ($answer,$exited_with_enter);
}

sub Allow_Buttons {

    my ($input,$selected);

    while ($input !~ /[\t \n]/) {
	($input,$selected) = buttons(    'window'       => $window,
				     'buttons'       => ["< Back >","< Next >",
					       $detail_button{$detail_toggle}],
				     'ypos'          => $LINES-2,
				     'xpos'          => ($increment)-4,
				     'spacing'       => $increment/4,
				     'active_button' => $highlighted_button,
				     'draw-only'     => 0,
				 );
    }

    $highlighted_button=$selected;

    if ($selected == 2) {
	$selected="Detail";
    }
    elsif ($selected == 0) {
	$selected="Back";
    }
    else {
	$selected="Next";
    }

    # But wait! If we exited button widget via Tab, return none of these b/c
    # the user didn't SELECT a button!
    if ($input eq "\t") {
	$selected="Repeat_Scroll";
    }

    $selected;
}

1;
