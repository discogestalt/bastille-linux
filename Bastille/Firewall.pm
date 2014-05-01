# Copyright (C) 1999 - 2001 Jay Beale
# assisted by Peter Watkins
# Licensed under the GNU General Public License, version 2

#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program; if not, write to the Free Software
#    Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

#
# NOTE   : This module is a stand-in for a more featureful model that uses all
#          the functionality of Peter's new firewall script.  Basically, this
#          doesn't handle dhcp-type connections nearly as well.  This is JJB's
#          temporary stand-in for a more featureful version...
#

package Bastille::Firewall;

use Bastille::API;
use Bastille::API::FileContent;
use Bastille::API::ServiceAdmin;
use Bastille::API::AccountPermission;

@ENV="";
undef(%ENV);
$ENV{PATH}="";
$ENV{CDPATH}=".";
$ENV{BASH_ENV}="";

# @ipchainsOptions contains information about the variables this script sets the value of
# in the final firewall script. Each item in @ipchainsOptions is a hash describing a certain
# environment variable. 
#
# Each such hash should have the following name-value pairs:
#	varname		the actual variable name for the /bin/sh firewall script
#	default		the default/suggested value for that variable (in case nothing in the config)
#	stanza		where this is used in the template script
#	configname	the name for the user's choice for this question, as read
#			from the "config" script


@ipchainsOptions = (

	{
	'varname' => "DNS_SERVERS",
	'default' => "",
	'stanza' => "0",
	'configname' => 'ip_s_dns',
	},

	{
	'varname' => "TRUSTED_IFACES",
	'default' => "lo",
	'stanza' => "1",
	'configname' => 'ip_s_trustiface',
	},

	{
	'varname' => "PUBLIC_IFACES",
	'default' => "eth+ ppp+",
	'stanza' => "1",
	'configname' => 'ip_s_publiciface',
	},

	{
	'varname' => "INTERNAL_IFACES",
	'default' => "",
	'stanza' => "1",
	'configname' => 'ip_s_internaliface',
	},

	{
	'varname' => "TCP_AUDIT_SERVICES",
	'default' => "telnet ftp imap pop3 finger sunrpc exec login ssh",
	'stanza' => "2",
	'configname' => 'ip_s_tcpaudit',
	},

	{
	'varname' => "UDP_AUDIT_SERVICES",
	'default' => "31337",
	'stanza' => "2",
	'configname' => 'ip_s_udpaudit',
	},

	{
	'varname' => "ICMP_AUDIT_TYPES",
	'default' => "",
	'stanza' => "2",
	'configname' => 'ip_s_icmpaudit',
	},

	{
	'varname' => "TCP_PUBLIC_SERVICES",
	'default' => "",
	'stanza' => "3",
	'configname' => 'ip_s_publictcp',
	},

	{
	'varname' => "UDP_PUBLIC_SERVICES",
	'default' => "",
	'stanza' => "3",
	'configname' => 'ip_s_publicudp',
	},

	{
	'varname' => "TCP_INTERNAL_SERVICES",
	'default' => "",
	'stanza' => "3",
	'configname' => 'ip_s_internaltcp',
	},

	{
	'varname' => "UDP_INTERNAL_SERVICES",
	'default' => "",
	'stanza' => "3",
	'configname' => 'ip_s_internaludp',
	},

	{
	'varname' => "FORCE_PASV_FTP",
	'default' => "N",
	'stanza' => "4",
	'configname' => 'ip_s_passiveftp',
	},

	{
	'varname' => "TCP_BLOCKED_SERVICES",
	'default' => "6000:6020",
	'stanza' => "5",
	'configname' => 'ip_s_tcpblock',
	},

	{
	'varname' => "UDP_BLOCKED_SERVICES",
	'default' => "",
	'stanza' => "5",
	'configname' => 'ip_s_udpblock',
	},

	{
	'varname' => "ICMP_ALLOWED_TYPES",
	'default' => "destination-unreachable echo-reply time-exceeded",
	'stanza' => "5",
	'configname' => 'ip_s_icmpallowed',
	},

	{
	'varname' => "ENABLE_SRC_ADDR_VERIFY",
	'default' => "Y",
	'stanza' => "6",
	'configname' => 'ip_s_srcaddr',
	},

	{
	'varname' => "IP_MASQ_NETWORK",
	'default' => "",
	'stanza' => "7",
	'configname' => 'ip_s_ipmasq',
	},

	{
	'varname' => "IP_MASQ_MODULES",
	'default' => "ftp raudio vdolive",
	'stanza' => "7",
	'configname' => 'ip_s_kernelmasq',
	},

	{
	'varname' => "REJECT_METHOD",
	'default' => "DENY",
	'stanza' => "8",
	'configname' => 'ip_s_rejectmethod',
	},

	{
	'varname' => "DHCP_IFACES",
	'default' => "",
	'stanza' => "9",
	'configname' => 'ip_s_dhcpiface',
	},

	{
	'varname' => "NTP_SERVERS",
	'default' => "",
	'stanza' => "10",
	'configname' => 'ip_s_ntpsrv',
	},

	{
	'varname' => "ICMP_OUTBOUND_DISABLED_TYPES",
	'default' => "destination-unreachable time-exceeded",
	'stanza' => "11",
	'configname' => 'ip_s_icmpout',
	},

	);

