# Copyright (C) 1999 - 2004 Jay Beale
# Copyright (C) 2001, 2002 Hewlett Packard Development Company, L.P.
# Licensed under the GNU General Public License, version 2

package Bastille::FilePermissions;
use lib "/usr/lib";
use strict;
use File::Find ();
use Bastille::API;
use Bastille::API::HPSpecific;
use Bastille::API::FileContent;
use Bastille::API::AccountPermission;


## TO DO:
#
#    1) Re-write file permissions from scratch, possibly creating a 
#       smarter chmod for the API...
#    2) Re-do the SUID audit, based on Mandrake and other distros...
#


#######################################################################
##                            File Permissions                       ##
#######################################################################

&GeneralPerms;
#&Activatelibsafe;
&SUIDAudit;
&WriteableDirAudit;

sub GeneralPerms {

   &B_log("ACTION","# sub GeneralPerms\n");

# First, we remove world read,execute,write access from some utilities
# that ordinary users shouldn't need.  

#
# Remove world read, write, execute where it's unnecessary
# This borrowed from a SANS publication, which borrowed/modified it
# from a TrinityOS script.
# 

   my $distro=&GetDistro;

   if (&getGlobalConfig("FilePermissions","generalperms_1_1") eq "Y") {

   if ($distro =~ /^RH/ or $distro =~ /^MN/ or $distro =~ /^DB/ or $distro =~ /^SE/ or $distro =~ /^TB/) {
	   &B_chmod_if_exists(0700,"/bin/linuxconf");
	   &B_chmod_if_exists(0750,"/bin/mt");
	   &B_chmod_if_exists(0750,"/bin/setserial");
	   &B_chmod_if_exists(0750,"/sbin/badblocks");
	   &B_chmod_if_exists(0750,"/sbin/ctrlaltdel");
	   &B_chmod_if_exists(0750,"/sbin/chkconfig");
	   &B_chmod_if_exists(0750,"/sbin/debugfs");
	   &B_chmod_if_exists(0750,"/sbin/depmod");
	   if ( $distro =~ /^DB/ ) {
		   &B_chmod_if_exists(0750,"/usr/bin/dpkg");
		   &B_chmod_if_exists(0750,"/usr/bin/apt-get");
	   }
	   &B_chmod_if_exists('o-rwx','/sbin/dump');
	   &B_chmod_if_exists(0750,"/sbin/dumpe2fs");
	   ####### Are there other dump___ programs to worry about?
	   &B_chmod_if_exists(0750,"/sbin/fdisk");
	   &B_chmod_if_exists(0750,"/sbin/fsck");
	   &B_chmod_if_exists(0750,"/sbin/fsck.ext2");
	   &B_chmod_if_exists(0750,"/sbin/fsck.minix");
	   &B_chmod_if_exists(0750,"/sbin/ftl_check");
	   &B_chmod_if_exists(0750,"/sbin/ftl_format");
	   &B_chmod_if_exists(0750,"/sbin/halt");
	   &B_chmod_if_exists(0750,"/sbin/hdparm");
	   &B_chmod_if_exists(0750,"/sbin/hwclock");
	   &B_chmod_if_exists(0750,"/sbin/ifconfig");
	   &B_chmod_if_exists(0750,"/sbin/ifdown");
	   &B_chmod_if_exists(0750,"/sbin/ifport");
	   &B_chmod_if_exists(0750,"/sbin/ifup");
	   &B_chmod_if_exists(0750,"/sbin/ifuser");
	   &B_chmod_if_exists(0750,"/sbin/init");
	   &B_chmod_if_exists(0750,"/sbin/insmod");
	   &B_chmod_if_exists(0750,"/sbin/isapnp");
	   &B_chmod_if_exists(0750,"/sbin/kerneld");
	   &B_chmod_if_exists(0750,"/sbin/killall5");
	   &B_chmod_if_exists(0750,"/sbin/lilo");
	   &B_chmod_if_exists(0750,"/sbin/mingetty");
	   &B_chmod_if_exists(0750,"/sbin/mkbootdisk");
	   &B_chmod_if_exists(0750,"/sbin/mke2fs");
	   &B_chmod_if_exists(0750,"/sbin/mkfs");
	   &B_chmod_if_exists(0750,"/sbin/mkfs.ext2");
	   &B_chmod_if_exists(0750,"/sbin/mkfs.minix");
	   &B_chmod_if_exists(0750,"/sbin/mkfs.msdos");
	   &B_chmod_if_exists(0750,"/sbin/mkinitrd");
	   &B_chmod_if_exists(0750,"/sbin/mkpv");
	   &B_chmod_if_exists(0750,"/sbin/mkraid");
	   &B_chmod_if_exists(0750,"/sbin/mkswap");
	   &B_chmod_if_exists(0750,"/sbin/modinfo");
	   &B_chmod_if_exists(0750,"/sbin/modprobe");
	   &B_chmod_if_exists(02750,"/sbin/netreport");

	   &B_chmod_if_exists(0750,"/sbin/pnpdump");
	   &B_chmod_if_exists(0750,"/sbin/portmap");
	   &B_chmod_if_exists(0750,"/sbin/quotaon");
	   &B_chmod_if_exists('o-rwx','/sbin/restore');
	   &B_chmod_if_exists(0750,"/sbin/runlevel");
	   &B_chmod_if_exists(0750,"/sbin/stinit");
	   &B_chmod_if_exists(0750,"/sbin/swapon");
	   &B_chmod_if_exists(0750,"/sbin/tune2fs");
	   &B_chmod_if_exists(0750,"/sbin/uugetty");
	   
	   # Comanche was removed from RH6.1 -- don't try to chmod if it doesn't exist
	   if ( $distro ne "RH6.0" and $distro ne "MN6.0" and $distro ne "SE7.2" and $distro ne "TB7.0") {
	       &B_chmod_if_exists(0750,"/usr/bin/comanche");
	   }
	   &B_chmod_if_exists(0750,"/usr/bin/control-panel");
	   &B_chmod_if_exists(0750,"/usr/bin/eject");
	   &B_chmod_if_exists('o-rwx','/usr/bin/gpasswd');
	   &B_chmod_if_exists(0750,"/usr/bin/kernelcfg");
	   
	   # Deviate from SAN/Trinity script.  Unless we create special 
	   # gnome/xwindows group, removing user access to gnome utilities 
	   # breaks things...
	   
	   # Don't modify any gnome stuff...

	   # Deviate from the SANS/Trinity script here: ordinary users should
	   # not be able to start the news server.  ( Chris Owen )
	   &B_chmod_if_exists(0500,"/usr/bin/inndstart");
	   &B_chmod_if_exists(0500,"/usr/bin/startinnfeed");
	   
	   &B_chmod_if_exists(0755,"/usr/bin/lpq");
	   &B_chmod_if_exists(0755,"/usr/bin/lpqall.faces");
	   &B_chmod_if_exists(0755,"/usr/bin/lprm");
	   &B_chmod_if_exists(0755,"/usr/bin/lptest");
	   &B_chmod_if_exists(0755,"/usr/bin/lpunlock");
	   &B_chmod_if_exists("o-w","/usr/bin/lpr");
           &B_chmod_if_exists("g-w","/usr/bin/lpr"); 

	   &B_chmod_if_exists(0750,"/usr/bin/minicom");
	   &B_chmod_if_exists(0750,"/usr/bin/netcfg");
	   
	   &B_chmod_if_exists(0750,"/usr/sbin/atd");
	   &B_chmod_if_exists(0750,"/usr/sbin/atrun");
	   &B_chmod_if_exists(0750,"/usr/sbin/crond");
	   &B_chmod_if_exists(0750,"/usr/sbin/dhcpd");
	   &B_chmod_if_exists(0750,"/usr/sbin/dhcrelay");
	   &B_chmod_if_exists(0750,"/usr/sbin/edquota");
	   &B_chmod_if_exists(0750,"/usr/sbin/exportfs");
	   &B_chmod_if_exists(0750,"/usr/sbin/groupadd");
	   &B_chmod_if_exists(0750,"/usr/sbin/groupdel");
	   &B_chmod_if_exists(0750,"/usr/sbin/groupmod");
	   &B_chmod_if_exists(0750,"/usr/sbin/grpck");
	   &B_chmod_if_exists(0750,"/usr/sbin/grpconv");
	   &B_chmod_if_exists(0750,"/usr/sbin/grpunconv");
	   &B_chmod_if_exists(0750,"/usr/sbin/imapd");
	   &B_chmod_if_exists(0750,"/usr/sbin/in.comsat");
	   &B_chmod_if_exists(0750,"/usr/sbin/in.fingerd");
	   &B_chmod_if_exists(0750,"/usr/sbin/in.identd");
	   &B_chmod_if_exists(0750,"/usr/sbin/in.ntalkd");
	   
	   # deviate from the SANS script for the in.r__d daemons -- these are 
	   # bad news!
	   &B_chmod_if_exists(0000,"/usr/sbin/in.rexecd");
	   &B_chmod_if_exists(0000,"/usr/sbin/in.rlogind");
	   &B_chmod_if_exists(0000,"/usr/sbin/in.rshd");
	   &B_chmod_if_exists(0750,"/usr/sbin/in.telnetd");
	   
	   # deviate from the SANS script -- tftpd has had serious vulnerabilities.
	   &B_chmod_if_exists(0000,"/usr/sbin/in.tftpd");
	   &B_chmod_if_exists(0750,"/usr/sbin/in.timed");
           &B_chmod_if_exists(0750,"/usr/sbin/inetd");
	   &B_chmod_if_exists(0750,"/usr/sbin/ipop2d");
	   &B_chmod_if_exists(0750,"/usr/sbin/ipop3d");
	   
	   # klogd was moved to /sbin in RH6.1, so modify the right file
	   &B_chmod_if_exists(0750,"/usr/sbin/klogd");
	   &B_chmod_if_exists(0750,"/sbin/klogd");
	   
	   &B_chmod_if_exists(0750,"/usr/sbin/logrotate");
	   #&B_chmod_if_exists(02750,"/usr/sbin/lpc");
	   &B_chmod_if_exists("o-rwx","/usr/sbin/lpc");
           &B_chmod_if_exists("g-w","/usr/sbin/lpc"); 
	   &B_chmod_if_exists(0740,"/usr/sbin/lpd");
	   &B_chmod_if_exists(0750,"/usr/sbin/lpf");
	   &B_chmod_if_exists(0755,"/usr/sbin/lsof");
	   &B_chmod_if_exists(0550,"/usr/sbin/makemap");
	   &B_chmod_if_exists(0750,"/usr/sbin/mouseconfig");
	   &B_chmod_if_exists(0750,"/usr/sbin/named");
	   &B_chmod_if_exists(0750,"/usr/sbin/named-xfer");
	   &B_chmod_if_exists(0750,"/usr/sbin/newusers");
	   &B_chmod_if_exists(0750,"/usr/sbin/nmbd");
	   &B_chmod_if_exists(0750,"/usr/sbin/ntpdate");
	   &B_chmod_if_exists(0750,"/usr/sbin/ntpq");
	   &B_chmod_if_exists(0750,"/usr/sbin/ntptime");
	   &B_chmod_if_exists(0750,"/usr/sbin/ntptrace");
	   &B_chmod_if_exists(0750,"/usr/sbin/ntsysv");
	   &B_chmod_if_exists(0750,"/usr/sbin/pppd");
	   &B_chmod_if_exists(0750,"/usr/sbin/pwck");
	   &B_chmod_if_exists(0750,"/usr/sbin/pwconv");
	   &B_chmod_if_exists(0750,"/usr/sbin/pwunconv");
	   &B_chmod_if_exists(0550,"/usr/sbin/quotastats");
	   &B_chmod_if_exists(0750,"/usr/sbin/rdev");
	   &B_chmod_if_exists(0550,"/usr/sbin/repquota");
	   &B_chmod_if_exists(0750,"/usr/sbin/rotatelogs");
	   
	   &B_chmod_if_exists(0750,"/usr/sbin/rpc.bootparamd");
	   &B_chmod_if_exists(0750,"/usr/sbin/rpc.mountd");
	   &B_chmod_if_exists(0750,"/usr/sbin/rpc.nfsd");
	   &B_chmod_if_exists(0750,"/usr/sbin/rpc.rquotad");
	   &B_chmod_if_exists(0750,"/usr/sbin/rpc.rstatd");
	   &B_chmod_if_exists(0750,"/usr/sbin/rpc.rusersd");
	   &B_chmod_if_exists(0750,"/usr/sbin/rpc.rwalld");
	   
	   # rpc.statd was moved to /sbin in RH6.1, so modify the right file 
	   
	   &B_chmod_if_exists(0750,"/usr/sbin/rpc.statd");
	   &B_chmod_if_exists(0750,"/sbin/rpc.statd");
	   
	   &B_chmod_if_exists(0750,"/usr/sbin/rpc.yppasswdd");
	   &B_chmod_if_exists(0750,"/usr/sbin/rpc.ypxfrd");
	   &B_chmod_if_exists(0750,"/usr/sbin/rpcinfo");
	   &B_chmod_if_exists(0750,"/usr/sbin/samba");
	   &B_chmod_if_exists(0750,"/usr/sbin/setup");
	   &B_chmod_if_exists(0750,"/usr/sbin/showmount");
	   &B_chmod_if_exists(0750,"/usr/sbin/smbd");
	   &B_chmod_if_exists(0750,"/usr/sbin/squid");
	   
	   # syslogd was moved to /sbin in RH6.1, so modify the right file
	   
	   &B_chmod_if_exists(0750,"/usr/sbin/syslogd");
	   &B_chmod_if_exists(0750,"/sbin/syslogd");
	   
	   &B_chmod_if_exists(0750,"/usr/sbin/taper");
	   &B_chmod_if_exists(0750,"/usr/sbin/tcpd");
	   &B_chmod_if_exists(0750,"/usr/sbin/tcpdchk");
	   &B_chmod_if_exists(0750,"/usr/sbin/tcpdmatch");
	   &B_chmod_if_exists(0750,"/usr/sbin/tcpdump");
	   &B_chmod_if_exists(0750,"/usr/sbin/timeconfig");
	   &B_chmod_if_exists(0750,"/usr/sbin/timed");
	   &B_chmod_if_exists(0750,"/usr/sbin/tmpwatch");
	   &B_chmod_if_exists(0750,"/usr/sbin/tunelp");
	   &B_chmod_if_exists(0750,"/usr/sbin/useradd");
	   &B_chmod_if_exists(0750,"/usr/sbin/userdel");
	   &B_chmod_if_exists('o-rwx','/usr/sbin/userhelper');
	   &B_chmod_if_exists(0750,"/usr/sbin/usermod");
	   &B_chmod_if_exists("o-rwx","/usr/sbin/usernetctl");
	   &B_chmod_if_exists("g-w","/usr/sbin/usernetctl");
	   &B_chmod_if_exists(0750,"/usr/sbin/vipw");
	   &B_chmod_if_exists(0750,"/usr/sbin/xntpd");
	   &B_chmod_if_exists(0750,"/usr/sbin/xntpdc");
       }
       else {
	   &B_log("ERROR","Didn't carry out general permissions modifications as they are very specific to Red Hat / Mandrake\n");
       }
   }
}


