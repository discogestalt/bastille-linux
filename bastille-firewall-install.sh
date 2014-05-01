#!/bin/sh
#
# install.sh
#
# script to install/upgrade Bastille firewall
#
# $Id: bastille-firewall-install.sh,v 1.7 2005/09/13 03:47:28 fritzr Exp $
#
# Copyright (C) 2001-2002 Peter Watkins
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License, version 2, under which this file is licensed, for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program; if not, write to the Free Software
#    Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA


CFG=/etc/Bastille/bastille-firewall.cfg
REQUIRED_APPS="echo grep netstat awk ifconfig expr egrep tail sort uniq head wc sed ls"

# Functions
# app_available: see if a given application is installed
app_available() {
  # takes a single argument, an app name, and tests for its availabilty
  which $1 >/dev/null 2>&1
  return $?
}
# get_answer: ask Y/N question until definite answer is given
get_answer() {
  question="${1}"
  rc=-1
  while [ $rc -lt 0 ]; do
    echo -n "${question} (Y or N) "
    read ans
    [ "$ans" = "Y" ] && rc=1
    [ "$ans" = "N" ] && rc=0
  done
  return $rc
}
# b_backup: back up file, increment backup_errors if problem
b_backup() {
  source="${1}"
  safedir="${2}"
  if [ -f "${source}" ]; then
    cp -p "${source}" $safedir/ && return 0
    backup_errs=`expr $backup_errs + 1`
    return 1
  fi
  return 0
}
# b_place: install file, editing "init.d" values as needed
b_place() {
  source="${1}"
  target="${2}"
  if [ -f "${source}" -a -d "${target}" ]; then
    [ -f "${target}/${source}" ] && chmod u+w "${target}/${source}"
    sed "s:/etc/rc.d:${initdbase}:g" < "${source}" > "${target}/${source}"
    return $?
  else
    echo "Error installing \"${source}\" in \"${target}\"" > /dev/stderr
    return 1
  fi
}

# check for required apps
missing_apps=""
for a in $REQUIRED_APPS; do
  app_available ${a} || missing_apps="${missing_apps} ${a}"
done
if [ -n "${missing_apps}" ]; then
  echo "ERROR: The following tools are needed to install & use this firewall:"
  echo "\"$missing_apps\""
  exit 3
fi

initdbase=""
for t in /etc /etc/rc.d ; do
  [ -d ${t}/init.d ] && initdbase="${t}"
done
if [ -z "${initdbase}" ]; then
  echo "ERROR: Cannot find init.d directory; unable to install"
  exit 1
fi

# make temp dir
TMP=${TMP:-/tmp}
TMPDIR="${TMP}/$$.fwall"
mkdir -m 0700 "$TMPDIR" 
if [ $? -ne 0 ]; then
  echo "ERROR: Unable to make tmp directory; unable to install"
  exit 2
fi
CFG2=${TMPDIR}/bastille-firewall.cfg.temp

if [ ! -d /etc/Bastille ]; then
  mkdir -m 0700 /etc/Bastille 2>/dev/null
  if [ ! -d /etc/Bastille -o ! -w /etc/Bastille ]; then
    echo "ERROR: Error creating /etc/Bastille; aborting"
    exit 6
  fi
fi

# convert old-style scripts to new-style
if [ -f ${initdbase}/init.d/bastille-firewall -a \! -f $CFG -a -f ./bastille-firewall-convert.sh ]; then
	# run the convert script to build a temporary config file,
	# so old settings are carried over
	echo
	echo "Extracting settings from \"${initdbase}/init.d/bastille-firewall\" to"
	echo "the \"${CFG}\" file now used"
	chmod +x ./bastille-firewall-convert.sh
	./bastille-firewall-convert.sh
	chmod -x ./bastille-firewall-convert.sh
fi

# check for current settings, migrate
installed=0
what="installing"
echo
if [ -f $CFG ]; then
  what="upgrading"
  installed=1
  echo "Upgrading bastille-firewall..."
  cp -p bastille-firewall.cfg $CFG2
  if [ $? -ne 0 ]; then
    echo "ERROR: Error making working copy of existing config"
    exit 4
  fi
  egrep '^[0-9A-Z\_]*\=.' $CFG > $TMPDIR/oldfull
  oldvars=`awk -F= '{print $1}' < $TMPDIR/oldfull`
  newvars=`egrep '^[0-9A-Z\_]*\=' bastille-firewall.cfg |awk -F= '{print $1}'`
  cp -p $CFG $TMPDIR/
  i=1
  for var in $oldvars; do
    opos=`grep -n "^${var}=" $CFG2 | tail -1 | awk -F: '{print $1}'`
    if [ -n "${opos}" ]; then
      sub=`head -${i} $TMPDIR/oldfull | tail -1`
      l=`wc -l $CFG2 | awk '{print $1}'`
      h=`expr $opos - 1`
      t=`expr $l - $opos`
      head -${h} $CFG2 > $CFG2.tmp
      echo $sub >> $CFG2.tmp
      tail -${t} $CFG2 >> $CFG2.tmp
      cat $CFG2.tmp > $CFG2
    fi
    i=`expr $i + 1`
  done
  new=""
  for n in $newvars; do
    found=0
    for var in $oldvars; do
      if [ "${var}" = "${n}" ]; then
        found=1
      fi
    done
    if [ $found -ne 1 ]; then
      new="${new} $n"
    fi
  done
  if [ -n "${new}" ]; then
    echo
    echo "The following options are new to bastille-firewall; you"
    echo "should look at bastille-firewall.cfg for more information:"
    echo $new
    echo
  fi
  # back up current files
  backup_errs=0
  mkdir $TMPDIR/backup
  if [ $? -ne 0 ]; then
    echo "ERROR: Unable to make backup directory; aborting"
    exit 7
  fi
  b_backup ${initdbase}/init.d/bastille-firewall $TMPDIR/backup
  b_backup /sbin/bastille-ipchains $TMPDIR/backup
  b_backup /sbin/bastille-netfilter $TMPDIR/backup
  b_backup /sbin/bastille-firewall-schedule $TMPDIR/backup
  b_backup /sbin/bastille-firewall-reset $TMPDIR/backup
  b_backup /etc/Bastille/bastille-firewall-early.sh $TMPDIR/backup
  b_backup $CFG $TMPDIR/backup
  b_backup /sbin/ifup-local $TMPDIR/backup
  if [ $backup_errs -eq 0 ]; then
    echo "old files/scripts copied to $TMPDIR/backup"
  else
    echo "Warning: ${backup_errs} errors encountered backing up old files"
  fi
  chmod u+w $CFG
  cat $CFG2 > $CFG
