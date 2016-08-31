FROM ruby:2.3-alpine

RUN apk update \
	&& apk add postfix socat bash \
	&& rm -f /var/cache/apk/*

EXPOSE 25
VOLUME /var/spool/postfix

RUN >/etc/postfix/main.cf \
	&& postconf -e smtputf8_enable=no \
	&& postconf -e compatibility_level=2 \
	&& postconf -e export_environment='TZ LANG' \
	&& postconf -e smtpd_banner='ESMTP server' \
	&& postconf -e append_dot_mydomain=no \
	&& postconf -e mydestination=localhost \
	&& postconf -e alias_maps= \
	&& postconf -e mynetworks='127.0.0.0/8 [::1]/128 [fe80::]/64' \
	&& postconf -e transport_maps=hash:/etc/postfix/transport \
	&& postconf -M -e 'discourse/unix=discourse unix - n n - - pipe user=nobody:nogroup argv=/usr/local/bin/receive-mail ${recipient}' \
	&& rm -rf /var/spool/postfix/*

COPY receive-mail /usr/local/bin/
COPY boot /sbin/
COPY fake-pups /pups/bin/pups

CMD ["/sbin/boot"]
