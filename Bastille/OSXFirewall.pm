# Copyright (C) 2006 Jay Beale
# Licensed under the GNU General Public License

package Bastille::OSXFirewall;
use lib "/usr/lib";

use Bastille::API;

use Bastille::API::FileContent;


#######################################################################
##                             OS X Firewall                         ##
#######################################################################

&OSXFirewallTiger;

sub OSXFirewallTiger {

    # This is only for OS X.
    if (&GetDistro !~ /^OSX/) {
	return 0;
    }

    if (&getGlobalConfig("OSXFirewall","fixosxfirewall") eq "Y") {
	&B_log("ACTION","# sub OSXFirewallTiger\n");

	my $close_off_bonjour = &getGlobalConfig("OSXFirewall","osxfirewallbonjour");
	my $tcp_ports = &getGlobalConfig("OSXFirewall","osxfirewalltcp");
        my $udp_ports = &getGlobalConfig("OSXFirewall","osxfirewalludp");

	mkdir "/Library/StartupItems/Firewall",0700;
	mkdir "/Library/StartupItems/Firewall/Resources",0700;
        mkdir "/Library/StartupItems/Firewall/Resources/English.lproj/",0700;

	&B_place("/StartupParameters.plist","/Library/StartupItems/Firewall/");
	#&B_place("/Firewall","/Library/StartupItems/Firewall/");
        &B_place("/Localizable.strings","/Library/StartupItems/Firewall/Resources/English.lproj/");
   
	# Now build the firewall script.
 	&B_create_file("/Library/StartupItems/Firewall/Firewall");
        &B_blank_file("/Library/StartupItems/Firewall/Firewall","^------");

        &B_append_line("/Library/StartupItems/Firewall/Firewall","Bastille","#!/bin/sh\n");
        &B_append_line("/Library/StartupItems/Firewall/Firewall","Bastille","echo Activating custom firewall\n");

	my $line = "
ipfw 'add 02000 allow ip from any to any via lo*'
ipfw add 02010 deny ip from 127.0.0.0/8 to any in
ipfw add 02020 deny ip from any to 127.0.0.0/8 in
ipfw add 02030 deny ip from 224.0.0.0/3 to any in
ipfw add 02040 deny tcp from any to 224.0.0.0/3 in
ipfw add 02050 allow tcp from any to any out
ipfw add 02060 allow tcp from any to any established
";
	&B_append_line("/Library/StartupItems/Firewall/Firewall",".*Bastille.*",$line);

	# Add TCP rules starting with line number 02100, parsing from $tcp_ports

	my @tcp_ports = split /\s+/,$tcp_ports;
        my @udp_ports = split /\s+/,$udp_ports;

	my $line_number = 02100;
;
	for $port (@tcp_ports) {
	    &B_append_line("/Library/StartupItems/Firewall/Firewall","Bastille","ipfw add $line_number allow tcp from any to any dst-port $port in\n");
	    $line_number++;
        }

	# Add TCP and ICMP default deny rules
	$line = "
ipfw add 12190 deny log tcp from any to any
ipfw add 20000 deny log icmp from any to me in\n";
	&B_append_line("/Library/StartupItems/Firewall/Firewall","Bastille",$line);

	# Add Bonjour
        if ( $close_off_bonjour eq "N" ) {
            &B_append_line("/Library/StartupItems/Firewall/Firewall","Bastille","ipfw add 20370 allow udp from any to any dst-port 5353 in\n");
            &B_append_line("/Library/StartupItems/Firewall/Firewall","Bastille","ipfw add 20350 allow udp from any to any dst-port 427 in\n");
        } 

        # Add DHCP client - buggy line?!
        &B_append_line("/Library/StartupItems/Firewall/Firewall","Bastille","ipfw add 20320 allow udp from any 67 to any dst-port 68 in\n");

	# Add UDP state keeping rules 
	$line = "
ipfw add 30510 allow udp from me to any out keep-state
ipfw add 30520 allow udp from any to any in frag
";
	&B_append_line("/Library/StartupItems/Firewall/Firewall","Bastille",$line);
	
	$line_number = 31000;
        for $port (@udp_ports) {
            &B_append_line("/Library/StartupItems/Firewall/Firewall","Bastille","ipfw add $line_number allow udp from any to any dst-port $port in\n");
            $line_number++;
        }

	# Add final default deny rules
	$line = "	
ipfw add 35000 deny log udp from any to any in
ipfw add 35010 deny log icmp from any to any in
ipfw add 65535 allow ip from any to any
";
	&B_append_line("/Library/StartupItems/Firewall/Firewall","Bastille",$line);

	# Now end the firewall
        &B_append_line("/Library/StartupItems/Firewall/Firewall","Bastille","# End of Bastille Firewall\n");
    }
}

1;

