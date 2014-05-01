# portforward.sh
#
# designed for bastille-firewall
# Copyright (c) 2002 Peter Watkins
# $Id: portforward.sh,v 1.3 2002/02/27 05:57:51 peterw Exp $
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program; if not, write to the Free Software
#    Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307 USA
#
# place in /etc/Bastille/firewall.d/pre-chain-split.d
# as portforward.sh (directory name and .sh suffix are critical)
#
#
# Settings:
#
# 1) IP_FORWARDS (all OSes/kernel versions)
#
# List your port forwarding info here. This should be a whitespace
# separated list. Each item in the list should be be a hyphen-separated
# list including the following, in this order
# - interface name, e.g. "eth0" (blank for all)
# - destination address, e.g. "192.168.1.1" for the single
#   address 192.168.1.1, "0.0.0.0/0" for any address, etc.
#   (this address should contain a netmask, e.g. 192.168.1.1/24)
# - the destination port number, e.g. "80" for standard HTTP
# - the protocol type or number, e.g. "tcp"
# - the forwarding service address, e.g. "172.19.1.2"
# - the forwarding service port, e.g. "8000"
#
# Example:
#   IP_FORWARDS="eth0-0.0.0.0/0-80-tcp-172.19.1.2-8000"
#  This says we only have one forwarding rule to establish. Any TCP
#  traffic destined for any address bound to the "eth0" interface's port
#  80 will be forwarded to TCP port 8000 of 172.19.1.2. This is a typical
#  rule for a site that wants to run its Web server on an internal
#  machine, using a high port so the Web server can be started by a
#  non-root user. Whether the forwarding or running on a high port are
#  a *good* idea is a question we won't address here.
#
IP_FORWARDS=""
#
#
# 2) IPMASQADM (Linux 2.2/ipchains only)
#
#
# For 2.2-based kernels, where is ipmasqadm?
IPMASQADM="/sbin/ipmasqadm"
#
if [ -z "${IPCHAINS}" -a -z "${IPTABLES}" ]; then
  echo "Error: only good for iptables or ipchains/ipmasqadm" > /dev/stderr
elif [ -n "${IPCHAINS}" -a \( \! -x "${IPMASQADM}" \) ]; then
  echo "Please install $IPMASQADM for forwarding with 2.2/ipchains
systems" >/dev/stderr
else
  if [ -n "${IPCHAINS}" -a \( -x "${IPMASQADM}" \) ]; then
    # flush ipmasqadm rules
    ${IPMASQADM} portfw -f
    echo "WARNING: this script has not been verified to work with ipmasqadm" >/dev/stderr
  fi
  for fw_rule in ${IP_FORWARDS} ; do
    # ugly awk hack
    fw_iface=`echo "$fw_rule" | awk -F\- '{print $1}'`
    fw_inaddr=`echo "$fw_rule" | awk -F\- '{print $2}'`
    fw_inport=`echo "$fw_rule" | awk -F\- '{print $3}'`
    fw_inproto=`echo "$fw_rule" | awk -F\- '{print $4}'`
    fw_outaddr=`echo "$fw_rule" | awk -F\- '{print $5}'`
    fw_outport=`echo "$fw_rule" | awk -F\- '{print $6}'`

    if [ -n "${fw_iface}" ]; then
      # we have an interface specified
      if [ -n "${IPTABLES}" ]; then
        ${IPTABLES} -t nat -A PREROUTING -p $fw_inproto -i $fw_iface \ 
	  -d $fw_inaddr --dport $fw_inport -j DNAT \ 
	  --to $fw_outaddr:$fw_outport
        ${IPTABLES} -A FORWARD -p $fw_inproto -i $fw_iface \ 
	  -d $fw_outaddr --dport $fw_outport -j ACCEPT
      else
          # trim netmask from input addr for ipmasqadm
          fw_inaddr_masq=`echo $fw_inaddr|awk -F/ '{print $1}'`
	  dnat_addr_test=`echo $fw_inaddr_masq|grep '\.0$'`
	  if [ "${dnat_addr_test}" != "" ]; then
	    # looks like a network address, not an individual IP
	    # -- just use the IP address for the interface
	    fw_inaddr_masq=`ifconfig -a $fw_iface|grep inet.addr|awk '{print $2}'|awk -F: '{print $2}'`
	  fi
          ${IPMASQADM} portfw -a -P $fw_inproto -L $fw_inaddr_masq $fw_inport -R $fw_outaddr $fw_outport
	  ${IPCHAINS} -A input -i $fw_iface -p $fw_inproto -d $fw_inaddr_masq $fw_inport -j ACCEPT
	  #echo 1 > /proc/sys/net/ipv4/ip_forward
	  #${IPCHAINS} -A forward -i $fw_iface  -p $fw_inproto -d $fw_inaddr_masq $fw_inport -j ACCEPT
      fi
    else
      # apply forward to all interfaces
      if [ -n "${IPTABLES}" ]; then
        ${IPTABLES} -t nat -A PREROUTING -p $fw_inproto  \ 
	  -d $fw_inaddr --dport $fw_inport -j DNAT \ 
	  --to $fw_outaddr:$fw_outport
        ${IPTABLES} -A FORWARD -p $fw_inproto  -d $fw_outaddr \ 
	  --dport $fw_outport -j ACCEPT
      else
          # same as rule without interface specified, actually
          # trim netmask from input addr for ipmasqadm
          fw_inaddr_masq=`echo $fw_inaddr|awk -F/ '{print $1}'`
	  dnat_addr_test=`echo $fw_inaddr_masq|grep '\.0$'`
	  if [ "${dnat_addr_test}" != "" ]; then
	    echo "Warning: you should specify a specific IP address" >/dev/stderr
	  fi
          ${IPMASQADM} portfw -a -P $fw_inproto -L $fw_inaddr_masq $fw_inport -R $fw_outaddr $fw_outport
	  ${IPCHAINS} -A input -p $fw_inproto -d $fw_inaddr_masq $fw_inport -j ACCEPT
	  #echo 1 > /proc/sys/net/ipv4/ip_forward
	  #${IPCHAINS} -A forward -p $fw_inproto -d $fw_inaddr_masq $fw_inport -j ACCEPT
      fi
    fi
  done
fi
