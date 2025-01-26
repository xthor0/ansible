#!/bin/bash
## we need to know what the name of the main interface is
netdev=$(ip route | grep ^default | awk '{ print $5 }')

## validate we got a valid interface
if [ -d /proc/sys/net/ipv4/conf/${netdev} ]; then
  echo "Validated: primary network device is ${netdev}"
else
  echo "Error: ${netdev} is not a valid network interface device, this script has bugs, exiting."
  exit 255
fi

## what's my IP address, so I can set it correctly later
ipaddr=$(ip -4 -br addr show ${netdev} | awk '{ print $3 }')
gateway=$(ip route | grep ^default | awk '{ print $3 }')

## set up the primary br0 for default vlan
nmcli c delete ${netdev}
nmcli c add type bridge ifname br0 autoconnect yes con-name br0 stp off
nmcli c modify br0 ipv4.addresses ${ipaddr} ipv4.gateway ${gateway} ipv4.dns ${gateway} ipv4.method manual
nmcli c add type bridge-slave autoconnect yes con-name ${netdev} ifname ${netdev} master br0
nmcli con up ${netdev}

# don't know why I had to do this AGAIN, but...
nmcli c mod br0 ipv4.method manual
nmcli c up br0

# individual vlan setup
for vlan in 50 51 52 53 54 55; do
nmcli c add type bridge ifname br-vlan${vlan} autoconnect yes con-name br-vlan${vlan} stp off
nmcli c modify br-vlan${vlan} ipv4.method disabled ipv6.method ignore
nmcli con up br-vlan${vlan}
nmcli c add type vlan autoconnect yes con-name vlan${vlan} dev ${netdev} id ${vlan} master br-vlan${vlan} slave-type bridge
done

