# Copyright (C) 1999 - 2001 Jay Beale
# assisted by Michael Rash
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
# NOTE   : This module is a first attempt at having a Bastille-friendly
#      installer for psad.
#

package Bastille::PSAD;
use lib '/usr/lib';

use Bastille::API;
use Bastille::API::ServiceAdmin;
use Bastille::API::FileContent;

@ENV='';
undef(%ENV);
$ENV{'PATH'}='';
$ENV{'CDPATH'}='.';
$ENV{'BASH_ENV'}='';

# @psadOptions contains information about the variables this script sets the value of
# in the final psad script. Each item in @psadOptions is a hash describing a certain
# environment variable. 
#
# Each such hash should have the following name-value pairs:
#   varname     the actual variable name for the psad perl script
#   default     the default/suggested value for that variable (in case nothing in the config)
#   configname  the name for the user's choice for this question, as read
#           from the "config" script


@psadOptions = (

    {
    'varname' => 'PSAD_CHECK_INTERVAL',
    'default' => 15,
    'configname' => 'psad_check_interval',
    },

    {
    'varname' => 'PORT_RANGE_SCAN_THRESHOLD',
    'default' => 1,
    'configname' => 'psad_port_range_scan_threshold',
    },

    {
    'varname' => 'ENABLE_PERSISTENCE',
    'default' => 'N',
    'configname' => 'psad_enable_persistence',
    },

    {
    'varname' => 'SCAN_TIMEOUT',
    'default' => 3600,
    'configname' => 'psad_scan_timeout',
    },

    {
    'varname' => 'SHOW_ALL_SIGNATURES',
    'default' => 'N',
    'configname' => 'psad_show_all_signatures',
    },

    {
    'varname' => 'DANGER_LEVELS',
    'default' => '5 50 1000 5000 10000',
    'configname' => 'psad_danger_levels',
    },

    {
    'varname' => 'EMAIL_ADDRESSES',
    'default' => 'root@localhost',
    'configname' => 'psad_email_alert_addresses',
    },

    {
    'varname' => 'EMAIL_ALERT_DANGER_LEVEL',
    'default' => 1,
    'configname' => 'psad_email_alert_danger_level',
    },

    {
    'varname' => 'ALERT_ALL',
    'default' => 'Y',
    'configname' => 'psad_alert_all',
    },

    {
    'varname' => 'ENABLE_AUTO_IDS',
    'default' => 'N',
    'configname' => 'psad_enable_auto_ids',
    },

    {
    'varname' => 'AUTO_IDS_DANGER_LEVEL',
    'default' => 5,
    'configname' => 'psad_auto_ids_danger_level',
    },

    {
    'varname' => 'PSAD_ENABLE_AT_BOOT',
    'default' => 'N',
    'configname' => 'psad_enable_at_boot',
    }
);

&InstallScript_simpler;

#============== sub routines =============
sub InstallScript_simpler() {

    my $configPrefix             = 'PSAD';
    my $psad_conf                = '/etc/psad/psad.conf';
    my $psad_daemon              = '/usr/sbin/psad';

    unless (-e $psad_conf and -e $psad_daemon) {
        &B_log("ERROR","PSAD does not appear to be installed. Download psad " .
            "here: http://www.cipherdyne.org/psad/\n");
        return;
    }

    ### If we get here then psad has been installed, so we can now
    ### configure it.

    # only do this if the user answered psad questions
    if ( &getGlobalConfig($configPrefix,'psad_config') eq 'Y' ) {

        &psad_firewall_compatibility();

        # Now, iterate through the answers filling in the script...
        # Strategy:  If and only if the Bastille config file has set a value for a variable
        # that is different from the default, then call B_replace_line() on psad and
        # psad.conf.

        OPTS: for (my $loop=0; $loop < scalar(@psadOptions); ++$loop) {

            my $ans = &getGlobalConfig($configPrefix,$psadOptions[$loop]{'configname'});
            my $variable = $psadOptions[$loop]{'varname'};

            if ($variable eq 'PSAD_ENABLE_AT_BOOT' && $ans eq 'Y') {
                &B_log("ACTION","# PSAD.pm: enabling psad with B_chkconfig_on\n");
                &B_chkconfig_on('psad');
                next OPTS;
            }

            ### if $ans was not set in the config file, then the default
            ### value must be in place (it wasn't changed).
            next OPTS unless $ans;

            ### deal with @EMAIL_ADDRESSES array
            if ($variable eq 'EMAIL_ADDRESSES') {
                my $pattern = '^\s*' . $variable . '\s';
                my $assignment = $variable .
                    '               ' . "$ans;\n";
                &B_replace_line($psad_conf, $pattern, $assignment);
                next OPTS;
            }

            ### deal with DANGER_LEVELS
            if ($variable eq 'DANGER_LEVELS') {
                my @ans = split /\s+/, $ans;
                for (my $i = 1; $i <= 5; $i++) {
                    my $pattern = 'DANGER_LEVEL' . $i;
                    my $assignment = 'DANGER_LEVEL' . $i .
                        '               ' . $ans[$i-1] . ";\n";
                    &B_replace_line($psad_conf, $pattern, $assignment);
                }
                next OPTS;
            }

            my $pattern = '^\s*' . $variable . '\s';
            my $assignment = $variable .
                '               ' . $ans . ";\n";

            &B_replace_line($psad_conf, $pattern, $assignment);
        }
    }
    return;
}

sub psad_firewall_compatibility() {
    my $firewall_config_file = '/etc/Bastille/bastille-firewall.cfg';
    my $firewall_init_script = $GLOBAL_DIR{"initd"} . '/bastille-firewall';

    ### since the admin configured psad, we must configure the firewall
    ### to log packets that are not explicitly accepted
    my $fwlog_pattern = '^LOG_FAILURES\s*=';
    my $fwlog_assignment = "LOG_FAILURES=\"Y\"\n";
    &B_replace_line($firewall_config_file,$fwlog_pattern,$fwlog_assignment);

    my $fwtcpaudit_pattern = '^TCP_AUDIT_SERVICES\s*=';
    my $fwtcpaudit_assignment = "TCP_AUDIT_SERVICES=\"\"\n";
    &B_replace_line($firewall_config_file,$fwtcpaudit_pattern,$fwtcpaudit_assignment);

    my $fwudpaudit_pattern = '^UDP_AUDIT_SERVICES\s*=';
    my $fwudpaudit_assignment = "UDP_AUDIT_SERVICES=\"\"\n";
    &B_replace_line($firewall_config_file,$fwudpaudit_pattern,$fwudpaudit_assignment);

    ### put the pre-audit script in place.  This script is responsible
    ### for making the firewall not write log messages for very chatty
    ### protocols such as netbios and multicast traffic.
    mkdir '/etc/Bastille/firewall.d', 500;
    mkdir '/etc/Bastille/firewall.d/pre-audit.d', 500;
    &B_place('/bastille-firewall-pre-audit.sh',
        '/etc/Bastille/firewall.d/pre-audit.d/pre-audit.sh');

    if ( &getGlobalConfig('Firewall','ip_enable_firewall') eq 'Y' ) {
        # run the firewall and enable it with chkconfig
            &B_log("ACTION","# PSAD.pm: restarting firewall after PSAD modifications\n");
            if ( ! (-x $firewall_init_script) ) {
                &B_log("ERROR","# PSAD.pm: \"$firewall_init_script\" not executable\n");
            } else {
                unless (((system "$firewall_init_script restart") >> 8) == 0) {
                    &B_log("ERROR","# PSAD.pm: error $? invoking \"$firewall_init_script\"\n");
                }
            }
    }
    return;
}

1;
