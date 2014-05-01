#!/bin/sh

umask 077
RPM_BUILD_ROOT=""

mkdir -p $RPM_BUILD_ROOT/usr/sbin
mkdir -p $RPM_BUILD_ROOT/usr/lib/perl5/site_perl/Curses
mkdir -p $RPM_BUILD_ROOT/usr/lib/Bastille
mkdir -p $RPM_BUILD_ROOT/usr/lib/Bastille/API
mkdir -p $RPM_BUILD_ROOT/usr/share/Bastille
mkdir -p $RPM_BUILD_ROOT/usr/share/Bastille/OSMap
mkdir -p $RPM_BUILD_ROOT/usr/share/Bastille/OSMap/Modules
mkdir -p $RPM_BUILD_ROOT/usr/share/Bastille/Questions
mkdir -p $RPM_BUILD_ROOT/usr/share/Bastille/FKL/configs/
mkdir -p $RPM_BUILD_ROOT/var/lock/subsys/bastille
 
cp AutomatedBastille $RPM_BUILD_ROOT/usr/sbin/
cp BastilleBackEnd $RPM_BUILD_ROOT/usr/sbin
cp Bastille_Curses.pm $RPM_BUILD_ROOT/usr/lib/perl5/site_perl
cp Bastille_Tk.pm $RPM_BUILD_ROOT/usr/lib/perl5/site_perl
cp Curses/Widgets.pm $RPM_BUILD_ROOT/usr/lib/perl5/site_perl/Curses
cp InteractiveBastille $RPM_BUILD_ROOT/usr/sbin
# Questions.txt has been replaced by Modules.txt and Questions/
#cp Questions.txt $RPM_BUILD_ROOT/usr/share/Bastille
cp Modules.txt $RPM_BUILD_ROOT/usr/share/Bastille
# New Weights file(s).
cp Weights.txt $RPM_BUILD_ROOT/usr/share/Bastille
# Castle graphic
cp bastille.jpg $RPM_BUILD_ROOT/usr/share/Bastille/
# Javascript file
cp wz_tooltip.js $RPM_BUILD_ROOT/usr/share/Bastille/
cp Credits $RPM_BUILD_ROOT/usr/share/Bastille
cp FKL/configs/fkl_config_redhat.cfg $RPM_BUILD_ROOT/usr/share/Bastille/FKL/configs/

cp RevertBastille $RPM_BUILD_ROOT/usr/sbin
cp bin/bastille $RPM_BUILD_ROOT/usr/sbin
chmod +x $RPM_BUILD_ROOT/usr/sbin/RevertBastille
cp bastille-firewall $RPM_BUILD_ROOT/usr/share/Bastille
cp bastille-firewall-reset $RPM_BUILD_ROOT/usr/share/Bastille
cp bastille-firewall-schedule $RPM_BUILD_ROOT/usr/share/Bastille
cp bastille-tmpdir-defense.sh $RPM_BUILD_ROOT/usr/share/Bastille
cp bastille-tmpdir.csh $RPM_BUILD_ROOT/usr/share/Bastille
cp bastille-tmpdir.sh $RPM_BUILD_ROOT/usr/share/Bastille
cp bastille-firewall.cfg $RPM_BUILD_ROOT/usr/share/Bastille
cp bastille-ipchains $RPM_BUILD_ROOT/usr/share/Bastille
cp bastille-netfilter $RPM_BUILD_ROOT/usr/share/Bastille
cp bastille-firewall-early.sh $RPM_BUILD_ROOT/usr/share/Bastille
cp bastille-firewall-pre-audit.sh $RPM_BUILD_ROOT/usr/share/Bastille
cp complete.xbm $RPM_BUILD_ROOT/usr/share/Bastille
cp incomplete.xbm $RPM_BUILD_ROOT/usr/share/Bastille
cp disabled.xpm $RPM_BUILD_ROOT/usr/share/Bastille
cp ifup-local $RPM_BUILD_ROOT/usr/share/Bastille


