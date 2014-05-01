#!/bin/sh

IPTABLES=/sbin/iptables
if [ -e /sbin/iptables ]; then
    IPTABLES=/sbin/iptables
else
    IPTABLES=/usr/sbin/iptables
fi
CONFIG=/etc/Bastille/bastille-firewall.cfg

for chain in INPUT PUB_IN INT_IN ; do
	### drop netbios traffic
	${IPTABLES} -A ${chain} -p tcp --dport 137:139 -j ${REJECT_METHOD}
	${IPTABLES} -A ${chain} -p udp --dport 137:139 -j ${REJECT_METHOD}

	### drop multicast traffic
	${IPTABLES} -A ${chain} -d 224/8 -j ${REJECT_METHOD}
done
