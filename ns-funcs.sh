#!/bin/sh
#
# Namespace related shell functions
#
# Copyright 2018 Yoichi Hariguchi
#

#
# ns_add: Add namespaces
#
#   ns_add ns1 [ns2 ...]
#
ns_add () {
  rc=0
  for ns in $*
  do
    if [ -f /var/run/netns/$ns ]; then
      #
      # Wipe out the namespace if it already exists
      #
      ip netns del $ns || rc=$?
      sleep 1
    fi
    echo "adding $ns"
    ip netns add $ns || rc=$?
  done
  return $rc
}

#
# ns_del: Delete namespaces.
#         Delete all the existing namespaces
#         if there are no arguments
#
#   ns_del [ns1 ...]
#
ns_del () {
  rc=0
  if [ $# = 0 ]; then
    name_spaces=`ip netns`
  else
    name_spaces="$*"
  fi
  for ns in $name_spaces
  do
    echo "deleting $ns"
    ip netns del $ns || rc=$?
  done
  return $rc
}

#
# ns_add_if: Add an interface to namespace
#
#  ns_add_if ns1 eth1
#
ns_add_if () {
  rc=0
  if [ $# -ge 2 ]; then
    ns=$1
    intf=$2
    ip link set $intf netns $ns up || rc=$?
    ip netns exec $ns ifconfig lo 127.0.0.1/8 up || rc=$?
  else
    echo "ns_add_if(): Error: too few args: $*" 1>&2
    rc=1
  fi

  return $rc
}

#
# vif_add: Add a pair of veth interfaces
#
#  vif_add veth1 veth2
#
vif_add () {
  rc=0
  if [ $# -ge 2 ]; then
    if [ ! -d /sys/devices/virtual/net/$1 ]; then
      if [ ! -d /sys/devices/virtual/net/$2 ]; then
        ip link add $1 type veth peer name $2 || rc=$?
        if [ $rc -eq 0 ]; then
          for intf in $1 $2
          do
            ip link set $intf up || rc2=$?
            if [ $rc -ne 0 ]; then
              echo "vif_add(): Error: failed to set link up ($intf)" 1>&2
              rc=1
            fi
          done
        fi
      else
        echo "vif_add(): $2 already exists" 1>&2
      fi
    else
      echo "vif_add(): $1 already exists" 1>&2
    fi
  else
    echo "vif_add(): Error: too few args: $*" 1>&2
    rc=1
  fi

  return $rc
}

#
# vif_del: Delete a (pair of) veth interface
#
#  vif_del veth1
#
vif_del () {
  rc=0
  if [ $# -ge 1 ]; then
    if [ -d /sys/devices/virtual/net/$1 ]; then
      ip link del $1 || rc=1
      if [ $rc -ne 0 ]; then
        echo "vif_del(): Error: failed to delete $1" 1>&2
      fi
    else
      echo "vif_del(): $1 does not exist" 1>&2
    fi
  else
    echo "vif_del(): Error: too few args: $*" 1>&2
    rc=1
  fi

  return $rc
}

#
# vif_peer_index: Get peer vif's ifindex
#
#  vif_peer_index veth1
#
vif_peer_index () {
  rc=0
  if [ $# -lt 1 ]; then 
    echo "vif_peer_index(): Error: too few args: $*" 1>&2
    return 1
  fi
  _out=`ethtool -S $1 2> /dev/null`
  if [ $? -eq 0 ]; then
      echo $_out | sed 's/^.*peer_ifindex: //'
  fi
  return $rc
}

#
# ns_add_ifaddr: attach an IPv4/IPv6 address to
#                the specified interface and namespace
#
#  ns_add_ifaddr ns1 eth1 2001:0:0:1::1/64 8192
#
ns_add_ifaddr () {
  rc=0
  if [ $# -lt 3 ]; then 
    echo "ns_add_ifaddr(): Error: too few args: $*" 1>&2
    return 1
  fi

  ns=$1
  intf=$2
  ipa=$3
  if echo $ipa | grep ':' > /dev/null ; then
    ver="-6"
  else
    ver="-4"
  fi
  if [ $# -ge 4 ]; then
    ip netns exec $ns ip link set dev $intf mtu $4 || rc=$?
  fi
  ip netns exec $ns ip $ver addr flush dev $intf || rc=$?
  ip netns exec $ns ip addr add $ipa dev $intf || rc=$?

  return $rc
}

#
# ns_flush_ifaddr: delete all IPv4/IPv6 addresses from
#                the interface in the specified namespace
#
#  ns_flush_ifaddr ns1 eth1
#
ns_flush_ifaddr () {
  rc=0
  if [ $# -ge 2 ]; then
    ns=$1
    intf=$2
    ip netns exec $ns ip -4 addr flush dev $intf || rc=$?
    ip netns exec $ns ip -6 addr flush dev $intf || rc=$?
  else
    echo "ns_flush_ifaddr(): Error: too few args: $*" 1>&2
    rc=1
  fi

  return $rc
}

# ns_exec: execute a command in the specified namespace
#
#  ns_exec ns1 cmd [...]
#
ns_exec () {
  rc=0
  if [ $# -ge 2 ]; then
    ns=$1
    shift
    ip netns exec $ns $* || rc=$?
  else
    echo "ns_exec(): Error: too few args: $*" 1>&2
    rc=1
  fi

  return $rc
}

#
# br_add: add a bridge
#
#  br_add br1
#
br_add () {
  rc=0
  if [ $# -ge 1 ]; then
    if ! brctl show | grep "$1" > /dev/null ; then
      brctl addbr "$1" || rc=1
      if [ $rc -eq 0 ]; then
        ifconfig $1 up
      else
        echo "br_add(): Error: failed to add bridge $1" 1>&2
      fi
    else
      echo "br_add(): bridge $1 already exists" 1>&2
    fi
  fi

  return $rc
}

#
# br_del: delete a bridge
#
#  br_del br1
#
br_del () {
  rc=0
  if [ $# -ge 1 ]; then
    if brctl show | grep "$1" > /dev/null ; then
      ifconfig "$1" down
      brctl delbr "$1" || rc=1
      if [ $rc -ne 0 ]; then
        echo "br_del(): Error: failed to delete bridge $1" 1>&2
      fi
    else
      echo "br_del(): brige $1 does not exist" 1>&2
    fi
  fi

  return $rc
}

#
# br_addif: Add an interface to a bridge
#
#  br_addif br1 intf
#
br_addif () {
  rc=0
  if [ $# -ge 2 ]; then
    brctl addif "$1" "$2" || rc=1
    if [ $rc -ne 0 ]; then
      if ! brctl addif "$1" "$2" 2>&1 | \
          grep 'already a member of a bridge' > /dev/null ; then
        echo "br_addif(): Error: failed to add interface $2 to bridge $1" 1>&2
      fi
    fi
  else
    echo "br_addif(): Error: too few args: $*" 1>&2
  fi

  return $rc
}

#
# br_delif: Delete an interface from a bridge
#
#  br_delif br1 intf
#
br_delif () {
  rc=0
  if [ $# -ge 2 ]; then
    brctl delif "$1" "$2" || rc=1
    if [ $rc -ne 0 ]; then
      echo "br_delif(): Error: failed to delete interface $2 from bridge $1" 1>&2
    fi
  else
    echo "br_delif(): Error: too few args: $*" 1>&2
  fi

  return $rc
}

#
# pci2if: Convert pci address to interface name
#
#  pci2if 0000:09:00.1
#
pci2if () {
  rc=0
  if [ $# -ge 1 ]; then
    if ! echo $1 | grep '^[0-9][0-9][0-9][0-9]:' > /dev/null ; then
      prefix="0000:"
    fi
    echo `ls /sys/bus/pci/devices/${prefix}$1/net`
  else
    echo "pci2if(): Error: too few args: $*" 1>&2
  fi
}
