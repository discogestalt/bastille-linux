#!/bin/sh
#
# bastille-tmpdir.sh
#
# version 1.14
#
# This script sets TMPDIR and TMP environment variables for some added
# safety on multi-user systems. Many applications write temporary
# files in unsafe ways to /tmp unless TMPDIR and/or TMP are set.
#
# For performance, backup, and housekeeping reasons, this script
# tries to (safely!) use space in /tmp (or other directory: see Settings, below)
#  performance:  many systems use tmpfs for /tmp
#  backup:       many backup configurations ignore /tmp
#  housekeeping: many systems prune /tmp with tools like 'tmpwatch'
#
# This script also makes two levels of directories so other users cannot
# glean much information by stat()ing the parent of $TMPDIR
#
#  -------------    ****   Important: required apps   ****    -------------
#
# 	You should have the following apps installed, and in a normal search path,
#	for this script to work properly:
#		grep, sed, which, uname, cut, ls, grep, mkdir, echo, cat, awk, id, expr, date, eval
#
#	The following apps are recommended:
#		printf, od
#	Also a readable /dev/urandom device is recommended.
#
#  -------------    ****   Important: required apps   ****    -------------
#
# Copyright (c) 2000-2001 Peter Watkins
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
# PREFDIR: the directory where TMPDIR should be made
#          /tmp is usually the best choice, unless you have another
#          partition explicitly created for temporary files
#           ** $PREFDIR should be user-writable, root-owned, and "sticky" (mode 01777) **
#	    ** and all parent dirs must be root-owned and sticky or mode go-w **
PREFDIR=/tmp
# 
# MAXTRIES: how many times to try creating a directory in $PREFDIR
#           before giving up and using $HOME. Since $PREFDIR is essentially world-writable,
#           we may have to try multiple times before successfully making
#           a safe temporary directory
MAXTRIES=20
#
# FAKEDATE: if non-empty, this will be used with 'touch' to set a fake timestamp
#	    on the top-level TMPDIR to further limit the information other users
#	    might glean from looking for tmpdir info (though users gathering historical
#	    info can determine the true age of the directory). Read the man page
#	    for 'touch' for format information
FAKEDATE=200001011200		# set top dir to timestamp of noon, 1 Jan 2000
#
# STATEFUL: if set to "YES", will keep trck of TMPDIRs created on different hosts in
#           $HOME/.tmpdirs/ so that $PREFDIR won't be littered with directories,
#           and nosy neighbors will have less information about system usage
STATEFUL="YES"
#
# RECREATE_DIR: set to "YES" if you want the script to try and recreate $TMPDIR
#	        if the user had a value stored in their $HOME state file but the
#               directory no longer exists. Advantage: nosy neighbors less likely to
#               notice new directories. Disadvantage: regular users may become accustomed
#               to having the same $TMPDIR each time, may be foolish enough to script
#               around the value of $TMPDIR instead of using the TMPDIR env variable.
RECREATE_DIR="NO"
#
# WHICH:	Please tell me where the real 'which' is (some Linux
#		distributions set up an alias for which!)
#WHICH=/usr/bin/which		# manual
# or the following will look for which:
for p in /usr/sbin /sbin /usr/bin /bin ; do
	[ -x "${p}/which" ] && WHICH="${p}/which"
