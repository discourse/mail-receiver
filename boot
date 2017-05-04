#!/bin/bash

set -e

# First, fire up possibly the world's *worst* syslog server, unless there's
# somewhere else meaningful to send syslog data to
if [ -z "$SYSLOG_SOCKET" ]; then
	/usr/bin/socat UNIX-RECV:/dev/log,mode=0666 stderr &
else
	ln -sf "$SYSLOG_SOCKET" /dev/log
fi

echo "Operating environment:" >&2
env >&2

ruby -rjson -e "File.write('/etc/postfix/mail-receiver-environment.json', ENV.to_hash.to_json)"

if [ -z "$MAIL_DOMAIN" ]; then
	echo "FATAL ERROR: MAIL_DOMAIN env var is not set." >&2
	exit 1
fi

/usr/sbin/postconf -e relay_domains=$MAIL_DOMAIN
rm -f /etc/postfix/transport
for d in $MAIL_DOMAIN; do
	echo "Delivering mail sent to $d to Discourse" >&2
	/bin/echo "$d discourse:" >>/etc/postfix/transport
done
/usr/sbin/postmap /etc/postfix/transport

# Make sure the necessary Discourse connection details are in place
for v in DISCOURSE_BASE_URL DISCOURSE_API_KEY DISCOURSE_API_USERNAME; do
	if [ -z "${!v}" ]; then
		echo "FATAL ERROR: $v env var is not set." >&2
		exit 1
	fi
done

# Generic postfix config setting code... bashers gonna bash.
for envvar in $(compgen -v); do
	if [[ "$envvar" =~ ^POSTCONF_ ]]; then
		varname="${envvar/POSTCONF_/}"
		echo "Setting $varname to '${!envvar}'" >&2
		/usr/sbin/postconf -e $varname="${!envvar}"
	fi
done

# Now, make sure that the Postfix filesystem environment is sane
mkdir -p -m 0755 /var/spool/postfix/pid
chown root:root /var/spool/postfix

/usr/sbin/postfix check >&2

echo "Starting Postfix" >&2

# Finally, let postfix-master do its thing
exec /usr/lib/postfix/master -c /etc/postfix -d
