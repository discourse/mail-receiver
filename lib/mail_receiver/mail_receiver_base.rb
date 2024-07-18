# frozen_string_literal: true
class MailReceiverBase
  class ReceiverException < StandardError
  end

  attr_reader :env

  def initialize(env_file)
    fatal "Config file %s does not exist. Aborting.", env_file unless File.exist?(env_file)

    @env = JSON.parse(File.read(env_file))

    %w[DISCOURSE_API_KEY DISCOURSE_API_USERNAME].each do |kw|
      fatal "env var %s is required", kw unless @env[kw]
    end

    if @env["DISCOURSE_MAIL_ENDPOINT"].nil? && @env["DISCOURSE_BASE_URL"].nil?
      fatal "DISCOURSE_MAIL_ENDPOINT and DISCOURSE_BASE_URL env var missing"
    end
  end

  def self.logger
    @logger ||= Syslog.open(File.basename($0), Syslog::LOG_PID, Syslog::LOG_MAIL)
  end

  def logger
    MailReceiverBase.logger
  end

  def key
    @env["DISCOURSE_API_KEY"]
  end

  def username
    @env["DISCOURSE_API_USERNAME"]
  end

  def fatal(*args)
    logger.crit(*args)
    raise ReceiverException.new(sprintf(*args))
  end
end
