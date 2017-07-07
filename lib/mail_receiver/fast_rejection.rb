require 'syslog'
require 'json'
require 'uri'
require 'cgi'
require 'net/http'

require_relative 'mail_receiver_base'

class FastRejection < MailReceiverBase

	def initialize(env_file)
		super(env_file)

		@disabled = @env['DISCOURSE_FAST_REJECTION_DISABLED'] || !@env['DISCOURSE_BASE_URL']
	end

	def disabled?
		!!@disabled
	end

	def process
		$stdout.sync = true   # unbuffered output

		args = {}
		while line = gets
			# Fill up args with the request details.
			line = line.chomp
			if line.empty?
				puts "action=#{process_single_request(args)}"
				puts ''

				args = {}  # reset for next request.
			else
				k,v = line.chomp.split('=', 2)
				args[k] = v
			end
		end
	end

	def process_single_request(args)
		return 'dunno' if disabled?

		if args['request'] != 'smtpd_access_policy'
			return 'defer_if_permit Internal error, Request type invalid'
		elsif args['protocol_state'] != 'RCPT'
			return 'dunno'
		elsif args['sender'].nil?
			return 'defer_if_permit No sender specified'
		elsif args['recipient'].nil?
			return 'defer_if_permit No recipient specified'
		end

		maybe_reject_email(args['sender'], args['recipient'])
	end

	def endpoint
		"#{@env['DISCOURSE_BASE_URL']}/admin/email/smtp_should_reject.json"
	end

	def maybe_reject_email(from, to)

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
			return "defer_if_permit Internal error, API request preparation failed"
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
			return "defer_if_permit Internal error, API request failed"
		end

		return "dunno"  # let future tests also be allowed to reject this one.
	end

end
