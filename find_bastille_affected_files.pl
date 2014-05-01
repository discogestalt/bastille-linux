#!/usr/bin/perl


 
use lib "/usr/lib";
push (@INC,"/usr/lib/perl5/site_perl/");
push (@INC,"/usr/lib/Bastille");  

use Bastille::API;

foreach $key (keys(%GLOBAL_BIN)) {
	unless ( -e $GLOBAL_BIN{$key} ) {
		print "Missing file for key $key\n";
	}
}

foreach $key (keys(%GLOBAL_FILE)) {
        unless ( -e $GLOBAL_FILE{$key} ) {
                print "Missing file for key $key\n";
        }
}
foreach $key (keys(%GLOBAL_DIR)) {
        unless ( -d $GLOBAL_DIR{$key} ) {
                print "Missing directory for key $key\n";
        }
}

