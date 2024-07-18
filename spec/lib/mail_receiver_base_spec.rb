# frozen_string_literal: true
require_relative "../../lib/mail_receiver/discourse_mail_receiver"

RSpec.describe MailReceiverBase do
  it "raises an error with an a non-existant env file" do
    expect { described_class.new("does-not-exist.json") }.to raise_error(
      MailReceiverBase::ReceiverException,
    )
  end

  it "parses the env file" do
    receiver = described_class.new(file_for(:standard))
    expect(receiver.key).to eq("EXAMPLE_KEY")
    expect(receiver.username).to eq("eviltrout")
    expect(receiver.env["DISCOURSE_BASE_URL"]).to eq("https://localhost:8080")
  end

  it "works with the deprecated format" do
    receiver = described_class.new(file_for(:standard_deprecated))
    expect(receiver.key).to eq("EXAMPLE_KEY")
    expect(receiver.username).to eq("eviltrout")
    expect(receiver.env["DISCOURSE_MAIL_ENDPOINT"]).to eq("https://localhost:8080/mail-me")
  end

  it "raises an error if the env file doesn't have the api key" do
    expect { described_class.new(file_for(:missing_api_key)) }.to raise_error(
      MailReceiverBase::ReceiverException,
    )
  end

  it "raises an error if the env file doesn't have the username" do
    expect { described_class.new(file_for(:missing_username)) }.to raise_error(
      MailReceiverBase::ReceiverException,
    )
  end

  it "raises an error if MAIL_ENDPOINT or BASE_URL are missing" do
    expect { described_class.new(file_for(:missing_host)) }.to raise_error(
      MailReceiverBase::ReceiverException,
    )
  end
end