# JJB's fix -- get this to work when they choose the ip_b_ questions instead.

if ( &getGlobalConfig("Firewall",ip_advnetwork) eq "N" ) {
    
    for (my $loop=0; $loop < scalar(@ipchainsOptions) ; ++$loop) {
	if ( $ipchainsOptions[$loop]{configname} =~ /^ip_s_(.*)$/ ) {
	    $ipchainsOptions[$loop]{configname} = "ip_b_" . $1;
	}
    }
}

# This is where the code uses Jay's subroutine, temporarily, to get this out the door faster...

&InstallScript_simpler;


sub ipchainsAddNetmask {
	# adds netmask info to plain dotted-quad IP addresses
	my ( $phrase ) = @_;
	if ( $phrase =~ /^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$/ ) {
		# looks like a plain IPv4 dot-quad address
		if ( $phrase eq '0.0.0.0' ) {
			$phrase .= '/0.0.0.0';
		} elsif ( $phrase =~ /\.0\.0\.0$/ ) {
			$phrase .= '/255.0.0.0';
		} elsif ( $phrase =~ /\.0\.0$/ ) {
			$phrase .= '/255.255.0.0';
		} elsif ( $phrase =~ /\.0$/ ) {
			$phrase .= '/255.255.255.0';
		} else {
			$phrase .= '/255.255.255.255';
		}
	} 
	return $phrase;
}

sub ipchainsCleanItemList {
	# removes spaces, cleans up whitespace in string
	my ( $list ) = @_;
	my ( @items, $one );
	$list =~ s/\,/ /g;
	$list =~ s/[^a-zA-Z0-9\-\_\s\.\:\+\/]//eg;	# remove unexpected chars
	$list =~ s/[\n\r\t]/ /g;
	while ( $list =~ /  / ) { $list =~ s/  / /g;}
	@items = split(/ /, $list);
	$list = '';
	foreach $one ( @items ) {
		$list .= ' '.&ipchainsAddNetmask($one);
	}
	$list =~ s/^.//;
	return $list;
}

