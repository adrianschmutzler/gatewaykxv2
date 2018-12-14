#!/bin/bash

if [ "$(/usr/bin/id -u)" -ne 0 ]; then
    echo "Please run as root"
    exit 1
fi

conffile="/etc/hoods/$1.conf"
if [ ! -s "$conffile" ]; then
    echo "Usage: $0 Hoodname ";
    exit 1;
fi

. "$conffile"

words="hoodname
fd43
fd43net
ipv6
ipv6net
ipv4
ipv4net
ipv4netmask
dhcpstart
dhcpend
numaddr
fastdname
iflabel
lat
lon
gwbandwidth
ethernetinterface"

exitcode=0
for w in $words ; do
	if ! grep -q "${w}=" $conffile ; then
		echo "Keyword $w missing!"
		exitcode=1
	fi
done

exit $exitcode

