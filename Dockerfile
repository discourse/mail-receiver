FROM debian:bullseye-slim

ARG INCLUDE_DMARC=true
ENV INCLUDE_DMARC=${INCLUDE_DMARC}

RUN DEBIAN_FRONTEND=noninteractive apt update \
	&& DEBIAN_FRONTEND=noninteractive apt install -y --no-install-recommends curl perl postfix ruby socat \
    && if [ "$INCLUDE_DMARC" = "true" ]; then \
         DEBIAN_FRONTEND=noninteractive apt install -y --no-install-recommends opendmarc opendkim opendkim-tools postfix-policyd-spf-python; \
       fi \
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
	&& if [ "$INCLUDE_DMARC" = "true" ]; then \
          postconf -e 'smtpd_recipient_restrictions=check_policy_service unix:private/policy,check_policy_service unix:private/policyd-spf' \
          && postconf -e smtpd_milters=unix:/run/opendkim/opendkim.sock,unix:/run/opendmarc/opendmarc.sock  \
          && postconf -e non_smtpd_milters=$smtpd_milters \
          && postconf -e 'milter_default_action=accept'; \
       else \
          postconf -e 'smtpd_recipient_restrictions = check_policy_service unix:private/policy'; \
       fi \
	&& postconf -M -e 'smtp/inet=smtp inet n - n - - smtpd' \
	&& postconf -M -e 'discourse/unix=discourse unix - n n - - pipe user=nobody:nogroup argv=/usr/local/bin/receive-mail ${recipient}' \
	&& postconf -M -e 'policy/unix=policy unix - n n - - spawn user=nobody argv=/usr/local/bin/discourse-smtp-fast-rejection' \
    && if [ "$INCLUDE_DMARC" = "true" ]; then \
          postconf -M -e 'policyd-spf/unix=policyd-spf unix - n n - - spawn user=nobody argv=/usr/bin/policyd-spf'; \
       fi \
	&& rm -rf /var/spool/postfix/*


COPY policyd-spf.conf /etc/postfix-policyd-spf-python/policyd-spf.conf
COPY opendkim.conf /etc/opendkim.conf
COPY opendmarc.conf /etc/opendmarc.conf

COPY receive-mail discourse-smtp-fast-rejection /usr/local/bin/
COPY lib/ /usr/local/lib/site_ruby/
COPY boot /sbin/
COPY fake-pups /pups/bin/pups

RUN curl -sL https://github.com/discourse/socketee/releases/download/v0.0.2/socketee -o /usr/local/bin/socketee \
	&& echo '7cd6df7aeeac0cce35c84e842b3cda5a4c36a301  /usr/local/bin/socketee' | sha1sum -c - \
	&& chmod 0755 /usr/local/bin/socketee

CMD ["/sbin/boot"]
