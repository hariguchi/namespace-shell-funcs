#!/bin/sh

# errExit <message> [number]
#
errExit () {
  if [ $# -gt 1 ]; then
    _num=$2
  else
    _num=1
  fi
  echo "ERROR: $1" 1>&2
  exit $_num
}

# isRoot
#
isRoot () {
  if [ `whoami` = "root" ]; then
    return 0
  fi
  return 1
}

# use <filename>
#
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

# get_ns_funcs
#
get_ns_funcs () {
  if [ -f /usr/bin/ns-funcs.sh ]; then
    return 0
  fi
  wget https://raw.githubusercontent.com/hariguchi/namespace-shell-funcs/master/ns-funcs.sh
  if [ ! -f ./ns-funcs.sh ]; then
    echo "get_ns-funcs: ERROR: failed to download ns-funcs.sh" 1>&2
    return 1
  fi
  mv ./ns-funcs.sh /usr/bin
}