sub Activatelibsafe {

    &B_log("ACTION","# sub Activatelibsafe\n");
    
    if (&getGlobalConfig("FilePermissions","libsafe") eq "Y") {

	&B_append_line("/etc/ld.so.preload","/lib/libsafe.so.1.3\n");
	
    }
}


sub SUIDAudit {
   &B_log("ACTION","# sub SUIDAudit\n");
##
### SUID Audit / Correction
##


# First, we list all SUID ROOT programs in the Redhat 6.0 install.
# We include the full list here, at least during the development 
# cycle of this script, to 1) allow easy edits and 2) maintain an 
# easy-to-find list.  Comment lines with names of binaries, thus, are
# just listing a non-modified binary.

#/bin/login
#/bin/su
#	   

   if (&getGlobalConfig("FilePermissions","suidmount") eq "Y") {
       &B_remove_suid(&getGlobal('BIN',"mount"));
       &B_remove_suid(&getGlobal('BIN',"umount"));
       &B_remove_suid(&getGlobal('BIN',"smbmnt"));
       # these appear to be for Debian but are never defined?
       #&B_remove_suid(&getGlobal('BIN',"smbmount-2.2.x"));
       #&B_remove_suid(&getGlobal('BIN',"smbumount-2.2.x"));
       #&B_remove_suid(&getGlobal('BIN',"smbmount-2.0.x"));
       #&B_remove_suid(&getGlobal('BIN',"smbumount-2.0.x"));
   }

   if (&getGlobalConfig("FilePermissions","suidping") eq "Y") {
       &B_remove_suid(&getGlobal('BIN',"ping"));
       &B_remove_suid(&getGlobal('BIN',"ping6"));
   }
    
#/sbin/pwdb_chkpwd

   if (&getGlobalConfig("FilePermissions","suiddump") eq "Y") {
       &B_remove_suid(&getGlobal('BIN',"dump"));
       &B_remove_suid(&getGlobal('BIN',"restore"));
       if (&GetDistro =~ /^OSX/) {
	   &B_remove_suid(&getGlobal('BIN',"rdump"));
	   &B_remove_suid(&getGlobal('BIN',"rrestore"));
       }
   }

   if (&getGlobalConfig("FilePermissions","suidcard") eq "Y") {
      &B_remove_suid(&getGlobal('BIN',"cardctl"));
   }
    
   if (&getGlobalConfig("FilePermissions","suidXwrapper") eq "Y") {
       &B_remove_suid(&getGlobal('BIN',"Xwrapper"));
   }
   if (&getGlobalConfig("FilePermissions","suidXFree86") eq "Y") {
       &B_remove_suid(&getGlobal('BIN','XFree86'));
   }
    
   if (&getGlobalConfig("FilePermissions","suidat") eq "Y") {
       &B_remove_suid(&getGlobal('BIN',"at"));
       if (&GetDistro =~ /^OSX/) {
	   &B_remove_suid(&getGlobal('BIN',"atq"));
	   &B_remove_suid(&getGlobal('BIN',"atrm"));
       }
   }

#/usr/bin/crontab
#/usr/bin/chage
#/usr/bin/gpasswd
#/usr/bin/chfn
#/usr/bin/chsh
#/usr/bin/newgrp 

   if (&getGlobalConfig("FilePermissions","suiddos") eq "Y") {
       &B_remove_suid(&getGlobal('BIN',"dos"));
   }

#/usr/bin/disable-paste ---?????????

   if (&getGlobalConfig("FilePermissions","suidnews") eq "Y") {
        &B_remove_suid( &getGlobal('BIN',"inndstart"));
        &B_remove_suid( &getGlobal('BIN',"startinnfeed"));
       
   }
# Note that these files have different names on HP-UX
# lprm=cancel / lpq=lpstat / lpr=lp (lp is the suid one)
   if (&getGlobalConfig("FilePermissions","suidprint") eq "Y") {
       &B_remove_suid(&getGlobal('BIN',"lpq"));
       &B_remove_suid(&getGlobal('BIN',"lpr"));
       &B_remove_suid(&getGlobal('BIN',"lprm"));
       if (&GetDistro =~ "^HP-UX") {
	   &B_remove_suid(&getGlobal('BIN',"lpalt"));
       }	   
   }

#/usr/bin/passwd
#/usr/bin/suidperl
#/usr/bin/sperl5.00503
#/usr/bin/procmail

   if (&getGlobalConfig("FilePermissions","suidrtool") eq "Y") {
       &B_chmod_if_exists(000,&getGlobal('BIN',"rcp"));
       &B_chmod_if_exists(000,&getGlobal('BIN',"rlogin"));
       &B_chmod_if_exists(000,&getGlobal('BIN',"rsh"));
       if ( &GetDistro =~ "^HP-UX") {
	   print "DEBUG: This is an HP system?\n\n";
	   &B_chmod_if_exists(000,&getGlobal('BIN',"rdist"));
	   &B_chmod_if_exists(000,&getGlobal('BIN',"rexec"));
       }   
   }

#/usr/bin/zgv --- ????????? why does this have suid root?
#/usr/bin/ssh1

   if (&getGlobalConfig("FilePermissions","suidusernetctl") eq "Y") {
       &B_remove_suid(&getGlobal('BIN',"usernetctl"));
   }
    
#/usr/sbin/sendmail

   if (&getGlobalConfig("FilePermissions","suidtrace") eq "Y") {
       &B_remove_suid( &getGlobal('BIN',"traceroute"));
       &B_remove_suid( &getGlobal('BIN',"traceroute6"));
   }

#/usr/sbin/userhelper
#/usr/libexec/pt_chown
}


