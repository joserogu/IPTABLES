# Limpiamos las tablas
iptables -F
iptables -t nat -F
iptables -Z
iptables -t nat -Z
# Establecemos la política
iptables -P INPUT DROP
iptables -P OUTPUT DROP
iptables -P FORWARD DROP
# Reglas de INPUT y OUTPUT
iptables -A OUTPUT -o eth1 -p icmp -m icmp --icmp-type echo-request -j ACCEPT
iptables -A INPUT -i eth1 -p icmp -m icmp --icmp-type echo-reply -j ACCEPT
iptables -A INPUT -i eth2 -p icmp -s 192.168.100.0/24 -j ACCEPT
iptables -A OUTPUT -o eth2 -p icmp -d 192.168.100.0/24 -j ACCEPT
iptables -A INPUT -i eth0 -p icmp -s 192.168.200.0/24 -j ACCEPT
iptables -A OUTPUT -o eth0 -p icmp -d 192.168.200.0/24 -j ACCEPT

# Nuevas cadenas
iptables -N LAN_A_INTERNET
iptables -N INTERNET_A_LAN
iptables -N A_DMZ
iptables -N DESDE_DMZ
iptables -N DMZ_A_INTERNET
iptables -N INTERNET_A_DMZ
iptables -N LAN_A_DMZ
iptables -N DMZ_A_LAN

# Enviamos todas las peticiones de la LAN a Internet a la cadena
# LAN_A_INTERNET
iptables -A FORWARD -i eth2 -o eth1 -s 192.168.100.0/24 -m state \
--state NEW,ESTABLISHED -j LAN_A_INTERNET
# Enviamos todas las respuestas de Internet de las peticiones hechas
# desde la LAN a la cadena INTERNET_A_LAN
iptables -A FORWARD -o eth2 -i br0 -d 192.168.100.0/24 -m state \
--state ESTABLISHED -j INTERNET_A_LAN
# Reglas de LAN_A_INTERNET
iptables -A LAN_A_INTERNET  -p udp --dport 53 -j ACCEPT
iptables -A LAN_A_INTERNET -p tcp --dport 80 -j ACCEPT
iptables -A LAN_A_INTERNET -p tcp --dport 443 -j ACCEPT
# Reglas de INTERNET_A_LAN
iptables -A LAN_A_INTERNET  -p udp --sport 53 -j ACCEPT
iptables -A LAN_A_INTERNET -p tcp --sport 80 -j ACCEPT
iptables -A LAN_A_INTERNET -p tcp --sport 443 -j ACCEPT
# Limite de peticiones simultáneas desde Internet
iptables -A FORWARD -i eth1 -o virbr2 -p tcp --syn --dport 25 \
-m connlimit --connlimit-above 2 -j REJECT --reject-with tcp-reset
iptables -A FORWARD -i eth1 -o virbr2 -p tcp --syn --dport 80 \
-m connlimit --connlimit-above 15 -j REJECT --reject-with tcp-reset
iptables -A FORWARD -i eth1 -o virbr2 -p tcp --syn --dport 443 \
-m connlimit --connlimit-above 15 -j REJECT --reject-with tcp-reset
# Peticiones desde Internet o LAN a servicios de la DMZ:
iptables -A FORWARD -o eth0 -d 192.168.200.0/24 -m state \
--state NEW,ESTABLISHED -j A_DMZ
# Servicios accesibles en la LAN
iptables -A A_DMZ -p tcp --dport 25 -j ACCEPT
iptables -A A_DMZ -p tcp --dport 80 -j ACCEPT
iptables -A A_DMZ -p tcp --dport 443 -j ACCEPT
# Respuestas desde la DMZ a las peticiones desde Internet o LAN
iptables -A FORWARD -i eth0 -s 192.168.200.0/24 -m state \
--state ESTABLISHED -j DESDE_DMZ
# Servicios accesibles en la DMZ
iptables -A DESDE_DMZ -p tcp --sport 25 -j ACCEPT
iptables -A DESDE_DMZ -p tcp --sport 80 -j ACCEPT
iptables -A DESDE_DMZ -p tcp --sport 443 -j ACCEPT
# Acceso entre las 12:00 y las 12:30 de la DMZ a Internet
iptables -A FORWARD -i eth0 -o eth1 -s 192.168.200.0/24 \
-m time --timestart 12:00 --timestop 12:30 -m state --state \
NEW,ESTABLISHED -j DMZ_A_INTERNET
# De la DMZ a Internet
iptables -A DMZ_A_INTERNET -p udp --dport 53 -j ACCEPT
iptables -A DMZ_A_INTERNET -p tcp --dport 80 -j ACCEPT
iptables -A DMZ_A_INTERNET -p tcp --dport 443 -j ACCEPT
# Respuestas entre las 12:00 y las 12:30 de Internet a DMZ
iptables -A FORWARD -o eth0 -i eth1 -d 192.168.200.0/24 \
-m time --timestart 12:00 --timestop 12:30 -m state \
--state ESTABLISHED -j INTERNET_A_DMZ
# De Internet a DMZ
iptables -A INTERNET_A_DMZ -p udp --dport 53 -j ACCEPT
iptables -A INTERNET_A_DMZ -p tcp --dport 80 -j ACCEPT
iptables -A INTERNET_A_DMZ -p tcp --dport 443 -j ACCEPT
# Peticiones y respuestas de la LAN a DMZ
iptables -A FORWARD -i virbr1 -o virbr2 -s 192.168.100.0/24 \
-d 192.168.200.0/24 -m state --state NEW,ESTABLISHED -j LAN_A_DMZ
# De la LAN a LA DMZ
iptables -A LAN_A_DMZ -p icmp -m icmp --icmp-type echo-request -j ACCEPT
iptables -A LAN_A_DMZ -p icmp -m icmp --icmp-type echo-reply -j ACCEPT
iptables -A LAN_A_DMZ -p tcp --sport 3306 -j ACCEPT
# Peticiones y respuestas de la DMZ a la LAN
iptables -A FORWARD -o eth2 -i eth1 -d 192.168.100.0/24 \
-s 192.168.200.0/24 -m state --state NEW,ESTABLISHED -j DMZ_A_LAN
# De la DMZ a la LAN
iptables -A DMZ_A_LAN -p icmp -m icmp --icmp-type echo-request -j ACCEPT
iptables -A DMZ_A_LAN -p icmp -m icmp --icmp-type echo-reply -j ACCEPT
iptables -A DMZ_A_LAN -p tcp --dport 3306 -j ACCEPT

# Añadimos aquí las reglas de NAT
iptables -t nat -A POSTROUTING -s 192.168.100.0/24 -o eth1 -j MASQUERADE
iptables -t nat -A POSTROUTING -s 192.168.200.0/24 -o eth1 -m time \
--timestart 12:00 --timestop 12:30 -j MASQUERADE
iptables -t nat -A PREROUTING -i eth1 -p tcp --dport 80 -j DNAT --to 192.168.200.2
iptables -t nat -A PREROUTING -i eth1 -p tcp --dport 443 -j DNAT --to 192.168.200.2
iptables -t nat -A PREROUTING -i eth1 -p tcp --dport 25 -j DNAT --to 192.168.200.2
