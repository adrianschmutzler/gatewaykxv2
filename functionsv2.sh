# Bash Syntax

setupFastdConfig() {

if [ $# -ne "6" ]; then
	echo "Usage: setupFastdConfig <interface label> <batX> <fastd interface name> <fastd port> <httpport> <secret>"
	return 1
fi

local iflabel="$1"
local bat="$2"
local fastdifname="$3"
local fastdport="$4"
local httpport="$5"
local secret="$6"

local basepath="/etc/fastd/$iflabel"

mkdir "$basepath"

# down.sh
echo "#!/bin/bash

ip link set dev \$INTERFACE down
" > "$basepath/down.sh"
chmod a+x "$basepath/down.sh"
echo "$basepath angelegt"

# up.sh
echo "#!/bin/bash

ip link set dev \$INTERFACE up
batctl -m $bat if add \$INTERFACE
batctl -m $bat gw_mode server 128000

ip6tables -t nat -A PREROUTING -i $bat -p tcp -d fe80::1 --dport 2342 -j REDIRECT --to-port $httpport
ip6tables -t nat -A PREROUTING -i $bat -p tcp -d fe80::fff:1 --dport 2342 -j REDIRECT --to-port $httpport
" > "$basepath/up.sh"
chmod a+x "$basepath/up.sh"
echo "$basepath/up.sh angelegt"

# verify.sh
echo "#!/bin/bash

return 0
" > "$basepath/verify.sh"
chmod a+x "$basepath/verify.sh"
echo "$basepath/verify.sh angelegt"

# fastd config
echo "# Log warnings and errors to stderr
log level error;

# Log everything to a log file
log to syslog as \"$fastdifname\" level info;

# Set the interface name
interface \"$fastdifname\";

# Disable encryption
method \"null\";

# Bind to a fixed port, IPv4 only
bind any:$fastdport;

# fastd need a key but we don't use them
secret \"$secret\";

# Set the interface MTU for TAP mode with xsalsa20/aes128 over IPv4 with a base MTU of 1492 (PPPoE)
# (see MTU selection documentation)
mtu 1426;

on up \"$basepath/up.sh\";
on down \"$basepath/down.sh\";

secure handshakes no;

on verify \"true\";
" > "$basepath/$iflabel.conf"
echo "$basepath/$iflabel.conf angelegt"

return 0

}

setupInterface() {

if [ $# -lt "7" ] || [ $# -gt "9" ]; then
	echo "Usage: setupInterface <interface label> <batX> <fe80 address> <ipv4 address> <ipv4 net> <fd43 address> <fd43 net> [<ipv6 address> <ipv6 net>]"
	return 1
fi

local iflabel="$1"
local bat="$2"
local fe80="$3"
local ipv4="$4"
local ipv4net="$5"
local fd43="$6"
local fd43net="$7"
local ipv6="$8"
local ipv6net="$9"

local configfile="/etc/network/interfaces.d/$iflabel.cfg"

echo "
auto $bat
iface $bat inet manual
    pre-up ip link add \$IFACE type batadv
    up ip link set dev \$IFACE up

    # IPs
    post-up ip addr add $ipv4 dev \$IFACE
    post-up ip -6 addr add $fe80 dev \$IFACE
    post-up ip -6 addr add fe80::1/64 dev \$IFACE nodad
    post-up ip -6 addr add fe80::fff:1/64 dev \$IFACE nodad
    post-up ip -6 addr add $fd43 dev \$IFACE
    #IPv6Addr#

    # Rules (use fff table)
    post-up ip rule add iif \$IFACE table fff
    post-up ip -6 rule add iif \$IFACE table fff

    # Routes
    post-up ip route replace $ipv4net dev \$IFACE proto static table fff
    post-up ip -6 route replace $fd43net dev \$IFACE proto static table fff
    #IPv6Route#

    # Down
    down ip addr flush dev \$IFACE
    down ip route del $ipv4net dev \$IFACE proto static table fff
    down ip -6 route del $fd43net dev \$IFACE proto static table fff
    #IPv6RouteDel#
    down ip rule del iif \$IFACE table fff
    down ip -6 rule del iif \$IFACE table fff
    down ip link set dev \$IFACE down
    post-down ip link del \$IFACE type batadv

" > "$configfile"
[ -n "$ipv6" ] && sed -i "s=#IPv6Addr#=post-up ip -6 addr add $ipv6 dev \$IFACE=" "$configfile"
[ -n "$ipv6net" ] && sed -i "s=#IPv6Route#=post-up ip -6 route replace $ipv6net dev \$IFACE proto static table fff=" "$configfile"
[ -n "$ipv6net" ] && sed -i "s=#IPv6RouteDel#=down ip -6 route del $ipv6net dev \$IFACE proto static table fff=" "$configfile"
echo "$configfile angelegt"

return 0

}

setupFastdService() {

if [ $# -ne "1" ]; then
	echo "Usage: setupFastdService <interface label>"
	return 1
fi

local iflabel="$1"

local configfile="/etc/systemd/system/fastd-$iflabel.service"

echo "[Unit]
Description=fastd
After=network.target auditd.service

[Service]
ExecStart=/usr/bin/fastd -c /etc/fastd/$iflabel/$iflabel.conf
Type=simple

[Install]
WantedBy=multi-user.target
" > "$configfile"
echo "$configfile angelegt"

return 0

}

setupApache() {

if [ $# -ne "2" ]; then
	echo "Usage: setupApache <interface label> <httpport>"
	return 1
fi

local iflabel="$1"
local httpport="$2"

local configfile="/etc/apache2/sites-available/$iflabel.conf"
local wwwfolder="/var/www/$iflabel"

echo "<VirtualHost *:$httpport>
        ServerAdmin webmaster@localhost
        DocumentRoot /var/www/$iflabel
        ErrorLog \${APACHE_LOG_DIR}/error.log
        CustomLog \${APACHE_LOG_DIR}/access.log combined
</VirtualHost>" > "$configfile"
echo "$configfile angelegt"

#Ordner für Apache Home anlegen
mkdir "$wwwfolder"
echo "$wwwfolder angelegt"

#/etc/apache2/ports.conf

sed -i '4i Listen '$httpport'' /etc/apache2/ports.conf
echo "Port in /etc/apache2/ports.conf erweitert"

echo "adrian-gw1" > "$wwwfolder/gateway"
echo "$wwwfolder/gateway angelegt"

return 0

}

setupCronHoodfile() {

if [ $# -ne "3" ]; then
	echo "Usage: setupCronHoodfile <interface label> <latitude> <longitude>"
	return 1
fi

local iflabel="$1"
local lat="$2"
local lon="$3"

local cronfile="/etc/cron.d/$iflabel"

echo "1-59/5 * * * * root wget \"http://keyserver.freifunk-franken.de/v2/index.php?lat=$lat&long=$lon\" -O /var/www/$iflabel/keyxchangev2data
" > "$cronfile"
echo "Cronjob in $cronfile angelegt"

return 0

}

setupDnsmasq() {

if [ $# -ne "5" ]; then
	echo "Usage: setupFastdConfig <interface label> <batX> <start of range> <end of range> <ipv4 netmask>"
	return 1
fi

local iflabel="$1"
local bat="$2"
local dhcpstart="$3"
local dhcpend="$4"
local ipv4mask="$5"

local configfile="/etc/systemd/system/dnsmasq-$iflabel.service"

echo "[Unit]
Requires=network.target
After=network.target

[Service]
Type=simple
Restart=always
RestartSec=10

ExecStart=/usr/sbin/dnsmasq -k --conf-dir=/etc/dnsmasq.d,*.conf --interface $bat --dhcp-range=$dhcpstart,$dhcpend,$ipv4mask,20m --pid-file=/var/run/dhcp-$iflabel.pid --dhcp-leasefile=/var/lib/misc/$iflabel.leases

[Install]
WantedBy=multi-user.target
" > "$configfile"
echo "$configfile angelegt"

return 0

}

setupRadvd() {

if [ $# -ne "3" ] && [ $# -ne "4" ]; then
	echo "Usage: setupFastdConfig <batX> <fe80 address> <fd43 prefix> [<ipv6 prefix>]"
	return 1
fi

local bat="$1"
local fe80="$2"
local fd43net="$3"
local ipv6net="$4"

local configfile="/etc/radvd.conf"

[ -n "$ipv6net" ] && lifetime=600 || lifetime=0

echo "interface $bat {
        AdvSendAdvert on;
        MinRtrAdvInterval 60;
        MaxRtrAdvInterval 300;
        AdvDefaultLifetime $lifetime;
        AdvRASrcAddress {
                ${fe80%/*}; 
        };
        prefix $fd43net {
                AdvOnLink on;
                AdvAutonomous on;
        };" >> "$configfile"
if [ -n "$ipv6net" ]; then
	echo "
        prefix $ipv6net {
                AdvOnLink on;
                AdvAutonomous on;
        };" >> "$configfile"
fi
echo "
        route fc00::/7 {
        };
};" >> "$configfile"
echo "$configfile erweitert"

return 0

}

setupAlfred() {

if [ $# -ne "2" ]; then
	echo "Usage: setupFastdConfig <interface label> <batX>"
	return 1
fi

local iflabel="$1"
local bat="$2"

local configfile="/etc/systemd/system/alfred-$iflabel.service"

echo "[Unit]
Description=alfred
Wants=fastd-$iflabel.service

[Service]
ExecStart=/usr/sbin/alfred -m -i $bat -b none -u /var/run/alfred-$iflabel.sock
Type=simple
ExecStartPre=/bin/sleep 20

[Install]
WantedBy=multi-user.target
WantedBy=fastd-$iflabel.service" >> "$configfile"
echo "$configfile angelegt"

return 0

}

setupMrtg() {

if [ $# -ne "4" ]; then
	echo "Usage: setupFastdConfig <interface label> <batX> <hood name> <number of addresses>"
	return 1
fi

local iflabel="$1"
local bat="$2"
local hoodname="$3"
local numaddr="$4"

#/etc/mrtg/dhcp.cfg

local cfgdhcp="/etc/mrtg/dhcp-$iflabel.sh"
echo "#!/bin/bash
leasecount=\$(cat /var/lib/misc/$iflabel.leases | wc -l)
echo \"\$leasecount\"
echo \"\$leasecount\"
echo 0
echo 0" > "$cfgdhcp"
chmod +x "$cfgdhcp"
echo "$cfgdhcp angelegt und ausführbar gemacht"

local cfggwl="/etc/mrtg/gwl-$iflabel.sh"
echo "#!/bin/bash
gwlcount=\$(/usr/sbin/batctl -m $bat gwl -H | wc -l)
echo \"\$gwlcount\"
echo \"\$gwlcount\"
echo 0
echo 0" > "$cfggwl"
chmod +x "$cfggwl"
echo "$cfggwl angelegt und ausführbar gemacht"

echo "
WorkDir: /var/www/mrtg
Title[dhcpleasecount$bat]: DHCP-Leases
PageTop[dhcpleasecount$bat]: <H1>DHCP-Leases $iflabel $bat $hoodname</H1>
Options[dhcpleasecount$bat]: gauge,nopercent,growright,noinfo
Target[dhcpleasecount$bat]: \`$cfgdhcp\`
MaxBytes[dhcpleasecount$bat]: $numaddr
YLegend[dhcpleasecount$bat]: DHCP Count
ShortLegend[dhcpleasecount$bat]: x
Unscaled[dhcpleasecount$bat]: ymwd
LegendI[dhcpleasecount$bat]: Count
LegendO[dhcpleasecount$bat]:

WorkDir: /var/www/mrtg
Title[gwlleasecount$bat]: Gatewayanzahl
PageTop[gwlleasecount$bat]: <H1>Gatewayanzahl $iflabel $bat $hoodname</H1>
Options[gwlleasecount$bat]: gauge,nopercent,growright,noinfo
Target[gwlleasecount$bat]: \`$cfggwl\`
MaxBytes[gwlleasecount$bat]: 3
YLegend[gwlleasecount$bat]: Gateway Count
ShortLegend[gwlleasecount$bat]: x
Unscaled[gwlleasecount$bat]: ymwd
LegendI[gwlleasecount$bat]: Count
LegendO[gwlleasecount$bat]:" >> /etc/mrtg/dhcp.cfg
echo "/etc/mrtg/dhcp.cfg erweitert"

#echo "Mache mrtg config neu"
#/usr/bin/cfgmaker --output=/etc/mrtg/traffic.cfg  -zero-speed=100000000 --global "WorkDir: /var/www/mrtg" --ifdesc=name,ip,desc,type --ifref=name,desc --global "Options[_]: bits,growright" public@localhost
sed -i -e 's/^\(MaxBytes.*\)$/\10/g' /etc/mrtg/traffic.cfg
#/usr/bin/indexmaker --output=/var/www/mrtg/index.html --title="$(hostname)" --sort=name --enumerat /etc/mrtg/traffic.cfg /etc/mrtg/cpu.cfg /etc/mrtg/dhcp.cfg
#echo "Mrtg config neu gemacht"

return 0

}
