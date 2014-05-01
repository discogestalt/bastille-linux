# Copyright 2003-2007 Jay Beale
# This file contains all of the Mac OS X-specific subroutines
# Licensed under the GNU General Public License, version 2


####################################################################
#
#  This module makes up the MAC OS X-specific API routines.
#  
####################################################################
#
#  Subroutine Listing:
#     &OSX_ConfigureForDistro: 	adds all used file names to global
#                             	hashes 
#
#     &B_deactivate_launchd($file) : deactivates the program started by
#                               launchd config file $file.
#
####################################################################

use Exporter;
@ISA = qw ( Exporter );
@EXPORT = qw( B_deactivate_launchd );



sub OSX_ConfigureForDistro {
    
    return;
    
    
    $GLOBAL_BIN{"md5sum"}="/usr/bin/md5sum";
    
    $GLOBAL_FILE{"sendmail.cf"}="/etc/sendmail.cf"; 
    $GLOBAL_FILE{"banners_makefile"}="/usr/share/doc/tcp_wrappers-7.6/Banners.Makefile";
	
}      


# OS X starts persistent daemons through three mechanisms.
#
# SystemStarter (/System/Library/StartupItems/*/* scripts)
# /etc/rc
# launchd ( /System/Library/LaunchDaemons items)
#
# The last of these requires that we run a command to deactivate it, mostly because launchd uses
# binary or XML files to describe each program to be run.  These files are difficult to deal with,
# so it makes sense to use launchctl, the vendor-provided interface for this.
#

##########################################################################################################
# B_deactivate_launchd($config_file) deactivates the program started by launchd config file $config_file.
#
# It does this by using the B_System API call to run launchctl, both using the standard management
# interface and providing the normal revert functionality that Bastille must support.
#
##########################################################################################################

sub B_deactivate_launchd {

    my $config_file = $_[0];

    # If there's no /System/Library/LaunchDaemons/ directory, this system isn't a launchd system, so we
    # should exit.

    my $launchdaemons_dir =  &getGlobal('DIR', 'LaunchDaemons');
    if ( ! -d $launchdaemons_dir ) {
        &B_log('ACTION',"Not trying to deactivate launchd-started item $config_file, since no $launchdaemons_dir directory exists.  This system must not use launchd.");
    }

    &B_log('ACTION',"Deactivating launchd-started item defined in $config_file");

    # If the config file doesn't exist, exit.
    if ( ! -e $config_file ) {
        return;
        &B_log('WARNING',"$config_file does not exist.  This is often not a bug, but reflects a system where a piece of software to be deactivated simply isn't installed.");
    }

    # If we can't run launchctl, exit and throw an error.
    my $launchctl = &getGlobal('FILE', 'launchctl' );
    if ( ! -x $launchctl ) {
        &B_log('ERROR',"launchctl cannot be found or is not executable.  Bastille cannot deactivate any launchd-controlled daemons, that is, any defined by a config file in /System/Library/LaunchDaemons.");

        return;
    }
    else {
        &B_System("$launchctl unload -w $config_file","$launchctl load -w $config_file");
    }

}

1;
