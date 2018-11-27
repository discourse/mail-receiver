require_relative '../../lib/mail_receiver/fast_rejection'

describe FastRejection do

	it "is enabled if BASE_URL is present" do
		receiver = described_class.new(file_for(:standard))
		expect(receiver).not_to be_disabled
	end

	it "is disabled if FAST_REJECTION_DISABLED is set" do
		receiver = described_class.new(file_for(:fast_disabled))
		expect(receiver).to be_disabled
	end

	it "is disabled if missing the base URL" do
		receiver = described_class.new(file_for(:standard_deprecated))
		expect(receiver).to be_disabled
	end

	it "has the correct endpoint" do
		receiver = described_class.new(file_for(:standard))
		expect(receiver.endpoint).to eq('https://localhost:8080/admin/email/smtp_should_reject.json')
	end

	context "process_single_request" do
		let(:receiver) { described_class.new(file_for(:standard)) }

		it "returns defer_if_permit if not smtpd_access_policy" do
			response = receiver.process_single_request('request' => 'unexpected')
			expect(response).to start_with('defer_if_permit')
		end

		it "returns dunno if the protocol state is not RCPT" do
			response = receiver.process_single_request(
				'request' => 'smtpd_access_policy',
				'protocol_state' => 'NOT_RCPT'
			)
			expect(response).to eq('dunno')
		end

		it "returns defer_if_permit if no sender" do
			response = receiver.process_single_request(
				'request' => 'smtpd_access_policy',
				'protocol_state' => 'RCPT'
			)
			expect(response).to start_with('defer_if_permit')
		end

		it "returns defer_if_permit if no recipient" do
			response = receiver.process_single_request(
				'request' => 'smtpd_access_policy',
				'protocol_state' => 'RCPT',
				'sender' => 'eviltrout@example.com'
			)
			expect(response).to start_with('defer_if_permit')
		end

		it "returns dunno if everything looks good" do
			expect_any_instance_of(Net::HTTP).to receive(:request) do |http|
				response = Net::HTTPSuccess.new(http, 200, "OK")
				expect(response).to receive(:body) { "{}" }
				response
			end
			response = receiver.process_single_request(
				'request' => 'smtpd_access_policy',
				'protocol_state' => 'RCPT',
				'sender' => 'eviltrout@example.com',
				'recipient' => 'discourse@example.com'
			)
			expect(response).to eq("dunno")
		end

		it "rejects if there's an HTTP error" do
			expect_any_instance_of(Net::HTTP).to receive(:request) do |http|
				Net::HTTPServerError.new(http, 500, 'Error')
			end
			response = receiver.process_single_request(
				'request' => 'smtpd_access_policy',
				'protocol_state' => 'RCPT',
				'sender' => 'eviltrout@example.com',
				'recipient' => 'discourse@example.com'
			)
			expect(response).to start_with('defer_if_permit')
		end

		it "rejects if the HTTP response has reject in the JSON" do
			expect_any_instance_of(Net::HTTP).to receive(:request) do |http|
				response = Net::HTTPSuccess.new(http, 200, "OK")
				expect(response).to receive(:body) {
				  '{"reject": true, "reason": "because I said so"}'
				}
				response
			end
			response = receiver.process_single_request(
				'request' => 'smtpd_access_policy',
				'protocol_state' => 'RCPT',
				'sender' => 'eviltrout@example.com',
				'recipient' => 'discourse@example.com'
			)
			expect(response).to eq("reject because I said so")
		end
	end

end
