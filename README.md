This container does the job of receiving an e-mail for a specified domain
and spawning an instance of another container to do "something" with the
e-mail.  That's it.  All very simple and straightforward.  You would
think...


# Installation and Configuration

Minimal configuration requires you to specify the domain you're receiving
mail for, and how to connect to your Discourse instance (URL, API key, etc).
This involves setting the following environment variables:

* `MAIL_DOMAIN` -- the domain name(s) to accept mail for and relay to
  Discourse.  Any number of space-separated domain names can be listed here.

* `DISCOURSE_MAIL_ENDPOINT` -- the complete URL to the API endpoint for
  receiving incoming e-mail.  This will be whatever your Discourse site URL
  is, with `/admin/email/handle_mail` appended.  For example, if people
  normally visit your Discourse forum by going to
  `https://discourse.example.com`, this environment variable should be set
  to `https://discourse.example.com/admin/email/handle_mail`.  If you're
  running a subfolder setup, be sure to account for that (ie
  `https://example.com/forum` ->
  `https://example.com/forum/admin/email/handle_mail`).

* `DISCOURSE_API_KEY` -- the API key which will be used to authenticate to
  Discourse in order to submit mail.  The value to use is shown in the "API"
  tab of the site admin dashboard.

* `DISCOURSE_API_USERNAME` -- (optional) the user whose identity and
  permissions will be used to make requests to the Discourse API.  This
  defaults to `system` and should be OK for 99% of cases.  The remaining 1%
  of times is where someone has (ill-advisedly) renamed the `system` user in
  Discourse.

For a straightforward setup, the above environment variables *should* be
enough to get you up and running.  If you have a desire for a more
complicated setup, the following subsections may provide you with the power
you need.


## Customised Postfix configuration

You can setup any Postfix configuration variables you need by setting env
vars of the form `POSTCONF_<var>` with the value of the variable you want.
For example, if you wanted to add a pre-delivery milter, you might use:

    -e POSTCONF_smtpd_milters=192.0.2.42:12345


## Syslog integration

Postfix loves to log everything to syslog.  In fact, that's really all it
supports.  Since, by default, Docker is not known for its superlative
out-of-the-box syslog integration, this container runs a tiny script which
reads all syslog data and dumps it to the container's `stderr` (which is
then examinable by `docker logs`).

If, by some chance, you have a system which can inject itself into a
container and process syslog entries intelligently (such as, say,
[syslogstash](https://github.com/discourse/syslogstash)), you can set the
`SYSLOG_SOCKET` environment variable to an alternate path, and the
`/dev/log` syslog socket will be symlinked to that alternate path.



# Theory of Operation

Every e-mail that is received is delivered to a custom `discourse` service.
That service, which is a small Ruby program, makes a POST request to the
specified URL (`DISCOURSE_MAIL_ENDPOINT`), with the key and username
specified.  Discourse itself stands ready to receive that e-mail and process
it into the discussion, in exactly the same way as an e-mail received via
POP3 polling.
