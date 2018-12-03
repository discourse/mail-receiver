require 'syslog'
require 'json'
require "uri"
require "net/http"
require_relative 'mail_receiver_base'

class DiscourseMailReceiver < MailReceiverBase

  def initialize(env_file = nil, recipient = nil, mail = nil)
    super(env_file)

    @recipient = recipient
    @mail = mail

    logger.debug "Recipient: #{@recipient}"
    fatal "No recipient passed on command line." unless @recipient
    fatal "No message passed on stdin." if @mail.nil? || @mail.empty?
  end

  def endpoint
    return @endpoint if @endpoint

    @endpoint = @env["DISCOURSE_MAIL_ENDPOINT"]

    if @env['DISCOURSE_BASE_URL']
      @endpoint = "#{@env['DISCOURSE_BASE_URL']}/admin/email/handle_mail"
    end
    @endpoint
  end

  def process
    uri = URI.parse(endpoint)
    api_qs = "api_key=#{key}&api_username=#{username}"
    if uri.query && !uri.query.empty?
      uri.query += "&#{api_qs}"
    else
      uri.query = api_qs
    end

    begin
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == "https"
      post = Net::HTTP::Post.new(uri.request_uri)
      post.set_form_data(email: @mail)

      response = http.request(post)
    rescue StandardError => ex
      logger.err "Failed to POST the e-mail to %s: %s (%s)", endpoint, ex.message, ex.class
      logger.err ex.backtrace.map { |l| "  #{l}" }.join("\n")

      return :failure
    ensure
      http.finish if http && http.started?
    end

    return :success if Net::HTTPSuccess === response

    logger.err "Failed to POST the e-mail to %s: %s", endpoint, response.code
    :failure
  end

end
