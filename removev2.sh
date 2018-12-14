#!/bin/bash

if [ "$(/usr/bin/id -u)" -ne 0 ]; then
    echo "Please run as root"
    exit 1
fi

if [ $# -ne "1" ]; then
    echo "Usage: removev2.sh <iflabel>"
    return 1
fi

iflabel="$1"

# Fastd
systemctl stop "fastd-$iflabel"
systemctl disable "fastd-$iflabel"

fastdpath="/etc/fastd/$iflabel"
rm -R "$fastdpath"

fastdsrvfile="/etc/systemd/system/fastd-$iflabel.service"
rm "$fastdsrvfile"

# Interface
iffile="/etc/network/interfaces.d/$iflabel.cfg"
bat="$(grep -m 1 -o "bat[0-9]* " "$iffile")"
ifdown $bat
ip link del $bat
rm "$iffile"

# Apache
a2dissite "$iflabel"

wwwfile="/etc/apache2/sites-available/$iflabel.conf"
wwwfolder="/var/www/$iflabel"

httpport="$(grep "<VirtualHost" "$wwwfile" | sed 's/.*:\([0-9]*\)>/\1/')"
echo "Removing HTTP port $httpport"
[ -n "$httpport" ] && sed -i '/Listen '$httpport'/d' /etc/apache2/ports.conf

rm "$wwwfile"
rm -R "$wwwfolder"

# Cron file
cronfile="/etc/cron.d/$iflabel"
rm "$cronfile"

# Dnsmasq
dhcpfile="/etc/systemd/system/dnsmasq-$iflabel.service"

systemctl stop "dnsmasq-$iflabel.service"
systemctl disable "dnsmasq-$iflabel.service"
rm "$dhcpfile"

# radvd
echo "Radvd needs to be adjusted MANUALLY!"

# Alfred
alfredfile="/etc/systemd/system/alfred-$iflabel.service"

systemctl stop "alfred-$iflabel"
systemctl disable "alfred-$iflabel"
rm "$alfredfile"

# Mrtg
cfgdhcp="/etc/mrtg/dhcp-$iflabel.sh"
cfggwl="/etc/mrtg/gwl-$iflabel.sh"

rm "$cfgdhcp"
rm "$cfggwl"

echo "/etc/mrtg/*.cfg files have to be adjusted MANUALLY!"

echo "Done."
echo "Radvd needs to be adjusted MANUALLY!"
echo "/etc/mrtg/*.cfg files have to be adjusted MANUALLY!"

