FROM debian:bullseye-slim

RUN DEBIAN_FRONTEND=noninteractive apt update \
	&& DEBIAN_FRONTEND=noninteractive apt install -y --no-install-recommends curl perl postfix ruby socat \
	&& DEBIAN_FRONTEND=noninteractive apt -y --purge autoremove \
	&& DEBIAN_FRONTEND=noninteractive apt clean

EXPOSE 25
VOLUME /var/spool/postfix

RUN >/etc/postfix/main.cf \
	&& postconf -e maillog_file=/dev/stdout \
	&& postconf -e smtputf8_enable=no \
	&& postconf -e compatibility_level=2 \
	&& postconf -e export_environment='TZ LANG' \
	&& postconf -e smtpd_banner='ESMTP server' \
	&& postconf -e append_dot_mydomain=no \
	&& postconf -e mydestination=localhost \
	&& postconf -e alias_maps= \
	&& postconf -e mynetworks='127.0.0.0/8 [::1]/128 [fe80::]/64' \
	&& postconf -e transport_maps=hash:/etc/postfix/transport \
	&& postconf -e 'smtpd_recipient_restrictions = check_policy_service unix:private/policy' \
	&& postconf -M -e 'smtp/inet=smtp inet n - n - - smtpd' \
	&& postconf -M -e 'discourse/unix=discourse unix - n n - - pipe user=nobody:nogroup argv=/usr/local/bin/receive-mail ${recipient}' \
	&& postconf -M -e 'policy/unix=policy unix - n n - - spawn user=nobody argv=/usr/local/bin/discourse-smtp-fast-rejection' \
	&& rm -rf /var/spool/postfix/*

COPY receive-mail discourse-smtp-fast-rejection /usr/local/bin/
COPY lib/ /usr/local/lib/site_ruby/
COPY boot /sbin/
COPY fake-pups /pups/bin/pups

RUN curl -sL https://github.com/discourse/socketee/releases/download/v0.0.2/socketee -o /usr/local/bin/socketee \
	&& echo '7cd6df7aeeac0cce35c84e842b3cda5a4c36a301  /usr/local/bin/socketee' | sha1sum -c - \
	&& chmod 0755 /usr/local/bin/socketee

CMD ["/sbin/boot"]
