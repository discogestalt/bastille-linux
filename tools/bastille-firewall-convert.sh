#!/bin/sh
#
# bastille-firewall-convert.sh
#
# version 1.4
#
# script to pull the configuration settings
# of an existing, old-style, /etc/rc.d/init.d/bastille-firewall
# script for the new-style /etc/Bastille/bastille-firewall.cfg
# configuration used by Bastille 1.2.0 and newer
#
# Copyright 2001 by Peter Watkins
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program; if not, write to the Free Software
#    Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

OLDFILE=/etc/rc.d/init.d/bastille-firewall
NEWCFGFILE=/etc/Bastille/bastille-firewall.cfg
LASTCFGNUMBER=14

if [ ! -r $OLDFILE ]; then
	echo "\"${OLDFILE}\" does not exist or is not readable"
	exit 1
fi

if [ -f $NEWCFGFILE ]; then
	echo "New configuration file \"${NEWCFGFILE}\" already exists"
	echo "Use \"bastille-firewall-install.sh\" to upgrade your"
	echo "firewall scripts"
	exit 1
fi

start=`grep -n "^IPCHAINS=" $OLDFILE | head -1 | awk -F: '{print $1}'`
stop=`grep -n "^\# Computed values" $OLDFILE | head -1 | awk -F: '{print $1}'`
stop=`expr $stop - 2`

if [ ! -d /etc/Bastille ]; then
	mkdir -m 0700 /etc/Bastille
	if [ $? -ne 0 ]; then
		echo "Error creating directory /etc/Bastille"
		exit 1
	fi
fi

if [ -n "${start}" -a -n "${stop}" -a "${start}" -gt 0 -a "${stop}" -gt "${start}" ]; then
	numlines=`expr $stop - $start`
	if [ -n "${numlines}" -a "$numlines" -gt 5 ]; then
		head -${stop} $OLDFILE | tail -${numlines} > $NEWCFGFILE
		 if [ $? -ne 0 ]; then
			echo "Errror creating \"${NEWCFGFILE}\""
			exit 1
		fi
		# make sure it looks like a full set of options
		if [ "$(grep "^\\# ${LASTCFGNUMBER})" $NEWCFGFILE 2>/dev/null)" = "" ]; then
			# missing last config option
			echo "WARNING: Your old script appears to lack configuration"
			echo "         variables for some newer features"
		fi
	else
		echo "Error calculating how many lines to grab!"
		exit 1
	fi
else
	echo "Error parsing \"${OLDFILE}\""
	exit 1
fi

echo "Configuration values copied to \"${NEWCFGFILE}\" for Bastille 1.2.0+ firewall scripts"
exit 0
