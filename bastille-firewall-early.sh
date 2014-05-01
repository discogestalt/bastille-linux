#
# /etc/Bastille/bastille-firewall-early.sh
#
# a Bourne script
#
# ** This script is sourced, so do NOT use 'exit' **
#
# Use this file for commands run after the Bastille firewall
# script flushes the chains, but before it constructs any rules.


# The Bastille firewall is designed to work with 'ipchains'
# or 'iptables', so you should implement custom rules inside
# conditional tests, for both systems, like this:
#
# if [ -n "${IPCHAINS}" ]; then
#	# using 2.2/ipchains or 2.4/ipchains, add ipchains rules
#	#${IPCHAINS} -A input ...etc...
# fi
#
# if [ -n "${IPTABLES}" ]; then
#	# using 2.4/iptables, add iptables rules
#	#${IPTABLES} -A INPUT ...etc...
# fi


# Logic to try to accomodate Mandrake "Internet Connection Sharing"
#
if [ -f /etc/sysconfig/inet_sharing -a -x /etc/rc.d/rc.firewall.inet_sharing ]; then
	#
	# Mandrake user who has ICS installed, check if it's enabled
	# (this config file should define the variable $INET_SHARING)
	#
	unset INTERFACE
	. /etc/sysconfig/inet_sharing
	#
	if [ "${INET_SHARING}" = "enabled" ]; then
	    if [ -z "${IP_MASQ_NETWORK}" ]; then
		#
		# We do not have NAT enabled in the Bastille firewall
		# Let them know we're loading Mandrake's rules
		#
		echo "Enabling Mandrake Internet Connection sharing"
		echo "If you would like to use Bastille's masquerading"
		echo "support instead, edit /etc/Bastille/bastille-firewall.cfg"
		echo "(especially the IP_MASQ_NETWORK setting) and run"
		echo " /etc/rc.d/init.d/bastille-firewall start"
		echo "to use Bastille's masquerading/connection sharing rules."
		#
		# if they're using ipchains, they would have needed to
		# declare the interface connected to the MASQ network as
		# "trusted" so the traffic can flow...
		#
		# We don't care about trusted interfaces unless you're
		# using ipchains and an old version of Mandrake ICS
		more_than_lo=1
		#
		# if we see $INTERFACE, it means they have a newer Mandrake
		# ICS setup which will handle the needed input rule
		#
		if [ -n "${IPCHAINS}" -a -z "${INTERFACE}" ]; then
			# now we care bout having other trusted interfaces
			more_than_lo=0
			# Let's add the interface for them if we can figure it out..
			#
			# looking for "/sbin/ipchains -A forward -s A.B.C.0/24 -j MASQ"
			ics_if_regexp=`grep '^/sbin/ipchains \-A forward \-s ' /etc/rc.d/rc.firewall.inet_sharing | egrep '\-j MASQ' | awk '{print $5}' | awk -F/ '{print $1}'| awk -F. '{print "^"$1"\\\\."$2"\\\\."$3"\\\\."}'`
			# now look for the matching interface in `netstat -nr`
			ics_iface=`netstat -nr | egrep $ics_if_regexp | awk '{print $8}'`
			# make sure that interface is in TRUSTED_IFACES
			TRUSTED_IFACES="${TRUSTED_IFACES} ${ics_iface}"
			# tell the user what we're doing
			if [ -n "${ics_iface}" ]; then
				echo "Adding \"${ics_iface}\" to the trusted interface list"
			fi
			unset ics_if_regexp
			unset ics_iface
		fi
		#
		# See if any non-loopback interfaces are defined. We loop through all
		# the values in ${TRUSTED_IFACES} because there may be weird spacing,
		# e.g., "lo" != "lo " != " lo", etc.
		#
		for i in ${TRUSTED_IFACES} ; do
			if [ "${i}" != "lo" ]; then
				more_than_lo=1
			fi
		done
		if [ $more_than_lo -eq 0 -a -n "${IPCHAINS}" ]; then
		    #
		    # this is definitely true for 2.2 and 2.4/ipchains!
		    #
		    echo "WARNING: no non-local \"trusted\" interfaces are configured"
		    echo "in /etc/Bastille/bastille-firewall.cfg -- Internet Connection"
		    echo "Sharing will most like NOT work. Please consider using"
		    echo "Bastille's masquerading/connection sharing rules instead!"
		    echo "Doing so will allow you to share a connection while using"
		    echo "more strict firewall rules."
		fi
		unset more_than_lo
		#
		# If using Mandrake ICS we also need to allow DNS queries
		# from outside, so the caching DNS server will work
		#
		echo "WARNING: to allow the caching DNS server in Mandrake's"
		echo "Internet Connection Sharing system to work, we are"
		echo "adding DNS to the list of public UDP and TCP services"
		TCP_PUBLIC_SERVICES="${TCP_PUBLIC_SERVICES} domain"
		UDP_PUBLIC_SERVICES="${UDP_PUBLIC_SERVICES} domain"
		if [ -n "${IPCHAINS}" ]; then
			echo "and allowing UDP responses from any DNS server"	
			DNS_SERVERS="0.0.0.0/0"
		fi
		#
		# run Mandrake's ICS rules
		#
		/etc/rc.d/rc.firewall.inet_sharing
	    else
		#
		# NAT is configured for the Bastille firewall
		#
		echo "You have Bastille configured for masquerading and"
		echo "you have enabled Mandrake's Internet Connection Sharing."
		echo "We will use Bastille's rules. To get rid of this"
		echo "warning, use DrakConf to disable Internet Connection Sharing"
		echo "or disable Bastille's ICS by setting IP_MASQ_NETWORK to \"\""
		echo "in /etc/Bastille/bastille-firewall.cfg"
	    fi
	fi
fi

