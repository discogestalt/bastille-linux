This software is copyright Jay Beale and the individual authors listed.  It is
licensed under the GNU General Public License, version 2, which allows for the use,
distribution and modification, with restrictions intended to keep it and all
derivative works open for use and modification by the public.

This is the Bastille Hardening Program which is intended to tighten security on
Linux and Unix machines.  It presently works well under Red Hat and Mandrake
Linux, but, under the new architecture (as of 1.1.0), can be easily enhanced
to run under other distributions / Unices by adding rvalues for the $GLOBAL_
variables.

QUICK START: 

   You can run Bastille in Full Interactive Mode by doing the following:

     0) Make sure you're logged in as root!
     1) Untar the bastille tarball in /root

           cd /root
           tar -xzpf Bastille-1.1.1.tgz

     2) chdir to this directory, by typing:     

           cd /root/Bastille

     3) Run the GUI to create and act on a config file.  The GUI requires
        perl-Tk to run under X or perl-Curses to run without X.  Please
	have one of these installed!

	   InteractiveBastille

     4) The TUI will implement your changes automatically.  You can re-run
        those changes on 1 or many machines by copying BastilleBackEnd and 
	config to that machine, then running BastilleBackEnd.

QUICK START w/ QUICKER FINISH:

     Follow steps above, replacing step 3 with: 
     
     3) Copy a template configuration file to /etc/Bastille/config:

       cp /usr/share/Bastille/FOO_config /etc/Bastille/config

     where FOO_config is a configuration file that matches your machine
     well.

     4) Implement this via the command  BastilleBackEnd

HISTORY:

The Bastille Linux Project was started by Jon Lasser, of UMBC, Ben Woodard, 
at VA Linux systems, and an informal group that met at a SANS 98 Conference. 
The primary codebase was donated by Jay Beale, who joined as Lead Developer
for the project.  Peter Watkins donated his firewalling script and began
heading up development for that module.  Other developers have joined,
contributing modules or ideas.


You can find a more complete Credits list in the file Credits.

Special Thanks to Arthur Corliss, for his Curses::Widgets module.

	



