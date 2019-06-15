describe SupportRequest do

  let(:user) { Factory(:user) }

  let(:support_request) {
    r = SupportRequest.new user: user, created_at: Time.zone.parse("2015-12-29 15:00"), referrer_url: "http://www.vfitrack.net", body: "Help!", severity: "OMG!!!", ticket_number: "Ticket", external_link: "Link"
  }

  before :each do 
    allow(described_class).to receive(:test_env?).and_return false
  end

  context "with email config" do
    let(:config) {
      {"email" => {"addresses" => "support@vandegriftinc.com"}}
    }

    before :each do
      expect(described_class).to receive(:support_request_config).and_return config
    end

    describe "request_sender" do
      it "returns email sender" do
        sender = described_class.request_sender
        expect(sender).to be_a(SupportRequest::EmailSender)
        expect(sender.addresses).to eq "support@vandegriftinc.com"
      end
    end

    describe "send_request" do
      it "uses EmailRequestSender to send a request" do
        stub_master_setup
        support_request.send_request!
        support_request.reload
        expect(support_request).to be_persisted
        expect(support_request.ticket_number).to eq support_request.id.to_s
        mail = ActionMailer::Base.deliveries.pop
        expect(mail.subject).to eq "[Support Request ##{support_request.ticket_number} (test)]"
      end
    end
  end

  context "with null config" do
    let(:config) {
      {"null" => ""}
    }

    before :each do
      expect(described_class).to receive(:support_request_config).and_return config
    end

    it "returns null sender" do
      sender = described_class.request_sender
      expect(sender).to be_a(SupportRequest::NullSender)
    end
  end

  describe "request_sender" do

    it "raises an error when an invalid sender is selected" do
      expect(described_class).to receive(:support_request_config).and_return({"invalid" => ""})
      expect { described_class.request_sender }.to raise_error "Unexpected Support Request ticket sender encountered: invalid."
    end

    it "raises an error when no config file is present" do 
      expect(described_class).to receive(:support_request_config).and_return nil
      expect { described_class.request_sender }.to raise_error "No ticket sender configured."
    end
  end
end
