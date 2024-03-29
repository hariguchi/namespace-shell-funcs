#!/bin/sh
#
# Namespace related shell functions
#
# Copyright 2018 Yoichi Hariguchi
#

#
# ns_add: Add namespaces
#         -f: delete namesape if already exist
#
#   ns_add [-f] ns1 [ns2 ...]
#
ns_add () {
  _rc=0
  while [ $# -gt 0 ]
  do
    case $1 in
    -f) _wipeout=1
        ;;
     *) break
        ;;
    esac
    shift
  done
  if [ -n "$_wipeout" ]; then
    for ns in $*
    do
      if [ -f /var/run/netns/$ns ]; then
        #
        # Wipe out the namespace if it already exists
        #
        ip netns del $ns || _rc=$?
        sleep 1
      fi
      echo "adding $ns"
      ip netns add $ns || _rc=$?
    done
  else
    for ns in $*
    do
      if [ -f /var/run/netns/$ns ]; then
        echo "namespace $ns already exists" 1>&2
      else
        echo "adding $ns"
        ip netns add $ns || _rc=$?
      fi
    done
  fi
  return $_rc
}

#
# ns_del: Delete namespaces.
#         Delete all the existing namespaces
#         if there are no arguments
#
#   ns_del [ns1 ...]
#
ns_del () {
  _rc=0
  if [ $# = 0 ]; then
    name_spaces=`ip netns`
  else
    name_spaces="$*"
  fi
  for ns in $name_spaces
  do
    echo "deleting $ns"
    ip netns del $ns || _rc=$?
  done
  return $_rc
}

#
# ns_add_if: Add an interface to namespace
#
#  ns_add_if ns1 eth1
#
ns_add_if () {
  _rc=0
  if [ $# -ge 2 ]; then
    ns=$1
    intf=$2
    ip link set $intf netns $ns up || _rc=$?
    ip netns exec $ns ip link set dev lo up || _rc=$?
    #ip netns exec $ns ip addr add 127.0.0.1/8 dev lo || _rc=$?
    #ip netns exec $ns ip -6 addr add ::1/128 dev lo
  else
    echo 'Usage: ns_add_if <namespace> <interface>' 1>&2
    _rc=1
  fi

  return $_rc
}

#
# ns_del_if: Delete an interface from namespace
#
#  ns_del_if ns1 eth1
#
ns_del_if () {
  _rc=0
  if [ $# -ge 2 ]; then
    ns=$1
    intf=$2
    ip netns exec $ns ip link set $2 netns 1 || _rc=$?
  else
    echo 'Usage: ns_del_if <namespace> <interface>' 1>&2
    _rc=1
  fi

  return $_rc
}


#
# vrf_add: Add a VRF
#
#  vrf_add vrfBlue 10
#
vrf_add () {
  if [ $# -lt 2 ]; then
    echo 'Usage: vrf_add <vrf> <table-id>' 1>&2
    return 1
  fi
  _rc=0
  _vrf="$1"
  _tid="$2"
  if ! ip link show $_vrf > /dev/null 2>&1 ; then
    ip link add $_vrf type vrf table $_tid || _rc=$?
    ip link set dev $_vrf up || _rc=$?
  else
    echo "vrf $_vrf already exists" 1>&2
  fi
  return $_rc
}


#
# vrf_del: Delete a VRF
#
#  vrf_del vrfBlue
#
vrf_del () {
  if [ $# -lt 1 ]; then
    echo 'Usage: vrf_del <vrf>' 1>&2
    return 1
  fi
  _rc=0
  _vrf="$1"
  if ip link show $_vrf > /dev/null 2>&1 ; then
    ip link del $_vrf || _rc=$?
  else
    echo "vrf_del: no such VRF: $_vrf" 1>&2
    _rc=1
  fi
  return $_rc
}


#
# vrf_show: list VRFs or show a VRF
#
#  vrf_show [-b] [-d] [-h] [vrf]
#
vrf_show () {
  _opt=""
  while [ $# -gt 0 ]
  do
    case $1 in
    -h*) echo "Usage: vrf_show [-b] [-d] [vrf]" 1>&2
         return 1
         ;;
    -b*) _opt="-br"
         ;;
    -d*) _opt="-d"
         ;;
    *)   break
         ;;
    esac
    shift
  done
  _rc=0
  if [ $# -lt 1 ]; then
    ip $_opt link show type vrf || _rc=$?
  else
    ip $_opt link show master $1 || _rc=$?
  fi
  return $_rc
}


#
# vrf_show_addr: list interfaces belonging to a VRF
#
#  vrf_show_addr [-b] [-d] [-h] vrf
#
vrf_show_addr () {
  _opt=""
  while [ $# -gt 0 ]
  do
    case $1 in
    -h*) echo "Usage: vrf_show_addr [-b] [-d] [vrf]" 1>&2
         return 1
         ;;
    -b*) _opt="-br"
         ;;
    -d*) _opt="-d"
         ;;
    *)   break
         ;;
    esac
    shift
  done
  if [ $# -ge 1 ]; then
    ip $_opt addr show master $1 || _rc=$?
  else
    echo "Usage: vrf_show_addr [-b] [-d] [-h] <vrf>" 1>&2
    _rc=1
  fi
  return $_rc
}


#
# vrf_show_tid: list VRFs and their table id
#
#  vrf_show_tid
#
vrf_show_tid () {
  _vrfs=`ip -br  link show type vrf | cut -d' ' -f1`
  for _vrf in $_vrfs
  do
    _tid=`ip -d link show $_vrf | grep table | cut -d' ' -f7`
    echo "$_vrf $_tid"
  done
}


#
# vrf_add_if: Add an interface to a VRF
#
#  vrf_add_if vrfBlue eth0
#
vrf_add_if () {
  if [ $# -lt 2 ]; then
    echo 'Usage: vrf_add_if <vrf> <interface>' 1>&2
    return 1
  fi
  _rc=0
  vrf="$1"
  intf="$2"
  if [ `ip link show type vrf $vrf | wc -l` -eq 0 ]; then
    echo "vrf_add_if: ERROR: no such vrf: $vrf" 1>&2
    return 1
  fi
  if ip link show $intf > /dev/null 2>&1 ; then
    ip link set dev $intf master $vrf up || _rc=$?
  else
    echo "vrf_add_if: ERROR: no such interface: $intf" 1>&2
    _rc=1
  fi
  return $_rc
}


#
# vrf_del_if: Make an interface belong to the default VRF.
#
#  vrf_del_if eth0
#
vrf_del_if () {
  if [ $# -lt 1 ]; then
    echo 'Usage: vrf_del_if <interface>' 1>&2
    return 1
  fi
  _rc=0
  if ip link show $1 > /dev/null 2>&1 ; then
    ip link set dev $1 nomaster || _rc=$?
  else
    echo "vrf_del_if: ERROR: no such interface: $1" 1>&2
    _rc=1
  fi
  return $_rc
}


#
# vrf_get_tid: Print the table id associated with the VRF
#              Return 1 if an error happens
#
#  vrf_get_tid vrf1
#
vrf_get_tid () {
  if [ $# -lt 1 ]; then
    echo 'Usage: vrf_get_tid <vrf>' 1>&2
    return 1
  fi
  _rc=0
  if ! ip -d link sh $1 > /dev/null ; then
    return 1
  fi
  tid=`ip -d link sh $1 | grep 'vrf table' | \
    sed 's/vrf table \([0-9]*\) .*$/\1/'` || _rc=$?
  if [ $_rc -eq 0 ]; then
    echo $tid
  else
    return 1
  fi
}


#
# vif_add: Add a pair of veth interfaces
#
#  vif_add veth1 veth2
#
vif_add () {
  _rc=0
  if [ $# -ge 2 ]; then
    if [ ! -d /sys/devices/virtual/net/$1 ]; then
      if [ ! -d /sys/devices/virtual/net/$2 ]; then
        ip link add $1 type veth peer name $2 || _rc=$?
        if [ $_rc -eq 0 ]; then
          for intf in $1 $2
          do
            ip link set $intf up || _rc2=$?
            if [ $_rc -ne 0 ]; then
              echo "vif_add: Error: failed to set link up ($intf)" 1>&2
              _rc=1
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
    echo 'Usage: vif_add <veth1> <veth2>' 1>&2
    _rc=1
  fi

  return $_rc
}

#
# vif_del: Delete a (pair of) veth interface
#
#  vif_del veth1
#
vif_del () {
  _rc=0
  if [ $# -ge 1 ]; then
    if [ -d /sys/devices/virtual/net/$1 ]; then
      ip link del $1 || _rc=1
      if [ $_rc -ne 0 ]; then
        echo "vif_del: Error: failed to delete $1" 1>&2
      fi
    else
      echo "vif_del: Error: $1 does not exist" 1>&2
    fi
  else
    echo 'Usage: vif_del <veth>' 1>&2
    _rc=1
  fi

  return $_rc
}

#
# vif_add_pair: Create a pair of veth interfaces from interface names
#
#  vif_add_pair if1 if2
#
#    if1-if2 <---> if2-if1
#
#
vif_add_pair () {
  _rc=0
  if [ $# -ge 2 ]; then
    if1="${1}-${2}"
    if2="${2}-${1}"
    vif_add "$if1" "$if2" || _rc=$?
  else
    echo 'Usage: vif_add_pair <interface1> <interface2>' 1>&2
    return 1
  fi

  return $_rc
}

#
# vif_peer_index: Get peer vif's ifindex
#
#  vif_peer_index veth1
#
vif_peer_index () {
  _rc=0
  if [ $# -lt 1 ]; then 
    echo 'Usage: vif_peer_index <veth>' 1>&2
    return 1
  fi
  _out=`ethtool -S $1 2> /dev/null`
  if [ $? -eq 0 ]; then
      echo $_out | sed 's/^.*peer_ifindex: //'
  fi
  return $_rc
}

#
# ns_add_ifaddr: Attach an IPv4/IPv6 address to
#                the specified interface and namespace
#
#  ns_add_ifaddr ns1 eth1 2001:0:0:1::1/64 8192
#
ns_add_ifaddr () {
  _rc=0
  if [ $# -lt 3 ]; then 
    echo 'Usage: ns_add_ifaddr <namespace> <interface> <IP-address> [mtu]' 1>&2
    return 1
  fi

  ns=$1
  intf=$2
  ipa=$3
  if [ $# -ge 4 ]; then
    mtu="mtu $4"
    #ip netns exec $ns ip link set dev $intf mtu $4 || _rc=$?
    ip netns exec $ns ip link set dev $intf up $mtu || _rc=$?
  else
    ip netns exec $ns ip addr add $ipa dev $intf || _rc=$?
  fi

  return $_rc
}

#
# ns_del_ifaddr: Detach an IPv4/IPv6 address from
#                the specified interface and namespace
#
#  ns_del_ifaddr ns1 eth1 2001:0:0:1::1/64
#
ns_del_ifaddr () {
  _rc=0
  if [ $# -lt 3 ]; then 
    echo 'Usage: ns_del_ifaddr <namespace> <interface> <IP-address>' 1>&2
    return 1
  fi

  ns=$1
  intf=$2
  ipa=$3
  ip netns exec $ns ip addr del $ipa dev $intf || _rc=$?

  return $_rc
}

#
# ns_flush_ifaddr: Delete all IPv4/IPv6 addresses from
#                the interface in the specified namespace
#
#  ns_flush_ifaddr ns1 eth1 [up]
#
ns_flush_ifaddr () {
  _rc=0
  if [ $# -ge 2 ]; then
    if [ $# -ge 2 -a "$2" = "up" ]; then
      ifup="up"
    else
      ifup=""
    fi
    ns=$1
    intf=$2
    ip netns exec $ns ip -4 addr flush dev $intf $ifup || _rc=$?
    ip netns exec $ns ip -6 addr flush dev $intf $ifup || _rc=$?
  else
    echo 'Usage: ns_flush_ifaddr <namespace> <interface> [up]' 1>&2
    _rc=1
  fi

  return $_rc
}

#
# ns_add_vlan: Add a VLAN interface to a namespace
#
#  ns_add_vlan ns1 veth1 1001
#
ns_add_vlan () {
  _rc=1
  if [ $# -ge 3  ]; then
    ip netns exec $1 ip link add link $2 name ${2}.$3 type vlan id $3
    if [ $? -eq 0 ]; then
      ip netns exec $1 ip link set dev ${2}.$3 up
      _rc=$?
    fi
  else
    echo 'Usage: ns_add_vlan <namespace> <intferface> <vlan_id>' 1>&2
  fi
  return $_rc
}

#
# ns_vlan_del: Delete a VLAN interface from a namespace
#
#   ns_del_vlan ns1 veth1 1001
#
ns_del_vlan () {
  _rc=1
  if [ $# -ge 3 ]; then
    ip netns exec $1 ip link set dev ${2}.$3 down
    if [ $? -eq 0 ]; then
      ip netns exec $1 ip link delete ${2}.$3
      _rc=$?
    fi
  else
    echo 'Usage: ns_del_vlan <namespace> <intferface> <vlan_id>' 1>&2
  fi
  return $_rc
}

# ns_exec: Execute a command in the specified namespace
#
#  ns_exec ns1 cmd [...]
#
ns_exec () {
  _rc=0
  if [ $# -ge 2 ]; then
    ns=$1
    shift
    ip netns exec $ns $* || _rc=$?
  else
    echo 'Usage: ns_exec <namespace> <command> [...]' 1>&2
    _rc=1
  fi

  return $_rc
}

# ns_list: Show all the existing namespaces
#
#  ns_list
#
ns_list () {
  ip netns
}

# ns_runsh: Run a shell ($SHELL unless specified) in the given namespace
#
#  ns_runsh ns1 [shell]
#
ns_runsh () {
  _rc=0
  if [ $# -ge 1 ]; then
    ns=$1
    shift
    if [ $# -ge 1 ]; then
      shell=$1
    else
      shell=$SHELL
    fi
    ip netns exec $ns $shell || _rc=$?
  else
    echo 'Usage: ns_runsh <namespace> [shell]' 1>&2
    _rc=1
  fi

  return $_rc
}

#
# ns_where: Show the namespae in which the shell is running
#
#  ns_where
#
ns_where () {
  ip netns identify
}

#
# ns_exists: Return 0 if the specified namespace exists
#
#  ns_exists ns
#
ns_exists () {
  if [ $# -lt 1 ]; then
    echo "Usage: ns_exists ns:" 1>&2
    return 1
  fi
  if [ -f /var/run/netns/$1 ]; then
    return 0
  fi
  return 1
}

#
# ns_set_ipv4_fwrd: Enable/disable IPv4 forwarding
#
#   ns_set_ipv4_fwrd ns <enable|disable>
#
ns_set_ipv4_fwrd () {
  if [ $# -lt 2 ]; then
    echo "Usage: ns_set_ipv4_fwrd ns <enable|disable>" 1>&2
    return 1
  fi
  case $2 in
  d*) _val=0
      ;;
  e*) _val=1
      ;;
  *)  echo "Usage: ns_set_ipv4_fwrd ns <enable|disable>" 1>&2
      return 1
      ;;
  esac
  _cmd="ip netns exec $1"
  $_cmd sh -c "/bin/echo $_val > /proc/sys/net/ipv4/ip_forward"
}

#
# ns_disable_ipv4_fwrd: Disable IPv4 forwarding
#
#   ns_disable_ipv4_fwrd ns
#
ns_disable_ipv4_fwrd () {
  if [ $# -lt 1 ]; then
    echo "Usage: ns_disable_ipv4_fwrd ns" 1>&2
    return 1
  fi
  ns_set_ipv4_fwrd $1 disable
}

#
# ns_enable_ipv4_fwrd: Enable IPv4 forwarding
#
#   ns_enable_ipv4_fwrd ns
#
ns_enable_ipv4_fwrd () {
  if [ $# -lt 1 ]; then
    echo "Usage: ns_disable_ipv4_fwrd ns" 1>&2
    return 1
  fi
  ns_set_ipv4_fwrd $1 enable
}

#
# if_add_addr: Attach an IPv4/IPv6 address to the specified interface
#
#  if_add_addr eth1 2001:0:0:1::1/64 8192
#
if_add_addr () {
  _rc=0
  if [ $# -lt 2 ]; then 
    echo 'Usage: if_add_addr <interface> <IP-address> [mtu]' 1>&2
    return 1
  fi

  intf=$1
  ipa=$2
  if echo $ipa | grep ':' > /dev/null ; then
    ver="-6"
  else
    ver="-4"
  fi
  if [ $# -ge 3 ]; then
    ip link set dev $intf mtu $3 || _rc=$?
  fi
  ip addr add $ipa dev $intf || _rc=$?

  return $_rc
}

#
# if_del_addr: Detach an IPv4/IPv6 address from the specified interface
#
#  if_del_addr eth1 2001:0:0:1::1/64
#
if_del_addr () {
  _rc=0
  if [ $# -lt 2 ]; then 
    echo 'Usage: if_del_addr <interface> <IP-address>' 1>&2
    return 1
  fi

  intf=$1
  ipa=$2
  if echo $ipa | grep ':' > /dev/null ; then
    ver="-6"
  else
    ver="-4"
  fi
  ip addr del $ipa dev $intf || _rc=$?

  return $_rc
}

#
# if_flush_addr: Delete all IPv4/IPv6 addresses from the specified interface
#
#  if_flush_addr eth1 [up]
#
if_flush_addr () {
  _rc=0
  if [ $# -ge 1 ]; then
    if [ $# -ge 2 -a "$2" = "up" ]; then
      ifup="up"
    else
      ifup=""
    fi
    intf=$1
    ip -4 addr flush dev $intf $ifup || _rc=$?
    ip -6 addr flush dev $intf $ifup || _rc=$?
  else
    echo 'Usage: if_flush_addr <interface> [up]' 1>&2
    _rc=1
  fi

  return $_rc
}

#
# if_rename: Change interface names
#
#  if_rename eth0 eth0-new
#
if_rename () {
  _rc=0
  if [ $# -ge 2 ]; then
    ip link set $1 down || _rc=$?
    if [ $? -eq 0 ]; then
      ip link set $1 name $2 up || _rc=$?
    fi
  else
    echo 'Usage: if_rename <old_ifname> <new_ifname>' 1>&2
    _rc=1
  fi

  return $?
}

#
# if_get_master: Output the name of the master interface if exists
#
#  if_get_master eth0
#
if_get_master () {
  _rc=0
  if [ $# -ge 1 ]; then
    if ip link show $1 | grep master > /dev/null ; then
      ip link show $1 | head -1 | \
        sed 's/^.* master \(.*\) state .*$/\1/' || _rc=$?
    else
      _rc=1
    fi
  else
    echo 'Usage: if_get_master <interface>' 1>&2
    _rc=1
  fi

  return $_rc
}

#
# if_set_master: add the specified interface to a master interface
#
#  if_set_master br0 eth1 [eth2 ...]
#
if_set_master () {
  if [ $# -lt 2 ]; then
    echo "Usage: if_set_master <master> <interface> [interface ...]" 1>&2
    return 1
  fi
  master="$1"
  shift
  for intf in $*
  do
    ip link set "$intf" master "$master"
  done
}

#
# if_unset_master: Detach the specified interface from its master
#
#  if_unset_master [eth1 ...]
#
if_unset_master () {
  if [ $# -lt 1 ]; then
    echo "Usage: if_unset_master [interface ...]" 1>&2
    return 1
  fi
  for intf in $*
  do
    ip link set "$intf" nomaster
  done
}

#
# if_exists: Return 0 if the interface exists. Returns 1 otherwise
#
#  if_exists eth0
#
if_exists () {
  _rc=1
  if [ $# -ge 1 ]; then
    if ip link show $1 > /dev/null 2>&1 ; then
      _rc=0
    fi
  else
    echo 'Usage: if_exists <interface>' 1>&2
    _rc=1
  fi

  return $_rc
}

#
# if_change: bring an interface up or taking an interface down
#
#  if_change intf <up | down>
#
if_change () {
  _rc=1
  if [ $# -ge 2 ]; then
    if [ $2 = "up" -o $2 = "down" ]; then 
      ip link set dev $1 $2
      _rc=$?
    else
      echo "if_change: ERROR: wrong parameter: $2" 1>&2
    fi
  else
    echo 'Usage: if_change <interface> <up | down>' 1>&2
  fi
  return $_rc
}

#
# if_up: bring an interface up
#
#  if_up interface
#
if_up () {
  _rc=1
  if [ $# -lt 1 ]; then
    echo 'Usage: if_up interface' 1>&2
  else
    if_change $1 up
    _rc=$?
  fi
  return $_rc
}

#
# if_down: take an interface down
#
#  if_down interface
#
if_down () {
  _rc=1
  if [ $# -lt 1 ]; then
    echo 'Usage: if_down interface' 1>&2
  else
    if_change $1 down
    _rc=$?
  fi
  return $_rc
}

#
# vlan_add: Add a VLAN interface
#
#   vlan_add intf vlan_id
#
vlan_add () {
  _rc=1
  if [ $# -ge 2 ]; then
    ip link add link $1 name ${1}.$2 type vlan id $2
    if [ $? -eq 0 ]; then
      ip link set dev ${1}.$2 up
      _rc=$?
    fi
  else
    echo 'Usage: vlan_add <intferface> <vlan_id>' 1>&2
  fi
  return $_rc
}

#
# vlan_del: Delete a VLAN interface
#
#   vlan_del intf vlan_id
#
vlan_del () {
  _rc=1
  if [ $# -ge 2 ]; then
    ip link set dev ${1}.$2 down
    if [ $? -eq 0 ]; then
      ip link delete ${1}.$2
      _rc=$?
    fi
  else
    echo 'Usage: vlan_del <intferface> <vlan_id>' 1>&2
  fi
  return $_rc
}

#
# br_add: Create a kernel bridge
#
#  br_add br1 [br2 ...]
#
br_add () {
  _rc=0
  if [ $# -ge 1 ]; then
    for br in $*
    do
      if ! ip link show "$br" > /dev/null 2>&1 ; then
        if ip link add "$br" type bridge vlan_filtering 1 ; then
          ip link set dev $br up
        else
          _rc=1
          echo "br_add: Error: failed to add bridge $br" 1>&2
        fi
      else
        _rc=1
        echo "br_add: bridge $br already exists" 1>&2
      fi
    done
  else
    _rc=1
    echo "Usage: br_add <bridge> [bridge ...]" 1>&2
  fi

  #
  # Disable bridge iptables
  #
  if [ -f /proc/sys/net/bridge/bridge-nf-call-iptables ]; then
    /bin/echo 0 > /proc/sys/net/bridge/bridge-nf-call-iptables
  fi

  return $_rc
}

#
# br_del: Delete a kernel bridge
#
#  br_del br1
#
br_del () {
  _rc=0
  if [ $# -ge 1 ]; then
    for br in $*
    do
      if ip link show "$br" > /dev/null 2>&1 ; then
        ip link set dev "$br" down
        if ! ip link del "$br" ; then
          _rc=1
          echo "br_del: failed to delete bridge $br" 1>&2
        fi
      else
        _rc=1
        echo "br_del: brige $br does not exist" 1>&2
      fi
    done
  else
    _rc=1
    echo "Usage: br_del <bridge> [bridge ...]" 1>&2
  fi

  return $_rc
}

#
# br_addif: Add an interface to a bridge
#
#  br_addif br1 intf
#
br_addif () {
  _rc=0
  if [ $# -ge 2 ]; then
    ip link set "$2" master "$1" || _rc=1
    if [ $_rc -ne 0 ]; then
        echo "br_addif: Error: failed to add interface $2 to bridge $1" 1>&2
    fi
  else
    echo 'Usage: br_addif <bridge> <interface>' 1>&2
  fi

  return $_rc
}
br_add_if() {
  br_addif $*
}

#
# br_delif: Delete an interface from a bridge
#
#  br_delif br1 intf
#
br_delif () {
  _rc=0
  if [ $# -ge 2 ]; then
    brctl delif "$1" "$2" || _rc=1
    if [ $_rc -ne 0 ]; then
      echo "br_delif: Error: failed to delete intf $2 from bridge $1" 1>&2
    fi
  else
    echo 'Usage: br_delif <bridge> <interface>' 1>&2
  fi

  return $_rc
}
br_del_if () {
  br_delif $*
}

#
# br_set_access_port: Make a bridge interface an access port
#
#  br_set_access_port veth0 1001 [force]
#
br_set_access_port() {
  if [ $# -lt 2 ]; then
    echo "Usage: br_set_access_port intf VLAN_ID" 1>&2
    return 1
  fi
  if ! ip a s $1 | grep master > /dev/null ; then
    echo "br_set_access_port: ERRROR: $1 must belong to a bridge" 1>&2
    return 1
  fi
  #
  # count VLAN_IDs, remove blank lines.
  #
  _n=`bridge vlan show dev $1 | sed -r '/^\s*$/d' | wc -l`
  if [ $# -eq 2 ]; then
    if [ $_n -eq 2 ]; then
      bridge vlan add dev $1 vid $2 pvid untagged
      _rc=$?
    else
      _rc=1
      echo "br_set_access_port: ERROR: already configured" 1>&2
      bridge vlan show dev $1 | sed -r '/^\s*$/d' 1>&2
    fi
  else
    #
    # force to add VLAN_ID
    #
    bridge vlan add dev $1 vid $2 pvid untagged
    _rc=$?
  fi
  return $_rc
}

#
# br_add_vlan_trunk: Add a VLAN to a trunk port
#
#  br_add_vlan_trunk veth0 1001
#
br_add_vlan_trunk() {
  if [ $# -lt 2 ]; then
    echo "Usage: br_add_vlan_trunk intf VLAN_ID" 1>&2
    return 1
  fi
  if ! ip a s $1 | grep master > /dev/null ; then
    echo "br_add_vlan_trunk: ERRROR: $1 must belong to a bridge" 1>&2
    return 1
  fi
  bridge vlan add dev $1 vid $2
}

#
# br_add_native_vlan: Add a native VLAN to a trunk port
#
#  br_add_native_vlan veth0 1001
#
br_add_native_vlan() {
  if [ $# -lt 2 ]; then
    echo "Usage: br_add_native_vlan intf VLAN_ID" 1>&2
    return 1
  fi
  if ! ip link show $1 | grep master > /dev/null ; then
    echo "br_add_native_vlan: ERRROR: $1 must belong to a bridge" 1>&2
    return 1
  fi
  bridge vlan add dev $1 vid $2 pvid untagged
}

#
# br_del_vlan: Remove a VLAN_ID from a bridge interface
#
#  br_del_vlan veth0 1001
#
br_del_vlan() {
  if [ $# -lt 2 ]; then
    echo "Usage: br_del_vlan intf VLAN_ID" 1>&2
    return 1
  fi
  if ! ip link show $1 | grep master > /dev/null ; then
    echo "br_del_vlan: ERRROR: $1 must belong to a bridge" 1>&2
    return 1
  fi
  bridge vlan del vid $2 dev $1
}

#
# pci2if: Convert pci address to interface name
#
#  pci2if 0000:09:00.1
#
pci2if () {
  _rc=0
  if [ $# -ge 1 ]; then
    if ! echo $1 | grep '^[0-9][0-9][0-9][0-9]:' > /dev/null ; then
      prefix="0000:"
    fi
    echo `ls /sys/bus/pci/devices/${prefix}$1/net`
  else
    echo 'Usage: pci2if <0000:01:00.1>' 1>&2
  fi
}

#
# addrFromPrefix: Output IP address from IP prefix. This function works
#                 even if the input has no prefix length.
#
#  addrFromPrefix <prefix>
#
#
addrFromPrefix () {
  if [ $# -lt 1 ]; then
    return 1
  fi
  echo $1 | cut -f 1 -d'/'
}

#
# lenFromPrefix: Output prefix length if the input has a prefix length.
#                Output -1 if unless input has a prefix length.
#
#  lenFromPrefix <prefix>
#
#
lenFromPrefix () {
  if [ $# -lt 1 ]; then
    return 1
  fi
  if echo $1 | grep '/' > /dev/null ; then
    echo $1 | cut -f 2 -d'/'
  else
    echo "-1"
    return 1
  fi
}

#
# changeDir: Go to directory <dir>.
#            Directories are created unless they exist.
#
#  changeDir <dir>
#
#
changeDir () {
  _curDir=`pwd`

  if [ "`echo $1 | cut -c1`" = "/" ]; then
    cd /
  fi
  for _dir in `echo $1 | sed 's@/@ @g'`
  do
    if [ ! -d  $_dir ]; then
      if ! mkdir $_dir ; then
        cd $_curDir
        return 1
      fi
    fi
    cd $_dir
  done

  return 0
}

#
# makeDir: Make directory <dir>. The path <dir> can be relative or absolute.
#          New drirectories are created if necessary.
#
#  makeDir <dir>
#
makeDir () {
  _curDir=`pwd`

  if [ "`echo $1 | cut -c1`" = "/" ]; then
    cd /
  fi
  for _dir in `echo $1 | sed 's@/@ @g'`
  do
    if [ ! -d $_dir ]; then
      if ! mkdir $_dir ; then
        echo "makeDir: ERROR: failed to create $_dir" 1>&2
        cd $_curDir
        return 1
      fi
    fi
    cd $_dir
  done

  cd $_curDir
  return 0
}

#
# prependZero: Prepend 0 if 'num' is between 0 and 9 (e.g., 00, 01, ..., 09)
#              Do nothing otherwise (e.g., 12, 120, etc.)
#
#  prependZero <num>
#
prependZero () {
  if echo $1 | egrep '^[0-9]+' > /dev/null ; then
    _num=`expr $1 + 0`
    if [ $_num -lt 10 ]; then
      echo "0$_num"
    else
      echo $_num
    fi
  else
    echo $1
  fi
}

#
# errExit "message" [code]
#
errExit () {
  _code=1
  case $# in
  0) echo "ERROR:" 1>&2
     ;;
  1) echo "ERROR: $1" 1>&2
     ;;
  *) echo "ERROR: $1" 1>&2
     echo "$2" | grep '^[0-9]*$'  > /dev/null && _code=$2
     ;;
  esac

  exit $_code
}