sub InstallScript_simpler {

    # This is JJB's (possibly temporary) modification to Firewall.pm to port to 1.1 architecture.

    my (@varArray,$loop);

    my $configPrefix="Firewall";

    my $firewall_init_script = &getGlobal('DIR', "initd") . "/bastille-firewall";
    my $virgin_init_script = "/bastille-firewall";

    my $firewall_ipchains_script = '/sbin/bastille-ipchains';
    my $virgin_ipchains_script = '/bastille-ipchains';

    my $firewall_netfilter_script = '/sbin/bastille-netfilter';
    my $virgin_netfilter_script = '/bastille-netfilter';

    my $firewall_config_file = '/etc/Bastille/bastille-firewall.cfg';
    my $virgin_config_file = '/bastille-firewall.cfg';

    my $firewall_early_file = '/etc/Bastille/bastille-firewall-early.sh';
    my $virgin_early_file = '/bastille-firewall-early.sh';

    # only do this if the user answered ipchains questions
    if ( &getGlobalConfig($configPrefix,"ip_intro") eq 'Y' ) {

	# Put the init script in place.
	&B_place($virgin_init_script,$firewall_init_script);
	&B_chmod(0500,$firewall_init_script);

	# Put the ipchains script in place.
	&B_place($virgin_ipchains_script,$firewall_ipchains_script);
	&B_chmod(0500,$firewall_ipchains_script);
	
	# Put the netfilter script in place.
	&B_place($virgin_netfilter_script,$firewall_netfilter_script);
	&B_chmod(0500,$firewall_netfilter_script);
	
	# Put the default firewall config script in place.
	&B_place($virgin_config_file,$firewall_config_file);
	&B_chmod(0600,$firewall_config_file);
	
	# Put the default "early" file in place
	if ( -e '/usr/share/Bastille'.$virgin_early_file ) {
		&B_place($virgin_early_file,$firewall_early_file);
		&B_chmod(0600,$firewall_early_file);
	}
	
	# Now, iterate through the answers filling in the script...
	for ($loop=0; $loop < scalar(@ipchainsOptions); ++$loop) {
	    
	    # Build the @varArray to hold text to be inserted.
	    
            # put in the defaults if the config option isn't defined
	    my $ans = &getGlobalConfig($configPrefix, 
                                       $ipchainsOptions[$loop]{configname});
            if (not defined $ans) {
               $ans=$ipchainsOptions[$loop]{default};
            }

	    $ans = &ipchainsCleanItemList($ans);
	    my $variable = $ipchainsOptions[$loop]{varname};
	    my $assignment = $variable . "=\"$ans\"\n";

	    my $pattern = '^' . $variable . '\s*=';
	    &B_replace_line($firewall_config_file,$pattern,$assignment);
	    
	} 

	# Place the bastille-firewall-schedule file
	my $placed_file = &getGlobal('DIR', "sbin") . "/bastille-firewall-schedule";
	my $orig_file = "/bastille-firewall-schedule";
	
	unless ( -e $placed_file ) {
	    &B_place($orig_file,$placed_file);
	    &B_chmod(0500,$placed_file);
	}
	
	
	# Place the bastille-firewall-reset file
	my $placed_file = &getGlobal('DIR', "sbin") . "/bastille-firewall-reset";
	my $orig_file = "/bastille-firewall-reset";
	
	unless ( -e $placed_file ) {
	    &B_place($orig_file,$placed_file);
	    &B_chmod(0500,$placed_file);
	}
	# Do we need to edit this to find bastille-firewall?
	if ( &getGlobal('DIR', "initd") ne '/etc/rc.d/init.d' ) {
	    B_replace_line (&getGlobal('DIR', "sbin") . "/bastille-firewall-reset",'^INITBASEDIR=/etc/rc.d/init.d',"INITBASEDIR=".&getGlobal('DIR', "initd")."\n");
	}

	if ( (&GetDistro =~ /^RH/) || (&GetDistro =~ /^MN/) || (&GetDistro =~ /^SE/) || (&GetDistro =~ /^TB/)) {
	
	    my $ifup_file = &getGlobal('DIR', "sbin") . "/ifup-local";
	    
	    if ( ( -e $ifup_file ) and ( ! -e $ifup_file . ".pre-bastille")) {
		
		# no pre-bastille yet; see if the current ifup-local
		# script is ours
		$looksLikeOurs = 0;
		&B_open(*IFUP_CURRENT,$ifup_file);
		while ($line=<IFUP_CURRENT>) {
		    if ( $line =~ /\/sbin\/bastille\-firewall\-reset/ ) {
			# it looks like our script, no need
			# to make a pre-bastille copy
			$looksLikeOurs = 1;
		    }
		}
		&B_close(*IFUP_CURRENT);
		if ( $looksLikeOurs == 0 ) {
		    # make copy of current ifup-local script that our 
		    # ifup-local script will call
		    # ACK! I _hate_ "unless ( ... )". Why can't folks use "if (! ...)" ???
		    # Gee, Larry, let's make another function that's Perl-specific. Gag!
		    &B_cp($ifup_file,$ifup_file . ".pre-bastille");
#		&B_blank_file($ifup_file);
		    &B_place("/ifup-local",$ifup_file);
		    &B_chmod(0500,$ifup_file);
		}
	    }
	    
	    if ( ! -e $ifup_file ) {
		&B_place("/ifup-local",$ifup_file);
		&B_chmod(0500,$ifup_file);
	    }
	    
	    if ( &getGlobalConfig($configPrefix,"ip_enable_firewall") eq 'Y' ) {
		# run the firewall and enable it with chkconfig
#               #GLOBAL_PREFIX hasn't worked for a long time, but we'll leave the logic in comments
#               #for now.
#		if ( $GLOBAL_PREFIX eq '' ) {
		    &B_log("ACTION","# Firewall.pm: invoking firewall\n");
		    if ( ! (-x $firewall_init_script) ) {
			&B_log("ERROR","# Firewall.pm: \"$firewall_init_script\" not executable\n");
		    } else {
			`$firewall_init_script start`;
			if ( $? ne 0 ) {
			    &B_log("ERROR","# Firewall.pm: error $? invoking \"$firewall_init_script\"\n");
			} else {
			    # since it started OK, lets' enable it at boot time
			    &B_log("ACTION","# Firewall.pm: enabling firewall with B_chkconfig_on\n");
			    &B_chkconfig_on("bastille-firewall");
			}
		    } # firewall is executable
#		} else {
#		    # we're chroot'ed; shouldn't run script, but should
#		    # enable it
#		    &B_log("ACTION","# Firewall.pm: enabling firewall inside $GLOBAL_PREFIX with B_chkconfig_on\n");
#		    &B_chkconfig_on("bastille-firewall");
#		}
	    }
	    
	}
    }
    # end of things to do if ipchains was chosen
    if ( &getGlobalConfig($configPrefix,"ip_intro") eq 'N' ) {
	    # user did not answer ipchains questions
	    # we should probably do some work to revert the ipchains 
	    # filter if it had previously been installed
	    #if ( $GLOBAL_PREFIX eq '' ) {
		&B_log("ACTION","# Firewall.pm: shutting down firewall\n");
		if ( -x $firewall_init_script ) {
		    `$firewall_init_script stop`;
		}
	    #}
            # This looks like it was broken...shouldn't there be an else here? -hpbuck, 1/3/2003
            # I'm commenting it out because GLOBAL_PREFIX is broken and shouldn't be relied upon.
	    # we're chroot'ed; shouldn't run script, but should
	    # enable it
	    #&B_log("ACTION","# Firewall.pm: disabling firewall inside $GLOBAL_PREFIX with B_chkconfig_off\n");
	    &B_chkconfig_off("bastille-firewall");
    }
}
    
1;