done
#
# DEFENSE_SCRIPT: location of script to defend $TMPDIR against programs like 'tmpwatch'
#		  This script typically 1) does something inside $TMPDIR (mkdir/rmdir)
#		  to keep $TMPDIR from looking "stale" and 2) has code to notify the
#		  user (write/mail/X pop-up) if something seems amiss 
DEFENSE_SCRIPT=/etc/bastille-tmpdir-defense.sh
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
	for a in printf od cut sed head; do
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
	MYHOST=`uname -n 2>/dev/null| sed 's:[^a-zA-Z0-9\.\-]::g; s:\.\.::g' 2>/dev/null| cut -c1-64 2>/dev/null`
	[ -z "${MYHOST}" ] && MYHOST=DEFAULT
	return 0
}
#
dir_owned_by() {
	# check if $1 is a directory owned by $2
	# the 'cut' here looks extraneous, but some versions of 'awk' (e.g. SunOS 5.x)
	# choke on long lines, so 'cut' is used here for some added safety
	owner=`ls -ld $1 2> /dev/null | cut -c1-40 | awk '{print $3}'`
	[ "${owner}" != "" -a "${owner}" = "$2" ] && return 0
	return 1
}
#
dir_has_perms() {
	# check if $1 has perms $2 (=="0700" or "sticky" or "go-w")
	if [ "$2" = "0700" ]; then
		# this is an exact perm test (but we allow drw[xs]--[S-]--[T-], too)
		dhptest=`ls -ld $1 2> /dev/null | grep '^drw[xs]\-\-[S\-]\-\-[T\-]'`
		[ ! -z "${dhptest}" ] && return 0
	fi
	if [ "$2" = "sticky" ]; then
		# only care about dir flag and sticky flag
		dhptest=`ls -ld $1 2> /dev/null | grep '^d........t'`
		[ ! -z "${dhptest}" ] && return 0
	fi
	if [ "$2" = "go-w" ]; then
		# only care about dir flag and g/o write flags
		dhptest=`ls -ld $1 2> /dev/null | grep '^d....-..-.'`
		[ ! -z "${dhptest}" ] && return 0
	fi
	return 1
}
#
# ---- Main script ------------------------------------------------
#
if [ -z "${TMPDIR}" -o \! -d "${TMPDIR}" ]; then
    # we only go through this if we don't already have $TMPDIR
    # or if the directory no longer exists
    ${WHICH} cp >/dev/null 2>&1
    if [ $? -ne 0 -o ! -x "${WHICH}" ]; then
       echo "WARNING: 'which' not available; unable to set safe TMPDIR"
	[ $# -gt 0 ] && exit 1	# non-zero exit code for csh
    else
        RC=0
        TRIES=0
	safe_hostname		# set MYHOST
	get_random		# set RAND
	TDIR=${HOME:-}/.tmpdirs
	[ $TDIR = "//.tmpdirs" ] && TDIR="/.tmpdirs"    # for ~root = /
	[ "${HOME:-}" = "" ] && STATEFUL="NO"           # no state if no $HOME
	TRYDIR=""
	TRYDIR2=""
	TESTDIR=""
	TESTDIR2=""
	THIS_USER=`id -un`
	#
	# make the dir to store info about reusable TMPDIRS
	if [ ! -d "$TDIR" -a "${STATEFUL}" = "YES" ]; then
		mkdir -m 0700 "$TDIR" || TDIR=""
	fi
	# do we have a suggested TMPDIR inside a safe-looking $TDIR?
	w=0
	[ \( ! -z "${TDIR}" \) -a -f "${TDIR}/${MYHOST}" -a "${STATEFUL}" = "YES" ] && dir_owned_by "$TDIR" $THIS_USER && dir_has_perms "$TDIR" "0700" && w=1
	if [ $w -eq 1 ]; then
		# FIXME: a more paranoid script might check this data more carefully
		# but since TDIR is in $HOME, any tampering  suggests
		# bigger problems, so I'm skipping those tests for now
		# FIXME: it would also be more efficient, disk-wise, to use a single
		# state file inside $HOME instead of using a separate file
		# for each `uname -n` hostname
		TRYDIR=`cat "${TDIR}/${MYHOST}"`
		x=0
		app_available sed && app_available grep && x=1
		if [ $x -eq 1 ]; then
			# minimal sanity checks: no "..", stay in $PREFDIR
			# this will probably reject any suggestions inside 
			# $HOME, which is probably desirable!
			TRYDIR=`cat "${TDIR}/${MYHOST}" | sed 's:\.\.::g' | grep "^${PREFDIR}/"`
		fi
		unset x
		TRYDIR2="${TRYDIR}"
	fi
	unset w
	if [ ! -z "${TRYDIR}" ]; then
		# see if $TRYDIR exists, is owned by me, and looks safe
		#echo "FIXME: add code here!"
		TESTDIR=`echo "${TRYDIR}" | sed 's:/[^\/]*$:: ; s:^$:/:' `
		# TMPDIR must be owned by me, mode 0700
		x=0
		dir_owned_by "${TRYDIR}" ${THIS_USER} && dir_has_perms "${TRYDIR}" "0700" || x=1
		if [ $x -eq 1 ]; then
			# bad permissions on TMPDIR, pick another
			TRYDIR=""
		fi
		unset x
		# same thing with TMPDIR's parent
		if [ ! -z "${TRYDIR}" ]; then
			x=0
			dir_owned_by "${TESTDIR}" ${THIS_USER} && dir_has_perms "${TESTDIR}" "0700" || x=1
			if [ $x -eq 1 ]; then
				# bad permissions on TMPDIR, pick another
				TRYDIR=""
			fi
			unset x
		fi 
		# higher level dirs must be root/sticky or root/go-w
		TESTDIR2="${TESTDIR}"
		TESTDIR=`echo "${TESTDIR}" | sed 's:/[^\/]*$:: ; s:^$:/:' `
		while [ "${TESTDIR}" != "${TESTDIR2}" -a \( ! -z "${TRYDIR}" \) ]; do
			dir_owned_by "${TESTDIR}" "root" ; x=$?
			dir_has_perms "${TESTDIR}" "sticky" ; y=$?
			dir_has_perms "${TESTDIR}" "go-w" ; z=$?
			if [ \( \( $z -ne 0 \) -a \( \( $y -ne 0 \) \) -o \( $x -ne 0 \) \) ]; then
				# bad perms
				TRYDIR=""
				TESTDIR="${TESTDIR2}"
			fi
			unset x y z
			if [ ! -z "${TRYDIR}" ]; then
				TESTDIR2="${TESTDIR}"
				TESTDIR=`echo "${TESTDIR}" | sed 's:/[^\/]*$:: ; s:^$:/:' `
			fi	
		done
	fi
	if [ -z "${TRYDIR}" ]; then
		# need to (re)create a safe directory
		#
		RC=1
		# first try to remake the old dir name, if possible, and so configured
		x=0
		app_available sed && [ ! -z "${TRYDIR2}" -a "${RECREATE_DIR}" = "YES" ] && x=1
		if [ $x -eq 1 ]; then
			# strip the lower level dir name ("/files") from TRYDIR2
			TRYDIR=`echo ${TRYDIR2} | sed 's:/files$::'`
			(mkdir -m 0700 "${TRYDIR}" && mkdir -m 0700 "${TRYDIR}/files") 2>/dev/null
			RC=$?
			[ $RC -eq 0 -a ! -z "${FAKEDATE}" ] && touch -t $FAKEDATE "${TRYDIR}" 2>/dev/null
		fi
		unset x
	        # see if we need to make a dir, and we haven't already tried too hard
        	while [ \( $RC -ne 0 \) -a \( $TRIES -lt $MAXTRIES \) ]; do
			TRYDIR="${PREFDIR}/${THIS_USER:-}-tmp.${RAND}"
			(mkdir -m 0700 "${TRYDIR}" && mkdir -m 0700 "${TRYDIR}/files") 2>/dev/null
			RC=$?
			[ $RC -eq 0 -a ! -z "${FAKEDATE}" ] && touch -t $FAKEDATE "${TRYDIR}" 2>/dev/null
			TRIES=`expr $TRIES + 1`
			get_random		# set RAND
		done
		if [ $TRIES -ge $MAXTRIES ]; then
			# fallback is to use space in $HOME
			echo "Warning: Unable to make safe temp dir in ${PREFDIR}"
			TRYDIR="${HOME-}/tmp-${RAND}"
			(mkdir -m 0700 "${TRYDIR}" && mkdir -m 0700 "${TRYDIR}/files") 2> /dev/null   
			RC=$?
			# don't bother to 'touch' the dir if inside $HOME
			# don't record state if the dir is inside $HOME
			[ \( ! -z "${TDIR}" \) -a \( -d "${TDIR}" \) -a \( ! -z "${MYHOST}" \) -a "${STATEFUL}" = "YES" -a $RC -eq 0 ] && dir_owned_by "${TDIR}" $THIS_USER && dir_has_perms "${TDIR}" 0700 && rm "${TDIR}/${MYHOST}" 2>/dev/null && STATEFUL="NO"
		fi
		if [ $RC -eq 0 ]; then 
			# the actual temp dir is $TRYDIR/files
			TRYDIR="${TRYDIR}/files"
		fi
	fi
        if [ $RC -ne 0 ]; then
                echo "ERROR: Unable to make safe temp directory!"
		echo "       Proceed with caution!"
		[ $# -gt 0 ] && exit 1	# non-zero exit code for csh
        else
                # success
                TMP="${TRYDIR}"
                TMPDIR="${TRYDIR}"
                export TMP
                export TMPDIR
		x=0
		[ \( ! -z "${TDIR}" \) -a \( -d "${TDIR}" \) -a \( ! -z "${MYHOST}" \) -a "${STATEFUL}" = "YES" ] && dir_owned_by "${TDIR}" $THIS_USER && dir_has_perms "${TDIR}" 0700 && x=1
		if [ $x -eq 1 ]; then
			# record the TMPDIR value for the next time
			echo "${TMPDIR}" > "${TDIR}/${MYHOST}"
		fi
		unset x
		# Below: can't run the bg task if spawned by the csh
		# wrapper, thus the insistence that $# -eq 0
		if [ $# -eq 0 -a \! -z "${DEFENSE_SCRIPT}" -a -f "${DEFENSE_SCRIPT}" -a -x "${DEFENSE_SCRIPT}" ]; then
			# schedule background task to update ctime/mtime
			# attributes so $TMPDIR won't be purged while the
			# user remains logged in
			# Why eval? It's stupid, but if you don't 'eval' this, 
			#  it looks awkward in 'jobs' (e.g. "/bin/sh $DEFENSE_SCRIPT &"
			#  instead of "/bin/sh /etc/bastille-tmpdir-defense.sh &"
			eval "$DEFENSE_SCRIPT $$ &"
		fi
        fi
	# unset variables used in this loop
	unset MYHOST
	unset RC
	unset TDIR
	unset THIS_USER
	unset TESTDIR
	unset TESTDIR2
	unset TRIES
	unset TRYDIR
	unset TRYDIR2
    fi
else
	x=0
	[ $# -gt 0 ] && x=1
	if [ $x -eq 1 ]; then
		echo ""
		unset x
		exit 0
	fi
fi
# unset global variables
unset DEFENSE_SCRIPT
unset FAKEDATE
unset MAXTRIES
unset PREFDIR
unset RECREATE_DIR
unset TOUCH_ALL_DIRS
unset TOUCH_INTERVAL
unset WHICH

# now undefine the functions
unset app_available
unset get_random
unset safe_hostname
unset dir_owned_by
unset dir_has_perms

# If we're passed an argument, echo the TMPDIR value
# This allows /bin/csh code like this (but safer!)
#    if ( -f /etc/profile.d/bastille-tmpdir.sh ) then
#	# actually we'd set an unimportant var, and watch $?
#	# before setting TMPDIR/TMP
#	setenv TMPDIR `/bin/sh /etc/profile.d/bastille-tmpdir.sh echo`
#	setenv TMP $TMPDIR
#    endif
# so we don't have to re-write this code for other login shells ;-)
#
[ $# -gt 0 ] && echo $TMPDIR