else
  # brand-new: use the default config file
  echo "Installing bastille-firewall..."
  cp bastille-firewall.cfg $CFG
fi

copy_ok=0
b_place bastille-firewall ${initdbase}/init.d && \
b_place bastille-firewall-early.sh /etc/Bastille && \
b_place bastille-ipchains /sbin && \
b_place bastille-netfilter /sbin && \
b_place bastille-firewall-reset /sbin && \
b_place bastille-firewall-schedule /sbin && \
copy_ok=1

# what about ifup-local?
if [ $installed -eq 0 ]; then
  # Fresh install: be careful
  [ -e /sbin/ifup-local -a ! -f /sbin/ifup-local.pre-bastille ] && mv /sbin/ifup-local  /sbin/ifup-local.pre-bastille
fi
[ $copy_ok -eq 1 ] && copy_ok=0 && b_place ifup-local /sbin && copy_ok=1

if [ $copy_ok -eq 1 ]; then
  for f in bastille-ipchains bastille-netfilter bastille-firewall-reset bastille-firewall-schedule ifup-local; do
    chmod 0500 /sbin/${f} || copy_ok=0
  done
  chmod 0500 ${initdbase}/init.d/bastille-firewall || copy_ok=0
  chmod 0400 $CFG || copy_ok=0
  chmod 0400 /etc/Bastille/bastille-firewall-early.sh || copy_ok=0
fi

if [ $copy_ok -ne 1 ]; then
  echo "ERROR: Error copying bastille-firewall files; installation aborting"
  exit 5
fi

# TODO: check the init order of the network script
# (bastille-firewall defaults are s=05, k=98)
# and modify ${initdbase}/init.d/bastille-firewall as needed

# offer to activate firewall
c=0
app_available chkconfig || app_available update-rc.d && c=1
chk=0
app_available chkconfig && chk=1
rcd=0
app_available update-rc.d && rcd=1
ci=`chkconfig --list bastille-firewall 2>/dev/null | grep :on`
dtest=`ls ${initdbase}/rc3.d/[SK]??bastille-firewall 2>/dev/null`
if [ $c -eq 1 ]; then
  if [ \( $chk -eq 1 -a -z "${ci}" \) -o \( $rcd -eq 1 -a -z "${dtest}" \) ]; then
    echo
    echo "You may configure bastille-firewall to run automatically; we"
    echo "recommend you examine $CFG"
    echo "and test the firewall first."
    get_answer "Configure bastille-firewall to run automatically?"
    enable=$?
    if [ $enable -eq 1 ]; then
      if [ $chk -eq 1 ]; then
        chkconfig --add bastille-firewall
        chkconfig --level 2345 bastille-firewall on
        rc=$?
      else
        update-rc.d -f bastille-firewall remove 2>/dev/null
        # NOTE: what should the runlevels be in Debian,
        #       especially considering we don't know how 
        #       to make the rules re-evaluate when each
        #       network inteface is raised?
        #       (IIUC, networking runs as S40, so we'll
        #        run immediately afterward)
        update-rc.d bastille-firewall defaults 41 98
        rc=$?
      fi
      if [ $rc -ne 0 ]; then
        echo "Warning: error configuring automatic operation"
      fi
    fi
  fi  
fi

# offer to "save" current ruleset?
if [ \( $chk -eq 1 -a -z "${ci}" \) -o \( $rcd -eq 1 -a -z "${dtest}" \) ]; then
  for old in iptables ipchains; do
    ctest=`chkconfig --list $old 2>/dev/null | grep :on`
    if [ -n "${ctest}" -a \( -x "${initdbase}/init.d/${old}" \) ]; then
      echo
      echo "You have an ${old} packet filter script enabled."
      echo "This script (as distributed by some vendors) has a"
      echo "\"save\" option for preserving rules after rebooting."
      get_answer "Attempt to save current ${old} rules?"
      save=$?
      if [ $save -eq 1 ]; then
        ${initdbase}/init.d/${old} save
        if [ $? -ne 0 ]; then
          echo "Warning: error saving current $old rules"
        fi
      fi
    fi
  done
fi

echo
get_answer "Start/reload bastille-firewall rules?"
reload=$?
if [ $reload -eq 1 ]; then
  ${initdbase}/init.d/bastille-firewall start
fi

echo
echo "Finished $what bastille-firewall"


