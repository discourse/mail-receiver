#!/usr/bin/env ruby

require 'syslog'
require 'json'
require 'uri'
require 'cgi'
require 'net/http'

ENV_FILE = "/etc/postfix/mail-receiver-environment.json"

def logger
  @logger ||= Syslog.open("smtp-reject", Syslog::LOG_PID, Syslog::LOG_MAIL)
end

def fatal(*args)
  logger.crit *args
  exit 1
end

def main
  unless File.exists?(ENV_FILE)
    fatal "Config file %s does not exist. Aborting.", ENV_FILE
  end

  real_env = JSON.parse(File.read(ENV_FILE))

  %w{DISCOURSE_MAIL_ENDPOINT DISCOURSE_API_KEY DISCOURSE_API_USERNAME}.each do |kw|
    fatal "env var %s is required", kw unless real_env[kw]
  end

  process_requests(real_env)
end

def process_requests(env)
  $stdout.sync = true   # unbuffered output

  args = {}
  while line = gets
    # Fill up args with the request details.
    line = line.chomp
    if !line.empty?
      k,v = line.chomp.split('=', 2)
      args[k] = v;
      next
    end

    process_single_request(args, env)
    args = {}  # reset for next request.
  end
end

def process_single_request(args, env)
  action = 'dunno'
  if args['request'] != 'smtpd_access_policy'
    action = 'defer_if_permit Internal error'
  elsif args['protocol_state'] != 'RCPT'
    action = 'dunno' 
  elsif args['sender'].nil? || args['recipient'].nil?
    action = 'defer_if_permit Internal error'
  else
    action = maybe_reject_email(args['sender'], args['recipient'], env)
  end

  puts "action=#{action}"
  puts ''
end

def maybe_reject_email(from, to, env)
  endpoint = env["DISCOURSE_SMTP_SHOULD_REJECT_ENDPOINT"]
  key = env["DISCOURSE_API_KEY"]
  username = env["DISCOURSE_API_USERNAME"]

  uri = URI.parse(endpoint)
  fromarg = CGI::escape(from)
  toarg = CGI::escape(to)

  api_qs = "api_key=#{key}&api_username=#{username}&from=#{fromarg}&to=#{toarg}"
  if uri.query and !uri.query.empty?
    uri.query += "&#{api_qs}"
  else
    uri.query = api_qs
  end

  begin
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == "https"
    get = Net::HTTP::Get.new(uri.request_uri)
    response = http.request(get)
  rescue StandardError => ex
    logger.err "Failed to GET smtp_should_reject answer from %s: %s (%s)", endpoint, ex.message, ex.class
    logger.err ex.backtrace.map { |l| "  #{l}" }.join("\n")
    return "defer_if_permit Internal error"
  ensure
    http.finish if http && http.started?
  end

  if Net::HTTPSuccess === response
    reply = JSON.parse(response.body)
    if reply['reject']
      return "reject #{reply['reason']}"
    end
  else
    logger.err "Failed to GET smtp_should_reject answer from %s: %s", endpoint, response.code
    return "defer_if_permit Internal error"
  end

  return "dunno"  # let future tests also be allowed to reject this one.
end

main if __FILE__ == $0
