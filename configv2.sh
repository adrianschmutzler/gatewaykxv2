#!/bin/bash

. ./functionsv2.sh

if [ "$(/usr/bin/id -u)" -ne 0 ]; then
    echo "Please run as root"
    exit 1
fi

conffile="/etc/hoods/$1.conf"
if [ ! -s "$conffile" ]; then
    echo "Usage: $0 Hoodname ";
    exit 1;
fi

fastdsecret="$(cat ./fastdsecret)"
if [ -z "$fastdsecret" ]; then
    echo "Error: No fastd secret found!"
    exit 1
fi

. "$conffile"

#fe80 IPv6 holen:
fe80=$(ip -6 addr show $ethernetinterface | grep "inet6 fe80" | grep -v "inet6 fe80::1" | tail -n 1 | cut -d " " -f6)
echo "Wir nutzen folgende fe80 IPv6: $fe80"

if [ -z "$fastdport" ]; then
    fastdport=$fastdportbase
    while grep $fastdport /etc/fastd/*/*.conf* &>/dev/null ; do ((fastdport+=1)); done
    echo "Wir nutzen $fastdport Port für fastd"
    ## $fastdport = port für fastdport
fi

if [ -z "$bat" ]; then
    bat=$batbase
    while grep "bat$bat " /etc/radvd.conf &>/dev/null ; do ((bat+=1)); done
    echo "Wir nutzen $bat Nummer für Batman Interface"
    ## $bat = bat interface
fi

if [ -z "$httpport" ]; then
    httpport=$httpportbase
    while grep $httpport /etc/apache2/sites-available/* &>/dev/null ; do ((httpport+=1)); done
    echo "Wir nutzen $httpport Port für http Server"
    ## $httpport = port für httpserver
fi


#### Configuration ####

batif="bat$bat"
[ -z "$iflabel" ] && iflabel="fff.$batif"

# Network interface - /etc/network/interfaces.d/<iflabel>.cfg
setupInterface "$iflabel" "$batif" "$fe80" "$ipv4" "$ipv4net" "$fd43" "$fd43net" "$ipv6" "$ipv6net"

ifup "$batif"
echo "$batif Interface gestartet"

# Fastd config - /etc/fastd/<iflabel>/...
setupFastdConfig "$iflabel" "$batif" "$fastdname" "$fastdport" "$httpport" "$fastdsecret" "$gwbandwidth"

# Fastd service - /etc/systemd/system/fastd-<iflabel>.service
setupFastdService "$iflabel"

systemctl enable "fastd-$iflabel"
systemctl start "fastd-$iflabel"
echo "fastd Service gestartet und enabled"

# Apache config - /etc/apache2/sites-available/<iflabel>.conf
setupApache "$iflabel" "$httpport"

a2ensite "$iflabel"
systemctl reload apache2
echo "Config für Apache neu geladen und Apache neu gestartet"

# Cronjob für Hoodfile anlegen
setupCronHoodfile "$iflabel" "$lat" "$lon"

# Dnsmasq service - /etc/systemd/system/dnsmasq-<iflabel>.service
setupDnsmasq "$iflabel" "$batif" "$dhcpstart" "$dhcpend" "$ipv4netmask"

systemctl enable "dnsmasq-$iflabel.service"
systemctl start "dnsmasq-$iflabel.service"
echo "dnsmasq enabled und gestartet"

# Radvd config - /etc/radvd.conf
setupRadvd "$batif" "$fe80" "$fd43net" "$ipv6net"

/etc/init.d/radvd restart
echo "radvd neu gestartet"

# Alfred service - /etc/systemd/system/alfred-<iflabel>.service
setupAlfred "$iflabel" "$batif"

systemctl enable "alfred-$iflabel"
systemctl start "alfred-$iflabel"
echo "Alfred Service gestartet und enabled"

# MRTG Config neu machen - /etc/mrtg/dhcp.cfg
setupMrtg "$iflabel" "$batif" "$hoodname" "$numaddr"

echo "Script fertig"
