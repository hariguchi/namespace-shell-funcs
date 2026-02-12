#!/bin/sh
#
# netlib.sh: shell functions for networking
#


##
## errExit <message> [number]
##
errExit () {
  if [ $# -gt 1 ]; then
    _num=$2
  else
    _num=1
  fi
  echo "ERROR: $1" 1>&2
  exit $_num
}

##
## isRoot
##
isRoot () {
  if [ `whoami` = "root" ]; then
    return 0
  fi
  return 1
}

##
## use <filename>
##
use () {
  if [ $# -lt 1 ]; then
    return 1
  fi
  _paths=`echo $PATH | sed 's/:/ /g'`
  _paths=". $_paths"
  for _path in $_paths
  do
    if [ -f "${_path}/$1" ]; then
      . "${_path}/$1"
      return 0
    fi
  done
  echo "ERROR: use: no such file: $1" 1>&2
  return 1
}

##
## get_ns-funcs
##
get_ns_funcs () {
  if [ -f /usr/bin/ns-funcs.sh ]; then
    return 0
  fi
  echo "get_ns_funcs 2"
  wget https://raw.githubusercontent.com/hariguchi/namespace-shell-funcs/master/ns-funcs.sh
  if [ ! -f ./ns-funcs.sh ]; then
    echo "get_ns-funcs: ERROR: failed to download ns-funcs.sh" 1>&2
    return 1
  fi
  mv ./ns-funcs.sh /usr/bin
}

##
## nat_add <add|in> chain src intf
##
nat_add() {
  if [ $# -lt 4 ]; then
    echo "Usage: nat_add <add|in> chain src_prefix intf" 1>&2
    return 1
  fi
  #
  # check if already exists
  #
  _cmd="iptables --table nat"
  _str="A $1 -o $3 -j MASQUERADE"
  if $_cmd -S $1  2> /dev/null | grep _str > /dev/null 2>&1 ; then
    return 1
  fi
  case $1 in
    add*) op="-A"
          ;;
    in*)  op="-I"
          ;;
    *)    echo "snat_add: ERROR: wrong 1st prameter: $1" 1>&2
          return 1
          ;;
  esac
  iptables -t nat -N $2
  iptables -t nat $op POSTROUTING -s $3 ! -d $3 -j $2
  iptables -t nat $op $2 --out-interface $4 -j MASQUERADE
}

##
## snat_add <in|add> src-prefix out-intf reflexive-info
##
snat_add() {
  if [ $# -lt 4 ]; then
    echo "Usage: snat_add <in|add> src_prefix out-intf reflexive-info" 1>&2
    echo "  Reflexive examples: 1.2.3.4-1.2.3.6, 1.2.3.4:1-1023" 1>&2
    return 1
  fi
  #
  # check if already exists
  #
  _cmd="iptables --table nat"
  _str="POSTROUTING -s $2 ! -d $2 -o $3 -j SNAT --to-source $4"
  if $_cmd -S 2> /dev/null | grep _str > /dev/null 2>&1 ; then
    return 1
  fi
  case $1 in
    add*) op="-A"
          ;;
    in*)  op="-I"
          ;;
    *)    echo "snat_add: ERROR: wrong 1st prameter: $1" 1>&2
          return 1
          ;;
  esac
  $_cmd $op $_str
}

# nat_del chain src
#
nat_del() {
  if [ $# -lt 2 ]; then
    echo "Usage: ns_nat_del chain src_prefix" 1>&2
    return 1
  fi
  iptables -t nat -D POSTROUTING -s $2 ! -d $2 -j $1
  iptables -t nat -F $1
  iptables -t nat -X $1
}

##
## snat_del src-prefix out-intf reflexive-info
##
snat_del() {
  if [ $# -lt 3 ]; then
    echo "Usage: snat_del src_prefix out-intf reflexive-info" 1>&2
    echo "  Reflexive examples: 1.2.3.4-1.2.3.6, 1.2.3.4:1-1023" 1>&2
    return 1
  fi
  _cmd="iptables --table nat"
  _str="POSTROUTING -s $1 ! -d $1 -o $2 -j SNAT --to-source $3"
  $_cmd -D $_str
}

##
## nat <add|del|insert> chain src [interface]
##

##
## itoV4 base offset
##
itoV4 () {
  if [ $# -lt 2 ]; then
    echo "itoV4: ERROR: too few parameters" 1>&2
    return 1
  fi
  _addr=`expr $1 + $2`
  _1=`expr $_addr / 16777216`
  _tmp=`expr 16777216 \* $_1`
  _addr=`expr $_addr - $_tmp`
  _2=`expr $_addr / 65536`
  _tmp=`expr 65536 \* $_2`
  _addr=`expr $_addr - $_tmp`
  _3=`expr $_addr / 256`
  _tmp=`expr 256 \* $_3`
  _4=`expr $_addr - $_tmp`
  echo "$_1.$_2.$_3.$_4"
}

##
## v4toInt IPv4-addr
##
v4toInt () {
  if [ $# -lt 1 ]; then
    echo "v4toInt: ERROR: need a parameter" 1>&2
    return 1
  fi
  _1=`echo $1 | cut -d . -f 1`
  _2=`echo $1 | cut -d . -f 2`
  _3=`echo $1 | cut -d . -f 3`
  _4=`echo $1 | cut -d . -f 4`
  echo `expr \( 16777216 \* $_1 \) + \( 65536 \* $_2 \) + \( 256 \* $_3 \) + $_4`
}
