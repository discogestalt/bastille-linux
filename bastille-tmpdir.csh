#!/bin/csh
#
# bastille-tmpdir.csh
#
# version 1.6
#
# This is a stub script for calling "bastille-tmpdir.sh" to set 
# safe values for TMPDIR and TMP environment variables, creating
# directories as needed. See bastille-tmpdir.sh for more information
# including required applications.
#
# Copyright (c) 2000-2001 Peter Watkins
#
# licensed under the terms of the GNU General Public License
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License, version 2, under which this file is licensed, for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program; if not, write to the Free Software
#    Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

set BSCRIPT = "/etc/profile.d/bastille-tmpdir.sh"
set DEFENSE_SCRIPT = "/etc/bastille-tmpdir-defense.sh"

if ( -f $BSCRIPT ) then
	setenv TMPTMPDIR `/bin/sh $BSCRIPT echo`
	if ( $? == 0 ) then
		if ( -d "$TMPTMPDIR" ) then
			setenv TMPDIR $TMPTMPDIR
			setenv TMP $TMPTMPDIR
			if ( -f $DEFENSE_SCRIPT ) then
				$DEFENSE_SCRIPT $$ &
			endif
		endif
	else
		echo "WARNING: unable to set safe TMPDIR/TMP directory!"
	endif
	setenv TMPTMPDIR ""
endif

