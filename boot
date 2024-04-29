#!/bin/bash

set -e

# Send syslog messages to stderr, optionally relaying them to another socket
# for postfix-exporter to take a look at
if [ -z "$SOCKETEE_RELAY_SOCKET" ]; then
	/usr/bin/socat UNIX-RECV:/dev/log,mode=0666 stderr &
else
	/usr/local/bin/socketee /dev/log "$SOCKETEE_RELAY_SOCKET" &
fi

echo "Operating environment:" >&2
env >&2

ruby -rjson -e "File.write('/etc/postfix/mail-receiver-environment.json', ENV.to_hash.to_json)"

if [ -z "$MAIL_DOMAIN" ]; then
	echo "FATAL ERROR: MAIL_DOMAIN env var is not set." >&2
	exit 1
fi

/usr/sbin/postconf -e relay_domains="$MAIL_DOMAIN"
rm -f /etc/postfix/transport
for d in $MAIL_DOMAIN; do
	echo "Delivering mail sent to $d to Discourse" >&2
	/bin/echo "$d discourse:" >>/etc/postfix/transport
done
/usr/sbin/postmap /etc/postfix/transport

# Make sure the necessary Discourse connection details are in place
for v in DISCOURSE_API_KEY DISCOURSE_API_USERNAME; do
	if [ -z "${!v}" ]; then
		echo "FATAL ERROR: $v env var is not set." >&2
		exit 1
	fi
done

if [ -z "$DISCOURSE_BASE_URL" ] && [ -z "$DISCOURSE_MAIL_ENDPOINT" ] ; then
	echo "FATAL ERROR: You need to define DISCOURSE_BASE_URL or DISCOURSE_MAIL_ENDPOINT" >&2
	exit 1
fi

# Generic postfix config setting code... bashers gonna bash.
for envvar in $(compgen -v); do
	if [[ "$envvar" =~ ^POSTCONF_ ]]; then
		varname="${envvar/POSTCONF_/}"
		echo "Setting $varname to '${!envvar}'" >&2
		/usr/sbin/postconf -e $varname="${!envvar}"
	fi
done

if [ "$INCLUDE_DMARC" = "true" ]; then
  echo "Starting OpenDKIM..." >&2
  adduser postfix opendkim #ensure postfix is part of opendkim group so it can access the socket
  /usr/sbin/opendkim -x /etc/opendkim.conf

  echo "Starting OpenDMARC..." >&2
  adduser postfix opendmarc #ensure postfix is part of opendmarc group so it can access the socket
  /usr/sbin/opendmarc -c /etc/opendmarc.conf
fi

# Now, make sure that the Postfix filesystem environment is sane
mkdir -p -m 0755 /var/spool/postfix/pid
chown root:root /var/spool/postfix

# Permissions are sensitive for postfix to work correctly; ensure the directory
# permissions are set as expected.
chown --recursive postfix:root /var/spool/postfix/*
[[ -d /var/spool/postfix/maildrop ]] && chown --recursive postfix:postdrop /var/spool/postfix/maildrop
[[ -d /var/spool/postfix/public ]] && chown --recursive postfix:postdrop /var/spool/postfix/public
chown --recursive root:root /var/spool/postfix/pid

/usr/sbin/postfix check >&2

echo "Starting Postfix" >&2

# Finally, let postfix-master do its thing
exec /usr/lib/postfix/sbin/master -c /etc/postfix -d
