# frozen_string_literal: true
require "base64"
require "net/smtp"
require "open3"
require "securerandom"
require "webrick"

RSpec.describe "mail-receiver image" do
  let(:marker) { "smoke-#{SecureRandom.hex(8)}" }
  let(:requests) { Queue.new }

  def docker(*args)
    output, status = Open3.capture2e("docker", *args)
    raise "docker #{args.join(" ")} failed:\n#{output}" unless status.success?
    output.strip
  end

  def start_fake_discourse
    started = Queue.new
    @server =
      WEBrick::HTTPServer.new(
        BindAddress: "0.0.0.0",
        Port: 0,
        Logger: WEBrick::Log.new(File::NULL),
        AccessLog: [],
        StartCallback: -> { started << true },
      )
    @server.mount_proc("/") do |req, _res|
      requests << {
        path: req.path,
        api_key: req["Api-Key"],
        api_username: req["Api-Username"],
        form: URI.decode_www_form(req.body).to_h,
      }
    end
    @server_thread = Thread.new { @server.start }
    started.pop
    @server.config[:Port]
  end

  def start_receiver(discourse_port)
    platform = ENV["SMOKE_PLATFORM"].to_s.empty? ? [] : ["--platform", ENV["SMOKE_PLATFORM"]]

    @container =
      docker(
        "run",
        "-d",
        *platform,
        "--add-host=host.docker.internal:host-gateway",
        "-p",
        "127.0.0.1::25",
        "-e",
        "MAIL_DOMAIN=smoke.test",
        "-e",
        "DISCOURSE_BASE_URL=http://host.docker.internal:#{discourse_port}",
        "-e",
        "DISCOURSE_API_KEY=smoke-key",
        "-e",
        "DISCOURSE_API_USERNAME=smoke-user",
        ENV["SMOKE_IMAGE"],
      )
    docker("port", @container, "25/tcp").lines.first.split(":").last.to_i
  end

  def connect_smtp(port)
    deadline = Time.now + 60
    begin
      Net::SMTP.start("127.0.0.1", port, helo: "smoke.test")
    rescue SystemCallError, IOError, Net::ReadTimeout
      raise if Time.now > deadline
      sleep 1
      retry
    end
  end

  before do
    raise "Set SMOKE_IMAGE to the mail-receiver image to test" if ENV["SMOKE_IMAGE"].to_s.empty?
  end

  after do |example|
    if @container
      if example.exception
        puts "--- docker logs #{@container}"
        puts Open3.capture2e("docker", "logs", @container).first
      end
      Open3.capture2e("docker", "rm", "-f", @container)
    end
    @server&.shutdown
    @server_thread&.join
  end

  it "delivers an email received over SMTP to Discourse" do
    smtp_port = start_receiver(start_fake_discourse)

    smtp = connect_smtp(smtp_port)
    response = smtp.send_message(<<~EMAIL, "sender@smoke.test", "reply@smoke.test")
      From: sender@smoke.test
      To: reply@smoke.test
      Subject: #{marker}

      #{marker}
    EMAIL
    smtp.finish
    expect(response.status).to eq("250")

    request = requests.pop(timeout: 60)
    expect(request).not_to be_nil, "Discourse did not receive the email within 60 seconds"
    expect(request[:path]).to eq("/admin/email/handle_mail")
    expect(request[:api_key]).to eq("smoke-key")
    expect(request[:api_username]).to eq("smoke-user")
    expect(Base64.strict_decode64(request[:form]["email_encoded"])).to include(marker)
  end
end
