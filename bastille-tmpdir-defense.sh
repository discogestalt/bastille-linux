#!/bin/sh
#
# bastille-tmpdir-defense.sh
#
# version 1.11
#
# This script is designed to complement bastille-tmpdir.sh
# for "defending" TMPDIR directories on systems running 
# pruning applications like 'tmpwatch'; making sure the 
# atime/mtime of $TMPDIR are updated periodically so that 
# the pruning application won't remove it. 
#
# This script also warns the user if it sees problems 
# with TMPDIR.
#
# ARGUMENTS:
#       as of v 1.2, this expects one argument: the PID
#       of the login shell it was spawned for; this enables
#       the script to gracefully kill itself *iff* /proc is
#       available
#
#  -------------    ****   Important: required apps   ****    -------------
#
# 	You should have the following apps installed, and in a normal search path,
#	for this script to work properly:
#		grep, sed, which, uname, cut, ls, grep, mkdir, echo, cat, id, touch, expr
#
#       The following apps are recommended:
#               printf, od
#       Also a readable /dev/urandom device is recommended.
#
#  -------------    ****   Important: required apps   ****    -------------
#
# Copyright (c) 2001 Peter Watkins
# with thanks to Sweth
#
# licensed under the terms of the GNU General Public License, version 2
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program; if not, write to the Free Software
#    Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
#
# ---- Settings ----------------------------------------------------
#
# TOUCH_INTERVAL: if > 0, will start a background task that periodically
#	          makes and removes a directory inside $TMPDIR. The reason
#		  for this is to avoid a problem on systems that run periodic
#		  directory cleanups like 'tmpwatch': if a user is logged on
#		  for a long time without using the $TMPDIR directory, then
#		  tools like 'tmpwatch' might remove the directory, thereby
#		  creating an opportunity for an attack.
#		  N.B. this setting is in *seconds*
TOUCH_INTERVAL=7200		# every two hours
#TOUCH_INTERVAL=432000		# Red Hat's usual tmpwatch interval is
#				# 240 hours, == 864000 seconds
#				# (see /etc/cron.daily/tmpwatch)
#
# USEAT:	used in conjunction with TOUCH_INTERVAL
#		if "Y", will try to run this script via 'at' instead
#		of using a persistent 'while' loop. The advantage
#		to USEAT is that users of text-based logins (getty, SSH, etc.)
#		won't see the defense script in their 'jobs' and,
#		therefore, anything they background will have a normal
#		background number. The main disadvantage of 'at' is 
#		that if anyone unschedules an 'at' task, the user will
#		not be warned, and might be put at risk
#		Note #1: TOUCH_INTERVAL must be > 120 to use 'at'
#		Note #2: the script will fall back to looping if you
#		         specify USEAT but the user is not allowed to
#		         use 'at', so it is safe to leave this as "Y"
USEAT=Y
#
# MYPATH:	full path to this script; other scripts call this
#		one, so be careful if you want to relocate it
MYPATH=/etc/bastille-tmpdir-defense.sh
#
# WHICH:        Please tell me where the real 'which' is (some Linux
#               distributions set up an alias for which!)
#WHICH=/usr/bin/which           # manual
# or the following will look for which:
for p in /usr/sbin /sbin /usr/bin /bin ; do
        [ -x "${p}/which" ] && WHICH="${p}/which"
