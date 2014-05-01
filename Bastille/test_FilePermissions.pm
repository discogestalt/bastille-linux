# Copyright (C) 1999 - 2005 Jay Beale
# Copyright (C) 2001, 2002, 2006 Hewlett Packard Development Company L.P.
# Copyright (C) 2005, Charlie Long Delphi Research
# Licensed under the GNU General Public License, version 2


#######################################################################
##                      File Permissions Audit                       ##
#######################################################################

use Bastille::API;

#This is not an HP-UX Module, so no need to define these on HP-UX
if (&GetDistro !~ "HP-UX"){
    
##Tests for SUID and GUID
##TODO: Collapse test-definitions into a loop

$GLOBAL_TEST{'FilePermissions'}{'suidmount'} =
    sub {
	my $mount = &getGlobal('BIN','mount');
	my $umount = &getGlobal('BIN','umount');
	my $smbmount = &getGlobal('BIN','smbmnt');

	# Return NOTSECURE_CAN_CHANGE() if either mount or umount is SUID
	if (&B_is_suid($mount) or &B_is_suid($umount) or &B_is_suid($smbmount)) {
	    return NOTSECURE_CAN_CHANGE();
	    }

	return SECURE_CANT_CHANGE();
    };


$GLOBAL_TEST{'FilePermissions'}{'suidping'} =
    sub {
	my $ping = &getGlobal('BIN','ping');
	my $ping6 = &getGlobal('BIN','ping6');

	# Return NOTSECURE_CAN_CHANGE() if ping is SUID
	if (&B_is_suid($ping) or &B_is_suid($ping6)  ) {
	    return NOTSECURE_CAN_CHANGE();
	}

	return SECURE_CANT_CHANGE();
    };

$GLOBAL_TEST{'FilePermissions'}{'suiddump'} =
    sub {
	my $dump = &getGlobal('BIN','dump');
	my $restore = &getGlobal('BIN','restore');

	# Return NOTSECURE_CAN_CHANGE() if either dump or restore SUID
	if (&B_is_suid($dump) or &B_is_suid($restore)) {
	    return NOTSECURE_CAN_CHANGE();
	}

	return SECURE_CANT_CHANGE();
    };


$GLOBAL_TEST{'FilePermissions'}{'suidcard'} =
    sub {
	my $cardctl = &getGlobal('BIN','cardctl');

	# Return NOTSECURE_CAN_CHANGE() if cardctl is SUID
	if (&B_is_suid($cardctl)) {
	    return NOTSECURE_CAN_CHANGE();
	}

	return SECURE_CANT_CHANGE();
    };


# Xwrapper is a soft link to /usr/X11R6/bin/XFree86 in SUSE
#

$GLOBAL_TEST{'FilePermissions'}{'suidXwrapper'} =
    sub {
	my $Xwrapper = &getGlobal('BIN','Xwrapper');

	# Return NOTSECURE_CAN_CHANGE() if Xwrapper is SUID
	#Note: SUID status of link doesn't likely affect its operation...
	#should test underlying file
	if (&B_is_suid($Xwrapper)) {
	    return NOTSECURE_CAN_CHANGE();
	}

	return SECURE_CANT_CHANGE();
    };

$GLOBAL_TEST{'FilePermissions'}{'suidXFree86'} =
    sub {
	my $Xwrapper = &getGlobal('BIN','XFree86');

	# Return NOTSECURE_CAN_CHANGE() if XFree86 is SUID
	if (&B_is_suid($Xwrapper)) {
	    return NOTSECURE_CAN_CHANGE();
	}

	return SECURE_CANT_CHANGE();
    };

$GLOBAL_TEST{'FilePermissions'}{'suidat'} =
    sub {
	my $at = &getGlobal('BIN','at');

	# Return NOTSECURE_CAN_CHANGE() if at is SUID
	if (&B_is_suid($at)) {
	    return NOTSECURE_CAN_CHANGE();
	}

	return SECURE_CANT_CHANGE();
    };


$GLOBAL_TEST{'FilePermissions'}{'suiddos'} =
    sub {
	my $dos = &getGlobal('BIN','dos');

	# Return NOTSECURE_CAN_CHANGE() if dos is SUID
	if (&B_is_suid($dos)) {
	    return NOTSECURE_CAN_CHANGE();
	}

	return SECURE_CANT_CHANGE();
    };


$GLOBAL_TEST{'FilePermissions'}{'suidnews'} =
    sub {
	my $inndstart = &getGlobal('BIN','inndstart');
	my $startinnfeed = &getGlobal('BIN','startinnfeed');


	# Return NOTSECURE_CAN_CHANGE() if news is SUID
	if (&B_is_suid($inndstart) or &B_is_suid($startinnfeed)) {
	    return NOTSECURE_CAN_CHANGE();
	}

	return SECURE_CANT_CHANGE();
    };


$GLOBAL_TEST{'FilePermissions'}{'suidprint'} =
    sub {
	my $lpr = &getGlobal('BIN','lpr');
	my $lpq = &getGlobal('BIN','lpq');
	my $lprm = &getGlobal('BIN','lprm');

	# Return NOTSECURE_CAN_CHANGE() if either lpr, lpq or lprm is SUID
	if (&B_is_suid($lpr) or &B_is_suid($lpq) or &B_is_suid($lprm)) {
	    return NOTSECURE_CAN_CHANGE();
	}

	return SECURE_CANT_CHANGE();
    };

$GLOBAL_TEST{'FilePermissions'}{'suidrtool'} =
    sub {
	my $rcp = &getGlobal('BIN','rcp');
	my $rlogin = &getGlobal('BIN','rlogin');
	my $rsh = &getGlobal('BIN','rsh');
	my $rdist = &getGlobal('BIN','rdist');
	my $rexec = &getGlobal('BIN','rexec');

	# Return NOTSECURE_CAN_CHANGE() if either rcp, rlogin, rsh, rdist or rexec SUID
	if (&B_is_suid($rcp) or &B_is_suid($rlogin) or &B_is_suid($rsh) or &B_is_suid($rdist) or &B_is_suid($rexec) ) {
	    return NOTSECURE_CAN_CHANGE();
	}

	return SECURE_CANT_CHANGE();
    };

$GLOBAL_TEST{'FilePermissions'}{'suidusernetctl'} =
    sub {
	my $usernetctl = &getGlobal('BIN','usernetctl');

	# Return NOTSECURE_CAN_CHANGE() if usernetctl is SUID
	if (&B_is_suid($usernetctl) ) {
	    return NOTSECURE_CAN_CHANGE();
	}

	return SECURE_CANT_CHANGE();
    };

$GLOBAL_TEST{'FilePermissions'}{'suidtrace'} =
    sub {
	my $traceroute = &getGlobal('BIN','traceroute');
	my $traceroute6 = &getGlobal('BIN','traceroute6');

	# Return NOTSECURE_CAN_CHANGE() if either traceroute or traceroute6 is SUID
	if (&B_is_suid($traceroute) or &B_is_suid($traceroute6)) {
	    return NOTSECURE_CAN_CHANGE();
	}

	return SECURE_CANT_CHANGE();
    };

# Commented out since we really don't know the "state" of what the user did with
# the information we provided in the script

#$GLOBAL_TEST{'FilePermissions'}{'world_writeable'} =
#sub {
#    return &isInTODO("Writeable Directory Audit:");
#};

###############################################################################################
# These tests are for the generalperms item, which is a very, very long fixing item that
# mostly removes user access to admin-only utilities.  We don't recommend a non-zero weight
# for this item, soley because there are just so many permissions changes requires and the
# failure of a single one would fail the item.
#
# TODO: Consider whether we should give partial credit.
#
# This item was mostly generated by Jay running a custom perl script over the fixer item to
# automatically generate it.
#
# TODO: Consider rewriting script to use an array and far less code.
###############################################################################################

    
$GLOBAL_TEST{'FilePermissions'}{'generalperms_1_1'} =
    sub {
	my $distro=&GetDistro;

	unless ($distro =~ /^RH/ or $distro =~ /^MN/ or $distro =~ /^DB/ or $distro =~ /^SE/ or $distro =~ /^TB/) {
	    return SECURE_CANT_CHANGE();
	}
	else { #rwf - removed much of the duplicate code branches to improve test coverage,where
	       # there was a lot of duplicate file permissions... I left the others and the
	       # hardcoded paths...those are "TODO"

	my @Array750 = (#perm 0750
	    "/bin/mt",			    "/bin/setserial",
	    "/sbin/badblocks",		    "/sbin/ctrlaltdel",
	    "/sbin/chkconfig",		    "/sbin/debugfs",
	    "/sbin/depmod",		    "/sbin/dumpe2fs",
	    "/sbin/fdisk",		    "/sbin/fsck",
	    "/sbin/fsck.ext2",		    "/sbin/fsck.minix",
	    "/sbin/ftl_check",		    "/sbin/ftl_format",
	    "/sbin/halt",		    "/sbin/hdparm",
	    "/sbin/hwclock",		    "/sbin/ifconfig",
	    "/sbin/ifdown",		    "/sbin/ifport",
	    "/sbin/ifup",		    "/sbin/ifuser",
	    "/sbin/init",		    "/sbin/insmod",
	    "/sbin/isapnp",		    "/sbin/kerneld",
	    "/sbin/killall5",		    "/sbin/lilo",
	    "/sbin/mingetty",		    "/sbin/mkbootdisk",
	    "/sbin/mke2fs",		    "/sbin/mkfs",
	    "/sbin/mkfs.ext2",		    "/sbin/mkfs.minix",
	    "/sbin/mkfs.msdos",		    "/sbin/mkinitrd",
	    "/sbin/mkpv",		    "/sbin/mkraid",
	    "/sbin/mkswap",		    "/sbin/modinfo",
	    "/sbin/modprobe",		    "/sbin/pnpdump",
	    "/sbin/portmap",		    "/sbin/quotaon",
	    "/sbin/restore",		    "/sbin/runlevel",
	    "/sbin/stinit",		    "/sbin/swapon",
	    "/sbin/tune2fs",		    "/sbin/uugetty",
	    "/usr/bin/control-panel",	"/usr/bin/eject",
	    "/usr/bin/kernelcfg",	    "/usr/bin/minicom",
	    "/usr/bin/netcfg",		    "/usr/sbin/atd",
	    "/usr/sbin/atrun",		    "/usr/sbin/crond",
	    "/usr/sbin/dhcpd",		    "/usr/sbin/dhcrelay",
	    "/usr/sbin/edquota",	    "/usr/sbin/exportfs",
	    "/usr/sbin/groupadd",	    "/usr/sbin/groupdel",
	    "/usr/sbin/groupmod",	    "/usr/sbin/grpck",
	    "/usr/sbin/grpconv",	    "/usr/sbin/grpunconv",
	    "/usr/sbin/imapd",		    "/usr/sbin/in.comsat",
	    "/usr/sbin/in.fingerd",	    "/usr/sbin/in.identd",
	    "/usr/sbin/in.ntalkd",	    "/usr/sbin/rpc.yppasswdd",
	    "/usr/sbin/rpc.ypxfrd",	    "/usr/sbin/rpcinfo",
	    "/usr/sbin/samba",		    "/usr/sbin/setup",
	    "/usr/sbin/showmount",	    "/usr/sbin/smbd",
	    "/usr/sbin/squid",		    "/usr/sbin/syslogd",
	    "/sbin/syslogd",		    "/usr/sbin/taper",
	    "/usr/sbin/tcpd",		    "/usr/sbin/tcpdchk",
	    "/usr/sbin/tcpdmatch",	    "/usr/sbin/tcpdump",
	    "/usr/sbin/timeconfig",	    "/usr/sbin/timed",
	    "/usr/sbin/tmpwatch",	    "/usr/sbin/tunelp",
	    "/usr/sbin/useradd",	    "/usr/sbin/userdel",
	    "/usr/sbin/in.telnetd",	    "/usr/sbin/in.timed",
	    "/usr/sbin/inetd",		    "/usr/sbin/ipop2d",
	    "/usr/sbin/ipop3d",		    "/usr/sbin/klogd",
	    "/sbin/klogd",		    "/usr/sbin/logrotate",
	    "/usr/sbin/mouseconfig",	    "/usr/sbin/named",
	    "/usr/sbin/named-xfer",	    "/usr/sbin/newusers",
	    "/usr/sbin/nmbd",		    "/usr/sbin/ntpdate",
	    "/usr/sbin/ntpq",		    "/usr/sbin/ntptime",
	    "/usr/sbin/ntptrace",	    "/usr/sbin/ntsysv",
	    "/usr/sbin/pppd",		    "/usr/sbin/pwck",
	    "/usr/sbin/pwconv",		    "/usr/sbin/pwunconv",
	    "/usr/sbin/rotatelogs",	    "/usr/sbin/rpc.bootparamd",
	    "/usr/sbin/rpc.mountd",	    "/usr/sbin/rpc.nfsd",
	    "/usr/sbin/rpc.rquotad",	    "/usr/sbin/rpc.rstatd",
	    "/usr/sbin/rpc.rusersd",	    "/usr/sbin/rpc.rwalld",
	    "/usr/sbin/rpc.statd",	    "/sbin/rpc.statd",
	    "/usr/sbin/lpf",		    "/usr/sbin/rdev",
	    "/usr/sbin/usermod",	    "/usr/sbin/vipw",
	    "/usr/sbin/xntpd",		    "/usr/sbin/xntpdc",
	    );
	my @Array755 = (#perm 0755
		"/usr/bin/lpq",		"/usr/bin/lpqall.faces",
		"/usr/bin/lprm",	"/usr/bin/lptest",
		"/usr/bin/lpunlock",    "/usr/sbin/lsof"
	       );

	my @Array000 = ( #perm 0000
	    "/usr/sbin/in.rexecd",	"/usr/sbin/in.rlogind",
	    "/usr/sbin/in.rshd",	"/usr/sbin/in.tftpd"
	   );
	
	foreach my $file (@Array000) {
	    if (&B_check_permissions($file,0000)){
		return NOTSECURE_CAN_CHANGE();
	    }
	}
	foreach my $file (@Array755) {
	    if (&B_check_permissions($file,0755)){
		return NOTSECURE_CAN_CHANGE();
	    }
	}
	foreach my $file (@Array750) {
	    if (&B_check_permissions($file,0750)){
		return NOTSECURE_CAN_CHANGE();
	    }
	}

	if ( $distro =~ /^DB/ ) {
	    unless ( &B_check_permissions("/usr/bin/dpkg",0750) ) {
		return NOTSECURE_CAN_CHANGE();
	    }
	    unless ( &B_check_permissions("/usr/bin/apt-get",0750) ) {
		return NOTSECURE_CAN_CHANGE();
	    }
	}
	   # Comanche was removed from RH6.1 -- don't try to chmod if it doesn't exist
	   if ( $distro ne "RH6.0" and $distro ne "MN6.0" and $distro ne "SE7.2" and $distro ne "TB7.0") {
	       unless ( &B_check_permissions("/usr/bin/comanche",0750) ) {
	            return NOTSECURE_CAN_CHANGE();
	       }
	   }

	   # Deviate from the SANS/Trinity script here: ordinary users should
	   # not be able to start the news server.  ( Chris Owen )
	   unless ( &B_check_permissions("/usr/bin/inndstart",0500) ) {
	        return NOTSECURE_CAN_CHANGE();
	   }
	   unless ( &B_check_permissions("/usr/bin/startinnfeed",0500) ) {
	        return NOTSECURE_CAN_CHANGE();
	   }
	   unless ( &B_check_permissions("/bin/linuxconf",0700) ) {
	        return NOTSECURE_CAN_CHANGE();
	   }
	   unless ( &B_check_permissions("/usr/bin/lpr",0775) ) {
	        return NOTSECURE_CAN_CHANGE();
	   }
	   unless ( &B_check_permissions("/sbin/dump",0770) ) {
	        return NOTSECURE_CAN_CHANGE();
	   }
           unless ( &B_check_permissions("/usr/bin/lpr",0757) ) {
                return NOTSECURE_CAN_CHANGE();
           }
	   unless ( &B_check_permissions("/usr/sbin/lpd",0740) ) {
	        return NOTSECURE_CAN_CHANGE();
	   }
	   unless ( &B_check_permissions("/usr/sbin/makemap",0550) ) {
	        return NOTSECURE_CAN_CHANGE();
	   }

	   unless ( &B_check_permissions("/usr/sbin/quotastats",0550) ) {
	        return NOTSECURE_CAN_CHANGE();
	   }
	   unless ( &B_check_permissions("/usr/sbin/repquota",0550) ) {
	        return NOTSECURE_CAN_CHANGE();
	   }
	   
	   

	   unless ( &B_check_permissions("/usr/sbin/userhelper",07770) ) {
	        return NOTSECURE_CAN_CHANGE();
	   }
	   unless ( &B_check_permissions("/usr/sbin/usernetctl",07770) ) {
	        return NOTSECURE_CAN_CHANGE();
	   }
	   unless ( &B_check_permissions("/usr/sbin/usernetctl",07757) ) {
	        return NOTSECURE_CAN_CHANGE();
	   }
	   unless ( &B_check_permissions("/usr/sbin/lpc",07770) ) {
	        return NOTSECURE_CAN_CHANGE();
	   }
           unless ( &B_check_permissions("/usr/sbin/lpc",07757) ) {
                return NOTSECURE_CAN_CHANGE();
           }
	   unless ( &B_check_permissions("/usr/bin/gpasswd",07770) ) {
	        return NOTSECURE_CAN_CHANGE();
	   }
	   unless ( &B_check_permissions("/sbin/netreport",02750) ) {
	        return NOTSECURE_CAN_CHANGE();
	   }

       }

	return SECURE_CANT_CHANGE();
    };
}

1;
