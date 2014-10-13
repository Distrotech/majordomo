#! /bin/sh
PATH=/bin:/usr/bin
IFS="	 "

if [ -d /sys/node_data ]; then
	arch="DomainOS"
  else
	arch=`arch`
fi

exec $0.${arch} "$@"

# $Header: /sources/cvsrepos/majordomo/wrapper.sh,v 1.4 1994/05/09 17:41:29 rouilj Exp $
