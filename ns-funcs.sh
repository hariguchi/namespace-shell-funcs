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
  rc=0
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
        ip netns del $ns || rc=$?
        sleep 1
      fi
      echo "adding $ns"
      ip netns add $ns || rc=$?
    done
  else
    for ns in $*
    do
      if [ -f /var/run/netns/$ns ]; then
        echo "namespace $ns already exists" 1>&2
      else
        echo "adding $ns"
        ip netns add $ns || rc=$?
      fi
    done
  fi
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
    echo 'Usage: ns_add_if <namespace> <interface>' 1>&2
    rc=1
  fi

  return $rc
}

#
# ns_del_if: Delete an interface from namespace
#
#  ns_del_if ns1 eth1
#
ns_del_if () {
  rc=0
  if [ $# -ge 2 ]; then
    ns=$1
    intf=$2
    ip netns exec $ns ip link set $2 netns 1 || rc=$?
  else
    echo 'Usage: ns_del_if <namespace> <interface>' 1>&2
    rc=1
  fi

  return $rc
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
  rc=0
  vrf="$1"
  tid="$2"
  if ! ip link show $vrf > /dev/null 2>&1 ; then
    ip link add $vrf type vrf table $tid || rc=$?
    ip link set dev $vrf up || rc=$?
  fi
  return $rc
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
  rc=0
  vrf="$1"
  if ip link show $vrf > /dev/null 2>&1 ; then
    ip link del $vrf || rc=$?
  else
    echo "vrf_del: no such VRF: $vrf" 1>&2
    rc=1
  fi
  return $rc
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
  rc=0
  if [ $# -lt 1 ]; then
    ip $_opt link show type vrf || rc=$?
  else
    ip $_opt link show master $1 || rc=$?
  fi
  return $rc
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
    ip $_opt link show master $1 || rc=$?
  else
    echo "Usage: vrf_show_addr [-b] [-d] [-h] <vrf>" 1>&2
    rc=1
  fi
  return $rc
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
  rc=0
  vrf="$1"
  intf="$2"
  if [ `ip link show type vrf $vrf | wc -l` -eq 0 ]; then
    echo "vrf_add_if: ERROR: no such vrf: $vrf" 1>&2
    return 1
  fi
  if ip link show $intf > /dev/null 2>&1 ; then
    ip link set dev $intf master $vrf up || rc=$?
  else
    echo "vrf_add_if: ERROR: no such interface: $intf" 1>&2
    rc=1
  fi
  return $rc
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
  rc=0
  if ip link show $1 > /dev/null 2>&1 ; then
    ip link set dev $1 nomaster || rc=$?
  else
    echo "vrf_del_if: ERROR: no such interface: $1" 1>&2
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
    echo 'Usage: vif_add <veth1> <veth2>' 1>&2
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
      echo "vif_del(): Error: $1 does not exist" 1>&2
    fi
  else
    echo 'Usage: vif_del <veth>' 1>&2
    rc=1
  fi

  return $rc
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
  rc=0
  if [ $# -ge 2 ]; then
    if1="${1}-${2}"
    if2="${2}-${1}"
    vif_add "$if1" "$if2" || rc=$?
  else
    echo 'Usage: vif_add_pair <interface1> <interface2>' 1>&2
    return 1
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
    echo 'Usage: vif_peer_index <veth>' 1>&2
    return 1
  fi
  _out=`ethtool -S $1 2> /dev/null`
  if [ $? -eq 0 ]; then
      echo $_out | sed 's/^.*peer_ifindex: //'
  fi
  return $rc
}

#
# ns_add_ifaddr: Attach an IPv4/IPv6 address to
#                the specified interface and namespace
#
#  ns_add_ifaddr ns1 eth1 2001:0:0:1::1/64 8192
#
ns_add_ifaddr () {
  rc=0
  if [ $# -lt 3 ]; then 
    echo 'Usage: ns_add_ifaddr <namespace> <interface> <IP-address> [mtu]' 1>&2
    return 1
  fi

  ns=$1
  intf=$2
  ipa=$3
  if [ $# -ge 4 ]; then
    mtu="mtu $4"
    #ip netns exec $ns ip link set dev $intf mtu $4 || rc=$?
  fi
  ip netns exec $ns ip addr add $ipa dev $intf || rc=$?
  ip netns exec $ns ip link set dev $intf up $mtu || rc=$?

  return $rc
}

#
# ns_del_ifaddr: Detach an IPv4/IPv6 address from
#                the specified interface and namespace
#
#  ns_del_ifaddr ns1 eth1 2001:0:0:1::1/64
#
ns_del_ifaddr () {
  rc=0
  if [ $# -lt 3 ]; then 
    echo 'Usage: ns_del_ifaddr <namespace> <interface> <IP-address>' 1>&2
    return 1
  fi

  ns=$1
  intf=$2
  ipa=$3
  ip netns exec $ns ip addr del $ipa dev $intf || rc=$?

  return $rc
}

#
# ns_flush_ifaddr: Delete all IPv4/IPv6 addresses from
#                the interface in the specified namespace
#
#  ns_flush_ifaddr ns1 eth1 [up]
#
ns_flush_ifaddr () {
  rc=0
  if [ $# -ge 2 ]; then
    if [ $# -ge 2 -a "$2" = "up" ]; then
      ifup="up"
    else
      ifup=""
    fi
    ns=$1
    intf=$2
    ip netns exec $ns ip -4 addr flush dev $intf $ifup || rc=$?
    ip netns exec $ns ip -6 addr flush dev $intf $ifup || rc=$?
  else
    echo 'Usage: ns_flush_ifaddr <namespace> <interface> [up]' 1>&2
    rc=1
  fi

  return $rc
}

# ns_exec: Execute a command in the specified namespace
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
    echo 'Usage: ns_exec <namespace> <command> [...]' 1>&2
    rc=1
  fi

  return $rc
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
  rc=0
  if [ $# -ge 1 ]; then
    ns=$1
    shift
    if [ $# -ge 1 ]; then
      shell=$1
    else
      shell=$SHELL
    fi
    ip netns exec $ns $shell || rc=$?
  else
    echo 'ns_runsh: Usage: ns_runsh <namespace> [shell]' 1>&2
    rc=1
  fi

  return $rc
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
# add_ifaddr: Attach an IPv4/IPv6 address to the specified interface
#
#  add_ifaddr eth1 2001:0:0:1::1/64 8192
#
add_ifaddr () {
  rc=0
  if [ $# -lt 2 ]; then 
    echo 'Usage: add_ifaddr <interface> <IP-address> [mtu]' 1>&2
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
    ip link set dev $intf mtu $3 || rc=$?
  fi
  ip addr add $ipa dev $intf || rc=$?

  return $rc
}

#
# flush_ifaddr: Delete all IPv4/IPv6 addresses from the specified interface
#
#  flush_ifaddr eth1 [up]
#
flush_ifaddr () {
  rc=0
  if [ $# -ge 1 ]; then
    if [ $# -ge 2 -a "$2" = "up" ]; then
      ifup="up"
    else
      ifup=""
    fi
    intf=$1
    ip -4 addr flush dev $intf $ifup || rc=$?
    ip -6 addr flush dev $intf $ifup || rc=$?
  else
    echo 'Usage: flush_ifaddr <interface> [up]' 1>&2
    rc=1
  fi

  return $rc
}

#
# if_rename: Change interface names
#
#  if_rename eth0 eth0-new
#
if_rename () {
  rc=0
  if [ $# -ge 2 ]; then
    ip link set $1 down || rc=$?
    if [ $? -eq 0 ]; then
      ip link set $1 name $2 up || rc=$?
    fi
  else
    echo 'Usage: if_rename <old_ifname> <new_ifname>' 1>&2
    rc=1
  fi

  return $?
}

#
# if_get_master: Output the name of the master interface if exists
#
#  if_get_master eth0
#
if_get_master () {
  rc=0
  if [ $# -ge 1 ]; then
    if ip link show $1 | grep master > /dev/null ; then
      ip link show $1 | head -1 | \
        sed 's/^.* master \(.*\) state .*$/\1/' || rc=$?
    else
      rc=1
    fi
  else
    echo 'Usage: if_get_master <interface>' 1>&2
    rc=1
  fi

  return $rc
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
  rc=1
  if [ $# -ge 1 ]; then
    if ip link show $1 > /dev/null 2>&1 ; then
      rc=0
    fi
  else
    echo 'Usage: if_exists <interface>' 1>&2
    rc=1
  fi

  return $rc
}

#
# br_add: Create a kernel bridge
#
#  br_add br1 [br2 ...]
#
br_add () {
  rc=0
  if [ $# -ge 1 ]; then
    for br in $*
    do
      if ! ip link show "$br" > /dev/null 2>&1 ; then
        if brctl addbr "$br" ; then
          ifconfig $br up
        else
          rc=1
          echo "br_add: Error: failed to add bridge $br" 1>&2
        fi
      else
        rc=1
        echo "br_add: bridge $br already exists" 1>&2
      fi
    done
  else
    rc=1
    echo "Usage: br_add <bridge> [bridge ...]" 1>&2
  fi

  #
  # Disable bridge iptables
  #
  if [ -f /proc/sys/net/bridge/bridge-nf-call-iptables ]; then
    /bin/echo 0 > /proc/sys/net/bridge/bridge-nf-call-iptables
  fi

  return $rc
}

#
# br_del: Delete a kernel bridge
#
#  br_del br1
#
br_del () {
  rc=0
  if [ $# -ge 1 ]; then
    for br in $*
    do
      if ip link show "$br" > /dev/null 2>&1 ; then
        ifconfig "$br" down
        if ! brctl delbr "$br" ; then
          rc=1
          echo "br_del: failed to delete bridge $br" 1>&2
        fi
      else
        rc=1
        echo "br_del: brige $br does not exist" 1>&2
      fi
    done
  else
    rc=1
    echo "Usage: br_del <bridge> [bridge ...]" 1>&2
  fi

  return $rc
}

#
# br_add_if: Add an interface to a bridge
#
#  br_add_if br1 intf
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
    echo 'Usage: br_addif <bridge> <interface>' 1>&2
  fi

  return $rc
}
br_add_if() {
  br_addif $*
}

#
# br_del_if: Delete an interface from a bridge
#
#  br_del_if br1 intf
#
br_delif () {
  rc=0
  if [ $# -ge 2 ]; then
    brctl delif "$1" "$2" || rc=1
    if [ $rc -ne 0 ]; then
      echo "br_delif(): Error: failed to delete intf $2 from bridge $1" 1>&2
    fi
  else
    echo 'Usage: br_delif <bridge> <interface>' 1>&2
  fi

  return $rc
}
br_del_if () {
  br_delif $*
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

