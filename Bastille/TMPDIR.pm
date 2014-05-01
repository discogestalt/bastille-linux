# Copyright (C) 2000-2001 Peter Watkins
# Licensed under the GNU General Public License, version 2

#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program; if not, write to the Free Software
#    Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

package Bastille::TMPDIR;
use lib "/usr/lib";

use Bastille::API;
use Bastille::API::AccountPermission;

@ENV="";
undef(%ENV);
$ENV{PATH}="";
$ENV{CDPATH}=".";
$ENV{BASH_ENV}="";

&InstallScript;

sub InstallScript {
	# For Bourne/BASH/etc., put a .sh script in /etc/profile.d
	my $final_bash_script = "/etc/profile.d/bastille-tmpdir.sh";
	my $virgin_bash_script = "/bastille-tmpdir.sh";
	# For csh/tcsh, install the stub .csh script that calls the 
	# .sh script
	my $final_csh_script = "/etc/profile.d/bastille-tmpdir.csh";
	my $virgin_csh_script = "/bastille-tmpdir.csh";
	# .sh 'tmpwatch' defense script
	my $final_defense_script = "/etc/bastille-tmpdir-defense.sh";
	my $virgin_defense_script = "/bastille-tmpdir-defense.sh";

	if (&getGlobalConfig("TMPDIR","tmpdir") eq 'Y' ) {
		# Bourne/BASH
		unless ( -e $final_bash_script ) {
			&B_place($virgin_bash_script,$final_bash_script);
			&B_chmod(0755,$final_bash_script);
    		}
		# CSH/TCSH ...
		unless ( -e $final_csh_script ) {
			&B_place($virgin_csh_script,$final_csh_script);
			&B_chmod(0755,$final_csh_script);
    		}
		# 'tmpwatch' defense
		unless ( -e $final_defense_script ) {
			&B_place($virgin_defense_script,$final_defense_script);
			&B_chmod(0755,$final_defense_script);
    		}
	}
	if (&getGlobalConfig("TMPDIR","tmpdir") eq 'N' ) {
		# remove the TMPDIR script
		# Bourne/BASH
		if ( -e $final_bash_script ) {
			&B_delete_file($final_bash_script);
    		}
		# CSH/TCSH ...
		if ( -e $final_csh_script ) {
			&B_delete_file($final_csh_script);
    		}
		# 'tmpwatch' defense
		if ( -e $final_defense_script ) {
			&B_delete_file($final_defense_script);
    		}
	}
}

1;

