# frozen_string_literal: true
require_relative "../../lib/mail_receiver/discourse_mail_receiver"

RSpec.describe DiscourseMailReceiver do
  let(:recipient) { "eviltrout@example.com" }
  let(:mail) { "some body" }

  it "raises an error without a recipient" do
    expect { described_class.new(file_for(:standard), nil, mail) }.to raise_error(
      MailReceiverBase::ReceiverException,
    )
  end

  it "raises an error without mail" do
    expect { described_class.new(file_for(:standard), recipient, nil) }.to raise_error(
      MailReceiverBase::ReceiverException,
    )

    expect { described_class.new(file_for(:standard), recipient, "") }.to raise_error(
      MailReceiverBase::ReceiverException,
    )
  end

  it "has a backwards compatible endpoint" do
    receiver = described_class.new(file_for(:standard_deprecated), recipient, mail)
    expect(receiver.endpoint).to eq("https://localhost:8080/mail-me")
  end

  it "has the correct endpoint" do
    receiver = described_class.new(file_for(:standard), "eviltrout@example.com", "test mail")
    expect(receiver.endpoint).to eq("https://localhost:8080/admin/email/handle_mail")
  end

  it "can process mail" do
    expect_any_instance_of(Net::HTTP).to receive(:request) do |http|
      Net::HTTPSuccess.new(http, 200, "OK")
    end

    receiver = described_class.new(file_for(:standard), "eviltrout@example.com", "test mail")
    expect(receiver.process).to eq(:success)
  end

  it "returns failure on HTTP error" do
    expect_any_instance_of(Net::HTTP).to receive(:request) do |http|
      Net::HTTPServerError.new(http, 500, "Error")
    end

    receiver = described_class.new(file_for(:standard), "eviltrout@example.com", "test mail")
    expect(receiver.process).to eq(:failure)
  end
end