done
#
# ---- Functions --------------------------------------------------
#
app_available() {
        # takes a single argument, an app name, and tests for its availabilty
        ${WHICH} $1 >/dev/null 2>&1
        return $?
}
#
get_random() {
        # generate a string of random characters
        r=1
        [ ! -r /dev/urandom ] && r=0
        for a in printf od cut head sed; do
                app_available $a || r=0
        done
        if [ $r -eq 1 ]; then
		RANDVAL=`od -N 8 /dev/urandom|sed 's:[ 	]*::g'|sed 's:^0*::g'| sed 's:[^0-9]::g'|head -1|cut -c1-8`
		RAND=`printf %x "${RANDVAL}" | cut -c -16`
		unset RANDVAL
        else
                # less random, but we're careful with this anyway...
                RAND="${RANDOM}"
                # Solaris /bin/sh doesn't support $RANDOM !?!
                if [ "${RAND}" = "" ]; then
                        if [ -x /bin/ksh ]; then
                                # ask the Korn shell for a random number
                                RAND=`echo 'echo $RANDOM' |/bin/ksh`
                        else
                                # use our PID
                                RAND=$$
                        fi
                fi
        fi
        unset r
        return 0
}
#
safe_hostname() {
        # return `uname -n` scrubbed of unexpected chars
        MYHOST=`uname -n 2>/dev/null| sed 's:[^a-zA-Z0-9\.]::g; s:\.\.::g' 2>/dev/null| cut -c1-64 2>/dev/null`
        [ -z "${MYHOST}" ] && MYHOST=DEFAULT
        return 0
}
#
send_warning() {
	# notify the user of problems via various mechanisms
	# write message to terminal (fallback to 'echo' if not running via 'at')
	echo $MSG | write $THIS_USER 2>/dev/null
	if [ $? -ne 0 -a "${usingat}" != "Y" ]; then
		echo $MSG
	fi
	# then mail to user
	# we must temporarily unset TMPDIR for GNU/Linux's
	# 'mail' to be able to write its temp file!
	TMPDIR=""; echo $MSG | $MAILER -s "${MSGSUBJ}" $THIS_USER 2>/dev/null ; TMPDIR=$TMP
	# how about X?
	${WHICH} wish >/dev/null 2>&1 && [ ! -z "${DISPLAY}" ] && echo "frame .t  -width 200;message .t.msg -text \"${MSG}\" -width 280;label .t.bmap -bitmap error;catch { .t.bmap configure -fg red };button .b -text OK -command exit;bind . <Return> exit\n;wm title . \"${MSGSUBJ}\";catch {wm geometry . 370x180+270+170};pack .t.bmap .t.msg  -side left;pack .b -side bottom -pady 4;pack .t -expand true" | wish 
	return 0
}
#
# ---- Main -------------------------------------------------------
#
[ ! -z "${TMP}" ] && TMPDIR="${TMP}"
if [ \! -z "${TMPDIR}" -a \! -z "${TOUCH_INTERVAL}" -a "${TOUCH_INTERVAL}" -gt 0 ]; then
	#
	# we only go through this if we have TMPDIR set
	# and TOUCH_INTERVAL set
	#
	# Make sure we have the pid of our login shell
	if [ $# -le 0 ]; then
		echo "usage: $0 pidOfLoginShell"
		exit 1
	fi
	#
	# Get the pid for the process we should terminate after
	pprocpid="$1"
	if [ -d /proc  -a \( ! -r "/proc/${pprocpid}/fd" \) ]; then 
		# the process that kicked this off is gone
		# so there's no pointin checking (chances
		# are that this is running from an 'at' job
		# scheduled before the user logged out
		exit
	fi
	#
	# Are we running from 'at'?
	usingat=N
	if [ $# -ge 2 -a "$2" = "useat" ]; then
		usingat=Y
	fi
	#
	${WHICH} cp >/dev/null 2>&1
	if [ $? -ne 0 -o ! -x "${WHICH}" ]; then
		echo "WARNING: 'which' not available; unable to run TMPDIR defense script"
		exit 1
	fi
	#
	get_random	# set RAND
	safe_hostname	# set MYHOST
	THIS_USER=`id -un`
	#
	# See if we can schedule this via 'at' instead of running
	# as a background task
	loopval=1	# keeps test loop running in while loop (default)
	if [ "${USEAT}" = "Y" -a "${TOUCH_INTERVAL}" != "" -a "${TOUCH_INTERVAL}" -ge 120 ]; then
		x=0
		app_available expr && x=1
		if [ $x -eq 1 ]; then
			minwait=`expr $TOUCH_INTERVAL / 60`
			if [ $? -eq 0 ]; then
				echo "DISPLAY=\"${DISPLAY}\" export DISPLAY ; ${MYPATH} ${pprocpid} useat" | at now + ${minwait} minutes 2> /dev/null
				if [ $? -eq 0 ]; then
					loopval=0 # do not run test in loop
					TOUCH_INTERVAL=0
				fi
			fi
		fi
		unset x
	fi
	#
	# Decide which app to use for emailing warnings
	MAILER=mail
	app_available mailx && MAILER=mailx
	#
	if [ $loopval -eq 1 ]; then
		# We have NOT scheduled the next test via 'at' and must
		# warn the user if we exit unexpectedly
		# set an exit handler in case the user kills this script prematurely
		XMSG="SECURITY ALERT: TMPDIR problem on host '${MYHOST}': The TMPDIR defense script is no longer protecting TMPDIR on '${MYHOST}'. This is alright if you are logging out of '${MYHOST}', otherwise you should restart the defense script or log out and log back in."
		XMSGSUBJ="SECURITY ALERT: TMPDIR problem on ${MYHOST}"
		trap "x=0 ; [ \( -z \"${pprocpid}\" \) -o \( -d /proc -a -r \"/proc/${pprocpid}/fd\" \) ] && x=1 ; if [ \$x -eq 1 ]; then MSG=\"\${XMSG}\" MSGSUBJ=\"\${XMSGSUBJ}\" send_warning ; fi ; unset x " EXIT
	fi
	#
	TD="${TMPDIR}/touchdir.${RAND}"
	whileval=1
	while [ ${whileval} -eq 1 ]; do 
		if [ -d /proc  -a \( ! -r "/proc/${pprocpid}/fd" \) ]; then 
			# the process that kicked this off is gone
			# so there's no point in checking (chances
			# are that the user logged out some time ago)
			exit
		fi
		# 'touch' updates atime attr safely, mkdir/rmdir confirm write perms
		x=1
		touch "${TMPDIR}" && mkdir "${TD}" 2>/dev/null && rmdir "${TD}" 2> /dev/null && x=0
		if [ $x -eq 1 ]; then
			# set the messages in vars for easier processing
			MSG="SECURITY ALERT: TMPDIR problem on host '${MYHOST}': Please check the existence and permissions on ${TMPDIR} and log out if you have any doubts! (error creating TMPDIR/touchdir.${RAND} at `date`)"
			MSGSUBJ="SECURITY ALERT: TMPDIR problem on ${MYHOST}"
			send_warning 
		fi
		unset x
		sleep ${TOUCH_INTERVAL}
		whileval=${loopval}
	done
	#
	unset MAILER
	unset TD
	unset RAND
	unset MYHOST
	unset THIS_USER
	unset pprocpid
	unset usingat
	unset loopval
fi
unset TOUCH_INTERVAL
unset USEAT
unset WHICH
unset MYPATH

# now undefine the functions
unset app_available
unset get_random
unset safe_hostname
unset send_warning

