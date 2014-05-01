# Copyright (C) 1999, 2000 Jay Beale
# Licensed under the GNU General Public License, version 2

package Bastille::RemoteAccess;
use lib "/usr/lib";

use Bastille::API;
use Bastille::API::FileContent;

@ENV="";
$ENV{PATH}="";
$ENV{CDPATH}=".";
$ENV{BASH_ENV}="";

#######################################################################
##                            Remote Access                          ##
#######################################################################

# Install and Configure ssh
&InstallSSH;


sub InstallSSH {
    
    # install and configure ssh -- use the configuration file from the LASG
    
    if ( &getGlobalConfig("RemoteAccess","installssh") eq "Y") {

	&B_log("ACTION","# sub InstallSSH\n");
	
	print "Downloading ssh...\n";
	&B_log("ACTION","Downloaded ssh via rpm.\n");

        my $rpm = &getGlobal('BIN',"rpm");
	`$rpm --quiet -i ftp://ftp.zedz.net/pub/crypto/linux/redhat/i386/ssh-1.2.27-7us.i386.rpm`;
	`$rpm --quiet -i ftp://ftp.zedz.net/pub/crypto/linux/redhat/i386/ssh-clients-1.2.27-7us.i386.rpm`;
	`$rpm --quiet -i ftp://ftp.zedz.net/pub/crypto/linux/redhat/i386/ssh-server-1.2.27-7us.i386.rpm`;
	print "Finished downloading ssh.\n";

	my $kurt_lines = <<END_KURT;
# Bastille Linux sshd_config file (Kurt Seifried's LASG Config)
      
Port 22
# runs on port 22, the standard
ListenAddress 0.0.0.0
# listens to all interfaces, you might only want to bind a firewall
# internally, etc
HostKey /etc/ssh/ssh_host_key
# where the host key is
RandomSeed /etc/ssh/ssh_random_seed
# where the random seed is
ServerKeyBits 768
# how long the server key is
LoginGraceTime 300
# how long they get to punch their credentials in
KeyRegenerationInterval 3600
# how often the server key gets regenerated 
PermitRootLogin no
# permit root to login? no
IgnoreRhosts yes
# ignore .rhosts files in users dir? yes
StrictModes yes
# ensures users don't do silly things
QuietMode no
# if yes it doesn't log anything. yikes. we want to log logins/etc.
X11Forwarding no
# forward X11? shouldn't have to on a server
FascistLogging no
# maybe we don't want to log too much.
PrintMotd yes
# print the message of the day? always nice
KeepAlive yes
# ensures sessions will be properly disconnected
SyslogFacility DAEMON
#  who's doing the logging?
RhostsAuthentication no
# allow rhosts to be used for authentication? the default is no
# but nice to say it anyways
RhostsRSAAuthentication no
# is authentication using rhosts or /etc/hosts.equiv sufficient
# not in my mind. the default is yes so lets turn it off. 
RSAAuthentication yes
# allow pure RSA authentication? this one is pretty safe
PasswordAuthentication yes
# allow users to use their normal login/passwd? why not?
PermitEmptyPasswords no
# permit accounts with empty password to log in? no

END_KURT



	&B_blank_file ("/etc/ssh/sshd_config");
	&B_append_line ("/etc/ssh/sshd_config","Kurt Seifried", $kurt_lines );


    }
}

1;

