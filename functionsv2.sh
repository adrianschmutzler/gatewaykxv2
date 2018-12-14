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
echo "#!/bin/bash
/sbin/ifdown \$INTERFACE" > "$basepath/down.sh"
# x setzen
chmod a+x "$basepath/down.sh"
echo "$basepath angelegt"

echo "#!/bin/bash
/sbin/ifup \$INTERFACE
batctl -m $bat gw_mode server 128000
ip6tables -t nat -A PREROUTING -i $bat -p tcp -d fe80::1 --dport 2342 -j REDIRECT --to-port $httpport" > "$basepath/up.sh"
# x setzen
chmod a+x "$basepath/up.sh"
echo "$basepath/up.sh angelegt"

echo "#!/bin/bash
return 0" > "$basepath/verify.sh"
# x setzen
chmod a+x "$basepath/verify.sh"
echo "$basepath/verify.sh angelegt"

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

if [ $# -ne "9" ]; then
	echo "Usage: setupInterface <interface label> <batX> <fastd interface name> <hood name> <ipv4 address> <ipv6 address> <fe80 address> <ipv4 net> <ipv6 net>"
	return 1
fi

local iflabel="$1"
local bat="$2"
local fastdifname="$3"
local hoodname="$4"
local ipv4="$5"
local ipv6="$6"
local fe80="$7"
local ipv4net="$8"
local ipv6net="$9"

local configfile="/etc/network/interfaces.d/$iflabel.cfg"

echo "#device: $bat
iface $bat inet manual
    post-up ip link set dev \$IFACE up
    ##Einschalten post-up:
    # IP des Gateways am B.A.T.M.A.N interface:
    post-up ip addr add $ipv4 dev \$IFACE
    post-up ip -6 addr add fe80::1/64 dev \$IFACE nodad
    post-up ip -6 addr add $ipv6 dev \$IFACE
    post-up ip -6 addr add $fe80 dev \$IFACE
    # Regeln, wann die fff Routing-Tabelle benutzt werden soll:
    post-up ip rule add iif \$IFACE table fff
    post-up ip -6 rule add iif \$IFACE table fff
    # Route in die XXXXXXXX Hood:
    post-up ip route replace $ipv4net dev \$IFACE proto static table fff
    post-up ip -6 route replace $ipv6net dev \$IFACE proto static table fff

    ##Ausschalten post-down:
    # Loeschen von oben definieren Routen, Regeln und Interface:
    post-down ip route del $ipv4net dev \$IFACE table fff
    post-down ip -6 route del $ipv6net dev \$IFACE proto static table fff
    post-down ip rule del iif \$IFACE table fff
    post-down ip link set dev \$IFACE down

# VPN Verbindung in die $hoodname Hood
iface $fastdifname inet manual
    post-up batctl -m $bat if add \$IFACE
    post-up ip link set dev \$IFACE up
    post-up ifup $bat
    post-down ifdown $bat
    post-down ip link set dev \$IFACE down
" > "$configfile"
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

echo "*/5 * * * * root wget \"http://keyserver.freifunk-franken.de/v2/index.php?lat=$lat&long=$lon\" -O /var/www/$iflabel/keyxchangev2data
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

if [ $# -ne "3" ]; then
	echo "Usage: setupFastdConfig <batX> <fe80 address> <ipv6 prefix>"
	return 1
fi

local bat="$1"
local fe80="$2"
local ipv6net="$3"

local configfile="/etc/radvd.conf"

echo "interface $bat {
        AdvSendAdvert on;
        MinRtrAdvInterval 60;
        MaxRtrAdvInterval 300;
        AdvDefaultLifetime 600;
        AdvRASrcAddress {
                ${fe80%/*}; 
        };
        prefix $ipv6net {
                AdvOnLink on;
                AdvAutonomous on;
        };
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

echo "Mache mrtg config neu"
/usr/bin/cfgmaker --output=/etc/mrtg/traffic.cfg  -zero-speed=100000000 --global "WorkDir: /var/www/mrtg" --ifdesc=name,ip,desc,type --ifref=name,desc --global "Options[_]: bits,growright" public@localhost
sed -i -e 's/^\(MaxBytes.*\)$/\10/g' /etc/mrtg/traffic.cfg
/usr/bin/indexmaker --output=/var/www/mrtg/index.html --title="$(hostname)" --sort=name --enumerat /etc/mrtg/traffic.cfg /etc/mrtg/cpu.cfg /etc/mrtg/dhcp.cfg
cat /var/www/mrtg/index.html | sed -e 's/SRC="/SRC="mrtg\//g' -e 's/HREF="/HREF="mrtg\//g' -e 's/<\/H1>/<\/H1><img src="topology.png">/g' > /var/www/index.html
echo "Mrtg config neu gemacht"

return 0

}
