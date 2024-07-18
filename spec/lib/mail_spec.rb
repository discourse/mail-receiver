# frozen_string_literal: true
require_relative "../../lib/mail_receiver/mail"

# rubocop:disable RSpec/DescribeClass
# mail.rb is not implemented as a class or module
RSpec.describe "domain_from_addrspec" do
  it "normalises domains to lowercase" do
    expect(domain_from_addrspec("local-part@DOMAIN.NET")).to eq "domain.net"
  end

  it "returns an empty string when given an empty string" do
    expect(domain_from_addrspec("")).to be_empty
  end

  it "returns an empty string if a domain was not found" do
    expect(domain_from_addrspec("local-part")).to be_empty
  end
end
