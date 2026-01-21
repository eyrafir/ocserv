#!/bin/bash

OCSERV_CONF="/etc/ocserv/ocserv.conf"

# Create init config
if [[ ! -f $OCSERV_CONF ]]; then
	cat > $OCSERV_CONF <<- EOCONF
	# authentication via linux user
	# auth = pam

	# authentication via passwd file
	auth = "plain[passwd=/etc/ocserv/ocpasswd]"

	tcp-port = 443
	udp-port = 443

	run-as-user = nobody
	run-as-group = daemon
	socket-file = /var/run/ocserv-socket

	max-clients = 100
	max-same-clients = 0

	# TLS priorities settings, use '-' to ban a cipher
	tls-priorities = "NORMAL:%SERVER_PRECEDENCE:%COMPAT:-RSA:-ARCFOUR-128:-VERS-SSL3.0:-VERS-TLS1.0:-VERS-TLS1.1:-VERS-TLS1.2"

	# This option requires the established DTLS channel to use the same cipher as
	# the primary TLS channel. Note, that this option implies that the
	# dtls-legacy option is false, and this option cannot be enforced in the
	# leagcy/compat protocol
	match-tls-dtls-ciphers = true

	# Change below to true and change match-tls-dtls-cipers to false if you want to
	# support old version cisco clients
	dtls-legacy = false
	cisco-client-compat = false

	# tun device name
	device = vpns

	# Prior to leasing any IP from the pool ping it to verify that
	# it is not in use by another (unrelated to this server) host.
	# Only set to true, if there can be occupied addresses in the
	# IP range for leases.
	ping-leases = false

	# The pool of addresses that leases will be given from. If the leases
	# are given via Radius, or via the explicit-ip? per-user config option then
	# these network values should contain a network with at least a single
	# address that will remain under the full control of ocserv (that is
	# to be able to assign the local part of the tun device address).
	# Note that, you could use addresses from a subnet of your LAN network if you
	# enable [proxy arp in the LAN interface](http://ocserv.openconnect-vpn.net/recipes-ocserv-pseudo-bridge.html);
	ipv4-network = 10.255.189.0/24
	ipv4-netmask = 255.255.255.0
	route = default
	tunnel-all-dns = true

	dns = 8.8.8.8
	dns = 1.1.1.1

	# custom config file must as same as username or groupname
	config-per-user = /etc/ocserv/config-per-user/
	config-per-group = /etc/ocserv/config-per-group/

	# IP stays the same for the same user when possible
	predictable-ips = true

	# dead peer detection and keepalive in seconds
	keepalive = 290
	dpd = 90
	mobile-dpd = 1800
	switch-to-tcp-timeout = 25
	try-mtu-discovery = true

	# Uncomment if you are using haproxy
	# listen-proxy-proto = true

	# Uncomment to enable compression negotiation (LZS, LZ4) and set minimum
	# under a packet will not be compressed.
	# Compression is designed to save bandwidth, but it can be bring a little latency.
	# The default size is 256 bytes, to avoid latency for VoIP packets.
	# Modify it if the clients typically use compression as well of VoIP with codecs
	# that exceed the default value.
	# compression = true
	# no-compress-limit = 256

	# Enable camouflage feature that make vpn service look like a web server.
	# Connection to the vpn can be established only if the client provided a specific secret string,
	# other wise the server will return HTTP error for all requests.
	camouflage = true

	# The URL prefix that should be set on the client (after '?' sign) to pass through the camouflage check,
	# e.g. in case of 'mysecretkey', the server URL on the client should be like "https://example.com/?mysecretkey".
	camouflage_secret = "thegreatwall"

	# Defines the realm (browser prompt) for HTTP authentication.
	# If no realm is set, the server will return 404 Not found error instead of 401 Unauthorized.
	# Better change it from the default value to avoid fingerprinting.
	camouflage_realm = "Restricted Content"

	# enable occtl tool
	use-occtl = true

	# default 0/2 info leavel, 1 basic, 3 debug, 4 http, 8 sensitive, 9 tls
	log-level = 1
	EOCONF

fi

#mkdir -p /etc/ocserv/


# Create random initial user if no PAM user file is provided
if [[ ! -f "/etc/ocserv/ocpasswd" ]]; then

	if [[ -z $USERNAME ]] && [[ -z $PASSWORD ]]; then
		# Create specific user
		USERNAME='test'
		PASSWORD=$(openssl rand -base64 14)
	fi

	echo $PASSWORD | echo $PASSWORD | ocpasswd $USERNAME

	echo $PASSWORD > $HOME/initial_pass.txt
	echo '----------------- User Generated ------------------'
	echo "User: $USERNAME"
	echo "Pass: $PASSWORD"
	echo '---------------------------------------------------'

fi


iptables -A FORWARD -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu

# Enable TUN device
mkdir -p /dev/net
mknod /dev/net/tun c 10 200
chmod 600 /dev/net/tun

# Run OpennConnect Server
exec "$@"