#############################################################################
#  &WriteableDirAudit;
#    This subroutine uses a perl find to generate a list of all of the
#    world writable directories for the target machine.  It then processes
#    the these permissions and bases on directory name and nesting it
#    generates a shell script with suggested values for permissions.
#
#    uses B_TODO B_append_line B_create_file B_blank_file
#############################################################################
sub WriteableDirAudit {
    &B_log("ACTION","# sub WriteableDirAudit\n");
    if (&getGlobalConfig("FilePermissions","world_writeable") eq "Y") {
# Set the variable $File::Find::dont_use_nlink if you're using AFS,
# since AFS cheats.

# for the convenience of &wanted calls, including -eval statements:
    use vars qw/*name *dir *prune/;
    *name   = *File::Find::name;
    *dir    = *File::Find::dir;
    *prune  = *File::Find::prune;
    my $strShell = ""; # Keeps all of the directories found by find.

    &B_TODO("\n---------------------------------\nWriteable Directory Audit:\n" .
	    "---------------------------------\n".
            "Bastille has created a shell script to change the permissions\n" .
            "on the world-writeable directories that it found.\n" .
	    "The shell script can be found in the following location:\n" . 
	    &getGlobal('BFILE',"directory-perms.sh") . "\n" . 
            "The script will add the \"sticky bit\" to all of the system's\n" . 
	    "world writeable directories.  This will help mitigate the\n" . 
	    "fact that directories often have to remain writeable.\n" .
            "The script will also update the internal products database \n".
	    "using the \"swmodify\" command and create another script \n".
	    "which you can use to revert the actions taken if\n" .
            "you need to.\n\n".

	    "World-writeable directories are potential vulnerabilities.\n".
	    "Examine each directories\' permissions in the shell script\n".
	    "to see if you want to leave them this way.  The permissions\n".
	    "in the script are just suggestions and should be modified to\n".
	    "meet your system\'s needs.\n\n" . 

	    "NOTE:    Do not run this UNSUPPORTED shell script without examining\n" . 
	    "         it closely.  It might break some applications and\n" .
            "         therefore should be customized to your specific needs.\n\n", #TODOFlag
            "FilePermissions.world_writeable");

    &B_create_file(&getGlobal('BFILE', "directory-perms.sh"));
    # the unmatchable regexp will insure that the file is always 
    # blanked "a$b" or 'a' endofstring 'b'
    &B_blank_file(&getGlobal('BFILE', "directory-perms.sh"),'a$b');

my $instructions = <<EOF;
# Please review the following shell script and modify it to suit the 
# needs of the system.  
#
# If you comment out a chmod, also comment out the echo
# one line below the chmod, as the echo defines the
# action to revert the chmod above.
#
# Here is a partial list of breakages to look out for if you use this script:
# 
#  - /tmp and /var/tmp sticky bit: applications which rely on unique process
# id's in /tmp when run by different users may break when the process id's
# are recycled (cleaning tmp directories regularly may alleviate this
# problem)
#
#  - Log directories (most of which are named with the word "log" in them): 
# Programs which are run by different users but create and/or write logs in
# a common directory may fail to log actions.  This includes GUI error logs
# in some versions of HP-UX diagnostic tools.
#
#  - "cat" directories such as those in /usr/share/man are used by the
# "man" command to write pre-processed man pages.  Eliminating the
# world-writeable bit will cause a degradation in performance because
# the man page will have to be reformatted every time it is accessed.
#
#  - Some directories may have incorrect owners and/or groups.  Eliminating
# world-writeable permisions on these directories have no effect if the
# owner/group is set properly.  For example, one problem with HP Openview
# running without world-writeable directories was corrected by the following:
#
#    /usr/bin/chown root:sys /var/opt/OV/analysis/ovrequestd/config
#
# This change has not been fully tested, but was shown to work when tested
# in a limited, single-purpose environment.
#
#  - Change the directory /var/obam/translated may have an impact on non-root
# users viewing help in obam (the GUI library used by swinstall, SAM,
# older versions of ServiceControl Manager, and others)
#
#  - Eliminating the world-writeable permissions on socket directories has been
# shown to stop the X server from operating properly.  However, setting the 
# sticky bit instead (what this script will do by default) did not have the 
# same effects.
#
#  - There are several other directories which have world-writeable permissions.
# Some of these are shipped with HP-UX, others are shipped with 3rd party
# products, and others may have been created by users without an appropriate
# umask set.  Bastille will help you find those directories so that you can
# make appropriate decisions for your environment.  The full impact of making
# these changes has not been analyzed.
#
# As you run the script, it will create a "revert-directory-perms.sh"
# script which will allow you to revert to a supported state (independent of
# the rest of the HP-UX Bastille configurations, which are supported). 
#
# Because of the potential for very subtle breakages, you should also keep
# a record of any changes which you make manually to your system so that
# you can revert them to help debug any problems which you run into.
# Running 'bastille -r' will revert all bastille changes, including
# running the revert-directory-perms.sh script, but it may not revert
# changes you have made manually.
#
# Comment out the following line if you accept that these changes are not
# supported by HP, you have customized the rest of the script for your
# needs, and you wish to make the changes to your system.
echo "The changes made by this script are NOT supported by HP.\nChanging the permissions of directories in this way has the potential to break\ncompatibility with some applications and requires testing in your environment.\nTherefore, the script must be customized before running.\nExiting script without taking any action."; exit 1
#
EOF

    &B_append_line(&getGlobal('BFILE', "directory-perms.sh"),"0",
                   $instructions .
                   "# Location of the revert directory permissions script (to be run by \n" .
                   "# Bastille's revert.)\n" .
                   "REVERTPERMS=" . &getGlobal('BFILE',"revert-directory-perms.sh") . "\n\n");


    my @rwx = qw(--- --x -w- -wx r-- r-x rw- rwx);
    my @moname = qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec);
    my (%uid, %user);
    while (my ($name, $pw, $uid) = getpwent) {
	$user{$uid} = $name unless exists $user{$uid};
    }
    my (%gid, %group);
    while (my ($name, $pw, $gid) = getgrent) {
	$group{$gid} = $name unless exists $group{$gid};
    }
# Traverse desired filesystems
  File::Find::find({wanted => \&wanted}, '/');
    
    sub wanted {
	my ($dev,$ino,$mode,$nlink,$uid,$gid);
	
	(($dev,$ino,$mode,$nlink,$uid,$gid) = lstat($_)) &&
	    ! ($dev >= 0) &&
		($File::Find::prune = 1)
		    ||
			((($mode & 01000) == 00000) && (($mode & 02) == 02)) && -d _ && &ls;
    }

sub sizemm {
    my $rdev = shift;
    sprintf("%3d, %3d", ($rdev >> 8) & 0xff, $rdev & 0xff);
}

sub ls {
    my ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,
        $atime,$mtime,$ctime,$blksize,$blocks) = lstat(_);
    my $pname = $name;
    
    $blocks
        or $blocks = int(($size + 1023) / 1024);
    my $newperm = "";
    my $oldperm = "";
    my $perms = "";

    $newperm = ($mode & 7);
    $oldperm = ($mode & 7);
    $perms = $rwx[$mode & 7];
    $mode >>= 3;
    
    $newperm = ($mode & 7) . $newperm;
    $oldperm = ($mode & 7) . $oldperm;
    $perms = $rwx[$mode & 7] . $perms;
    $mode >>= 3;
    
    $newperm = ($mode & 7) . $newperm;
    $oldperm = ($mode & 7) . $oldperm;
    $perms = $rwx[$mode & 7] . $perms;
    $mode >>= 3;
    
    $newperm = (($mode & 7)+1) . $newperm;
    $oldperm = ($mode & 7) . $oldperm;

    
    substr($perms, 2, 1) =~ tr/-x/Ss/ if -u _;
    substr($perms, 5, 1) =~ tr/-x/Ss/ if -g _;
    substr($perms, 8, 1) =~ tr/-x/Tt/ if -k _;
    if    (-f _) { $perms = '-' . $perms; }
    elsif (-d _) { $perms = 'd' . $perms; }
    elsif (-l _) { $perms = 'l' . $perms; $pname .= ' -> ' . readlink($_); }
    elsif (-c _) { $perms = 'c' . $perms; $size = sizemm($rdev); }
    elsif (-b _) { $perms = 'b' . $perms; $size = sizemm($rdev); }
    elsif (-p _) { $perms = 'p' . $perms; }
    elsif (-S _) { $perms = 's' . $perms; }
    else         { $perms = '?' . $perms; }
    
    my $user = $user{$uid} || $uid;
    my $group = $group{$gid} || $gid;
    my ($sec,$min,$hour,$mday,$mon,$timeyear) = localtime($mtime);
    if (-M _ > 365.25 / 2) {
        $timeyear += 1900;
    } else {
        $timeyear = sprintf("%02d:%02d", $hour, $min);
    }
    my $swString = "";
    my $shSafePname = $pname;
 
    $shSafePname =~ s/([\"\`\$\\])/\\$1/g;
    # The IPD allows directories to be defined as /dir or /dir/ 
    # so a check for either is appropriate.
    if(defined &getGlobalSwlist("$pname")){
	# defining additional swmodify command if directory is in IPD.
	my @products = @{ &getGlobalSwlist("$pname")};
	foreach my $product (@products) {
	    $swString .= " ; " . &getGlobal('BIN',"swmodify") . " -x files=\"${shSafePname}\" " . $product;
	}
    } # dangleing / case
    elsif(defined &getGlobalSwlist("${pname}\/")) {
        # defining additional swmodify command if directory is in IPD.
	my @products = @{ &getGlobalSwlist("${pname}\/")};
	foreach my $product (@products) {
	    $swString .= " ; " . &getGlobal('BIN',"swmodify") . " -x files=\"${shSafePname}\/\" " . $product;
	}
    }
   
    # Generating WORLD WRITEABLE DIR shell commands for directory-perms.sh
    my $echoSafeRevert = &getGlobal('BIN', "chmod") . " $oldperm \"$shSafePname\"" . $swString;

    # if our distro matches HP-UX then we need a layer of escapes for System 5 echo
    if( &GetDistro =~ "^HP-UX") {
	$echoSafeRevert =~ s/([\\])/\\$1/g;
    }

    # add second level of escaping for posix shell
    $echoSafeRevert =~ s/([\"\`\$\\])/\\$1/g;

    $strShell .= "# $perms   $user   $group   $moname[$mon]   $mday   " . 
            "$timeyear   $shSafePname \n" . 
	     &getGlobal('BIN', "chmod") . " $newperm \"$shSafePname\"" . $swString .
	     "\n" . "echo" . " \"$echoSafeRevert\" >> " .  '$REVERTPERMS' . "\n\n";
    
} # ls subroutine

# This section prepends revert-directory-perms.sh to the revert-actions file.
# revert-directory-perms is generated by directory-perms.sh and unmakes the
# script's permission changes.
$strShell .= "# Editing Bastille's revert scripts to include permissions changes\n# PLEASE DO NOT EDIT BELOW\n" . 
    &getGlobal('BIN',"mv") . " " . &getGlobal('BFILE',"revert-actions") .
    " " . &getGlobal('BFILE',"revert-actions") . ".bastille\n" .
    &getGlobal('BIN',"echo") . " \"" . &getGlobal('BFILE',"revert-directory-perms.sh") .
    "\" > " .  &getGlobal('BFILE',"revert-actions") . "\n" . 
    &getGlobal('BIN',"echo") . " \"" . &getGlobal('BIN',"mv") . " " .
    &getGlobal('BFILE',"revert-directory-perms.sh") . " " . &getGlobal('BFILE',"revert-directory-perms.sh") .
    ".last\" >> " .  &getGlobal('BFILE',"revert-actions") . "\n" . 
    &getGlobal('BIN',"echo") . " \"" . &getGlobal('BIN',"chmod") . " 500 " .
    &getGlobal('BFILE',"revert-directory-perms.sh") . ".last\" >> " .  
    &getGlobal('BFILE',"revert-actions") . "\n" . 
    &getGlobal('BIN',"cat") . " " .  &getGlobal('BFILE',"revert-actions") . ".bastille" .
    " >>" .  &getGlobal('BFILE',"revert-actions") . "\n" .
    &getGlobal('BIN',"rm") . " " .  &getGlobal('BFILE',"revert-actions") . ".bastille\n" .
    &getGlobal('BIN',"chown") . " root:sys " .  &getGlobal('BFILE',"revert-actions") . "\n" .
    &getGlobal('BIN',"chmod") . " 0500 " .  &getGlobal('BFILE',"revert-actions") . "\n" .
    &getGlobal('BIN',"chown") . " root:sys " .  &getGlobal('BFILE',"revert-directory-perms.sh") . "\n" .
    &getGlobal('BIN',"chmod") . " 0500 " .  &getGlobal('BFILE',"revert-directory-perms.sh") . "\n";
   &B_append_line(&getGlobal('BFILE', "directory-perms.sh"),"0",$strShell);

   } # if question is yes
} # End Audit Subroutine

1;
