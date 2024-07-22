# frozen_string_literal: true

# rubocop:disable Lint/RedundantRequireStatement
# require "set" is needed for Set
require "set"
require "syslog"
require "json"
require "uri"
require "cgi"
require "net/http"

require_relative "mail"
require_relative "mail_receiver_base"

class FastRejection < MailReceiverBase
  def initialize(env_file)
    super(env_file)

    @disabled = @env["DISCOURSE_FAST_REJECTION_DISABLED"] || !@env["DISCOURSE_BASE_URL"]

    @blacklisted_sender_domains =
      Set.new(@env.fetch("BLACKLISTED_SENDER_DOMAINS", "").split(" ").map(&:downcase))
  end

  def disabled?
    !!@disabled
  end

  def process
    $stdout.sync = true # unbuffered output

    args = {}
    while line = gets
      # Fill up args with the request details.
      line = line.chomp
      if line.empty?
        puts "action=#{process_single_request(args)}"
        puts ""

        args = {} # reset for next request.
      else
        k, v = line.chomp.split("=", 2)
        args[k] = v
      end
    end
  end

  def process_single_request(args)
    return "dunno" if disabled?

    if args["request"] != "smtpd_access_policy"
      return "defer_if_permit Internal error, Request type invalid"
    elsif args["protocol_state"] != "RCPT"
      return "dunno"
    elsif args["sender"].nil?
      # Note that while this key should always exist, its value may be the empty
      # string.  Postfix will convert the "<>" null sender to "".
      return "defer_if_permit No sender specified"
    elsif args["recipient"].nil?
      return "defer_if_permit No recipient specified"
    end

    run_filters(args)
  end

  def maybe_reject_email(from, to)
    uri = URI.parse(endpoint)
    fromarg = CGI.escape(from)
    toarg = CGI.escape(to)

    qs = "from=#{fromarg}&to=#{toarg}"
    if uri.query && !uri.query.empty?
      uri.query += "&#{qs}"
    else
      uri.query = qs
    end

    begin
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == "https"
      get = Net::HTTP::Get.new(uri.request_uri)
      get["Api-Username"] = username
      get["Api-Key"] = key
      response = http.request(get)
    rescue StandardError => ex
      logger.err "Failed to GET smtp_should_reject answer from %s: %s (%s)",
                 endpoint,
                 ex.message,
                 ex.class
      logger.err ex.backtrace.map { |l| "  #{l}" }.join("\n")
      return "defer_if_permit Internal error, API request preparation failed"
    ensure
      http.finish if http && http.started?
    end

    if Net::HTTPSuccess === response
      reply = JSON.parse(response.body)
      return "reject #{reply["reason"]}" if reply["reject"]
    else
      logger.err "Failed to GET smtp_should_reject answer from %s: %s", endpoint, response.code
      return "defer_if_permit Internal error, API request failed"
    end

    "dunno" # let future tests also be allowed to reject this one.
  end

  def endpoint
    "#{@env["DISCOURSE_BASE_URL"]}/admin/email/smtp_should_reject.json"
  end

  private

  def run_filters(args)
    filters = %i[maybe_reject_by_sender_domain maybe_reject_by_api]

    filters.each do |f|
      action = send(f, args)
      return action if action != "dunno"
    end

    "dunno"
  end

  def maybe_reject_by_sender_domain(args)
    sender = args["sender"]

    return "dunno" if sender.empty?

    domain = domain_from_addrspec(sender)
    if domain.empty?
      logger.info("deferred mail with domainless sender #{sender}")
      return "defer_if_permit Invalid sender"
    end
    if @blacklisted_sender_domains.include? domain
      logger.info("rejected mail from blacklisted sender domain #{domain} (from #{sender})")
      return "reject Invalid sender"
    end

    "dunno"
  end

  def maybe_reject_by_api(args)
    maybe_reject_email(args["sender"], args["recipient"])
  end
end