cp hosts.allow $RPM_BUILD_ROOT/usr/share/Bastille
cp Bastille/AccountSecurity.pm $RPM_BUILD_ROOT/usr/lib/Bastille
cp Bastille/Apache.pm $RPM_BUILD_ROOT/usr/lib/Bastille
cp Bastille/API.pm $RPM_BUILD_ROOT/usr/lib/Bastille/API.pm
cp Bastille/API/AccountPermission.pm $RPM_BUILD_ROOT/usr/lib/Bastille/API
cp Bastille/API/FileContent.pm $RPM_BUILD_ROOT/usr/lib/Bastille/API
cp Bastille/API/HPSpecific.pm $RPM_BUILD_ROOT/usr/lib/Bastille/API
cp Bastille/API/ServiceAdmin.pm $RPM_BUILD_ROOT/usr/lib/Bastille/API
cp Bastille/API/Miscellaneous.pm $RPM_BUILD_ROOT/usr/lib/Bastille/API
cp Bastille/BootSecurity.pm $RPM_BUILD_ROOT/usr/lib/Bastille
cp Bastille/ConfigureMiscPAM.pm $RPM_BUILD_ROOT/usr/lib/Bastille
cp Bastille/DisableUserTools.pm $RPM_BUILD_ROOT/usr/lib/Bastille
cp Bastille/DNS.pm $RPM_BUILD_ROOT/usr/lib/Bastille
cp Bastille/FilePermissions.pm $RPM_BUILD_ROOT/usr/lib/Bastille
cp Bastille/FTP.pm $RPM_BUILD_ROOT/usr/lib/Bastille
cp Bastille/Firewall.pm $RPM_BUILD_ROOT/usr/lib/Bastille
cp Bastille/OSX_API.pm $RPM_BUILD_ROOT/usr/lib/Bastille
cp Bastille/LogAPI.pm $RPM_BUILD_ROOT/usr/lib/Bastille
cp Bastille/HP_UX.pm $RPM_BUILD_ROOT/usr/lib/Bastille
cp Bastille/IOLoader.pm $RPM_BUILD_ROOT/usr/lib/Bastille
cp Bastille/Patches.pm $RPM_BUILD_ROOT/usr/lib/Bastille
cp Bastille/Logging.pm $RPM_BUILD_ROOT/usr/lib/Bastille
cp Bastille/MiscellaneousDaemons.pm $RPM_BUILD_ROOT/usr/lib/Bastille
cp Bastille/PatchDownload.pm $RPM_BUILD_ROOT/usr/lib/Bastille
cp Bastille/Printing.pm $RPM_BUILD_ROOT/usr/lib/Bastille
cp Bastille/PSAD.pm $RPM_BUILD_ROOT/usr/lib/Bastille
cp Bastille/RemoteAccess.pm $RPM_BUILD_ROOT/usr/lib/Bastille
cp Bastille/SecureInetd.pm $RPM_BUILD_ROOT/usr/lib/Bastille
cp Bastille/Sendmail.pm $RPM_BUILD_ROOT/usr/lib/Bastille
cp Bastille/TestDriver.pm $RPM_BUILD_ROOT/usr/lib/Bastille
cp Bastille/TMPDIR.pm $RPM_BUILD_ROOT/usr/lib/Bastille
cp Bastille/test_AccountSecurity.pm $RPM_BUILD_ROOT/usr/lib/Bastille
cp Bastille/test_Apache.pm $RPM_BUILD_ROOT/usr/lib/Bastille
cp Bastille/test_DNS.pm $RPM_BUILD_ROOT/usr/lib/Bastille
cp Bastille/test_FTP.pm $RPM_BUILD_ROOT/usr/lib/Bastille
cp Bastille/test_HP_UX.pm $RPM_BUILD_ROOT/usr/lib/Bastille
cp Bastille/test_MiscellaneousDaemons.pm $RPM_BUILD_ROOT/usr/lib/Bastille
cp Bastille/test_Patches.pm $RPM_BUILD_ROOT/usr/lib/Bastille
cp Bastille/test_SecureInetd.pm $RPM_BUILD_ROOT/usr/lib/Bastille
cp Bastille/test_Sendmail.pm $RPM_BUILD_ROOT/usr/lib/Bastille
cp Bastille/test_BootSecurity.pm $RPM_BUILD_ROOT/usr/lib/Bastille
cp Bastille/test_DisableUserTools.pm $RPM_BUILD_ROOT/usr/lib/Bastille
cp Bastille/test_FilePermissions.pm $RPM_BUILD_ROOT/usr/lib/Bastille
cp Bastille/test_Logging.pm $RPM_BUILD_ROOT/usr/lib/Bastille
cp Bastille/test_Printing.pm $RPM_BUILD_ROOT/usr/lib/Bastille
cp Bastille/IPFilter.pm $RPM_BUILD_ROOT/usr/lib/Bastille



cp OSMap/LINUX.bastille $RPM_BUILD_ROOT/usr/share/Bastille/OSMap
cp OSMap/LINUX.system $RPM_BUILD_ROOT/usr/share/Bastille/OSMap
cp OSMap/LINUX.service $RPM_BUILD_ROOT/usr/share/Bastille/OSMap
cp OSMap/HP-UX.bastille $RPM_BUILD_ROOT/usr/share/Bastille/OSMap
cp OSMap/HP-UX.system $RPM_BUILD_ROOT/usr/share/Bastille/OSMap
cp OSMap/HP-UX.service $RPM_BUILD_ROOT/usr/share/Bastille/OSMap
cp OSMap/OSX.bastille $RPM_BUILD_ROOT/usr/share/Bastille/OSMap
cp OSMap/OSX.system $RPM_BUILD_ROOT/usr/share/Bastille/OSMap

for file in `cat Modules.txt` ; do
   cp Questions/$file.txt $RPM_BUILD_ROOT/usr/share/Bastille/Questions
done

ln -s $RPM_BUILD_ROOT/usr/sbin/RevertBastille $RPM_BUILD_ROOT/usr/sbin/UndoBastille
