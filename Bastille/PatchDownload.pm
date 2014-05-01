# Copyright (C) 1999, 2000 Jay Beale
# Licensed under the GNU General Public License, version 2

package Bastille::PatchDownload;

use Bastille::API;
use Bastille::API::FileContent;

&PatchDownload;


### TO DO: Fix this!!!!!!!!!!!!1
###



#######################################################################
##                            Patch Download                         ##
#######################################################################

# Download specific RPMs from RedHat's errata list
# We get the list of which ones to download from a Bastille/SANS web
# server, so as to avoid the question: "do we download all security
# patches indiscriminately, or do we put a static list in the script,
# for safety/predictability?

# TODO: Figure out _how_ to patch the kernel...
# TODO: Figure out how to secure this interaction...

sub PatchDownload {

    if ( 0 and &getGlobalConfig("PatchDownload","patchdownload") eq "Y" ) {
	    if ( $distro =~/^RH/ ) {
		    &B_log("ACTION","# sub PatchDownload\n");

        # We download the list of RPMs to upgrade from a Bastille/SANS site, 
        # hardcoded as one of my web sites, until we get one, and then download
        # only those RPMs for which the package was already installed.

# This script does not currently have a method for verifying that the patches
# it downloads are authentic.  We download patches from a site we consider to
# be generally secure and reliable, but that's not an absolute guarantee.  For
# instance, if the RedHat web server we download from was cracked, the
# attacker could place Trojan horses or otherwise false RPMs on the site.  We
# include directions for getting these patches manually in the README.PATCH 
# file.
# You do need patches, though -- without patches, your risk of being hacked
# is soooo much higher. 

			my $version = &GetDistro;
			my $file = "Bastille" . $version . "SecurityRPMS";
			my $url = "http://bastille-linux.sourceforge.net/" . $file;

			# Don't download patches for now -- we need a good site with secure d/l
			`./webget $url`;
			&B_open(*BRHSRPMS,$file);
			while ($rpmline=<BRHSRPMS>) {
				if ($rpmline =~ /^ftp:\/\/.*\/(.*)-.*-.*\.i386\.rpm$/) {
					&B_log("ACTION","# Downloading updated rpm $rpmline\n");
					my $rpm=&getGlobal('BIN',"rpm");
					`$rpm -Fvh $rpmline`;
					&B_log("ACTION","rpm -Fvh $rpmline\n");
				}
			}

			&B_close(*BRHSRPMS);

		} elsif ( &GetDistro =~ /^DB/ ) {
			# Add security.debian.org to the /etc/apt/sources.list file and do
			# and apt-get update && apt-get upgrade

			# BEWARE: apt-get upgrade will upgrade all stuff, not just security fixed
			# that's why we need an apt-get -s (source) to a new file so that 
			#*only* has this URI and then do the upgrade with it
			# (but apt-get currently does not have a -s)
			&B_log("ACTION","# sub PatchDownload\n");
			&B_create_file("/etc/apt/bastille.sources.list");
			# BUG: This always asumes user is running stable which might not be the
			# case, we could retrieve the distribution info from the /etc/apt/sources.list 
			# But it's better to set only DB$stable in Questions.txt
			&B_append_line("/etc/apt/bastille.sources.list","^deb http://security.debian.org","deb http://security.debian.org stable/updates main contrib non-free\n");
			&B_log("ACTION","# Downloading list of latest security patches\n# This can take some minutes depending on your Internet connection\n");
			# BIG HACK: Rename, do update and upgrade and rename again
			if ( ! -e "/etc/apt/sources.list.backup") {
				`/bin/cp /etc/apt/sources.list /etc/apt/sources.list.backup`;
				`/bin/cp /etc/apt/bastille.sources.list /etc/apt/sources.list`;
				my $command = "/usr/bin/apt-get update";
				&B_log("ACTION","$command\n");
				my $ok =  0;
				if ( system($command) == 0) {
					&B_log("ACTION","# Upgrading the system with latest security patches\n");

					$command = "/usr/bin/apt-get  upgrade";
					&B_log("ACTION","$command\n");
					$ok = 1 if ( system($command) == 0) ;
				}
				`/bin/cp /etc/apt/sources.list.backup /etc/apt/sources.list`;
				`/bin/rm /etc/apt/sources.list.backup`;
				&B_log("ERROR","Bastille was unable to update your system to latest security updates.\nPlease check your Internet connection is ready and run Bastille again\n") if ! $ok;
				&B_log("ACTION","# Security upgrade successful\n") if $ok ;
			} else {
				# Cowardly refusing to continue on, since we might lose everything!
				&B_log("ERROR","Latest update seem to break in the middle!\nRestore manually your /etc/apt/sources.list from /etc/apt/sources.list.backup.");
			} # from if -f list.backup
		} # from if distro

	} else {
		# Deactivating patch downloads for now...
		print "We're not installing patches right now -- you should go and\n";
		if ( $distro =~ /^RH/ ) {
			print "download all the patches listed on Red Hat's distro page.\n\n";

			print "Please install patches manually, following directions in README.PATCH!\n";
		} elsif ( $distro =~ /^DB/ ) {
			print "download all the patches listed on Debian's security page.\n(URL: http://security.debian.org\n\n";
		} else { 
			print "check your vendor WWW site in order to see what security patches\nhave appeared after you installed this operating system\n\n";
		} #from if distro
	} # from else

}

1;






