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

##
## pl2mask <IPv4-prefix-length>
##
pl2mask () {
  local _head
  local _max
  local _n
  local _pl
  local _tail

  if [ $# -lt 1 ]; then
    echo 'Usage: pl2mask <prefix-length>' 1>&2
    return 1
  fi
  _pl=$1
  if [ $_pl -gt 32 ]; then
    return 1
  fi
  if [ $_pl -gt 24 ]; then
    _max=32
    _head='255.255.255.'
  elif [ $_pl -gt 16 ]; then
    _max=24
    _head='255.255.'
    _tail='.0'
  elif [ $_pl -gt 8 ]; then
    _max=16
    _head='255.'
    _tail='.0.0'
  else
    _max=8
    _tail='255.255.0'
  fi
  _n=`echo "256 - 2^(${_max}-${_pl})" | bc`
  if [ $? != 0 ]; then
    return 1
  fi
  echo ${_head}${_n}${_tail}
}

##
## mask2pl <IPv4-netmask>
##
mask2pl () {
  if [ $# -lt 1 ]; then
    echo 'Usage: mask2pl <netmask>' 1>&2
    return 1
  fi
  echo $1 | awk -F'.' '{ \
    if (NF != 4) { \
      print "ERROR: wrong input:" $0 | "cat 1>&2"; exit 1\
    } else {\
      input = $0; \
      if ($1 == 255 && $2 == 255 && $3 == 255) {\
        a = 24; b = $4\
      } else if ($1 == 255 && $2 == 255) {\
        a = 16; b = $3\
      } else if ($1 == 255) {\
        a = 8; b = $2\
      } else {\
        a = 0; b = $1\
      }\
    }\
  } END { \
    if (NR > 1) {\
      print "ERROR: too many lines" | "cat 1>&2"; exit 1\
    }\
    if (b == 255) {\
      print a + 8\
    } else if (b == 254) {\
      print a + 7\
    } else if (b == 252) {\
      print a + 6\
    } else if (b == 248) {\
      print a + 5\
    } else if (b == 240) {\
      print a + 4\
    } else if (b == 224) {\
      print a + 3\
    } else if (b == 192) {\
      print a + 2\
    } else if (b == 128) {\
      print a + 1\
    } else if (b == 0) {\
      print a\
    } else {\
      print "ERROR: wrong input" input | "cat 1>&2" ; exit 1\
    }\
  }'
}
