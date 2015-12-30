require 'spec_helper'

describe SupportRequest do

  let(:user) { Factory(:user) }

  let(:support_request) {
    r = SupportRequest.new user: user, created_at: Time.zone.parse("2015-12-29 15:00"), referrer_url: "http://www.vfitrack.net", body: "Help!", severity: "OMG!!!", ticket_number: "Ticket", external_link: "Link"
  }

  context "with trello config" do
    let(:config) {
      {"trello" => {"board_id" => "the_board", "list_name" => "The List", "severity_colors" => {"OMG!!!" => "red", "Meh" => "green"}}}
    }

    before :each do
      Rails.env.stub(:test?).and_return false
      described_class.should_receive(:support_request_config).and_return config
    end

    describe "request_sender" do
      it "returns Trello sender" do
        sender = described_class.request_sender
        expect(sender).to be_a(SupportRequest::TrelloTicketSender)
        expect(sender.board_id).to eq "the_board"
        expect(sender.list_name).to eq "The List"
        expect(sender.severity_mappings).to eq({"OMG!!!" => "red", "Meh" => "green"})
      end
    end

    describe "send_ticket!" do
      it "uses TrelloTicketSender to send a ticket" do
        card = double("Trello::Card")
        card.should_receive(:short_url).and_return "http://short.en/me"
        OpenChain::Trello.should_receive(:send_support_request!).with("the_board", "The List", support_request, "red").and_return card

        support_request.send_request!

        support_request.reload

        expect(support_request).to be_persisted
        expect(support_request.ticket_number).to eq support_request.id.to_s
        expect(support_request.external_link).to eq "http://short.en/me"
      end
    end
  end

  context "with null config" do
    let(:config) {
      {"null" => ""}
    }

    before :each do
      Rails.env.stub(:test?).and_return false
      described_class.should_receive(:support_request_config).and_return config
    end

    it "returns null sender" do
      sender = described_class.request_sender
      expect(sender).to be_a(SupportRequest::NullSender)
    end
  end

  describe "request_sender" do
    before :each do
      Rails.env.stub(:test?).and_return false
    end

    it "raises an error when an invalid sender is selected" do
      described_class.should_receive(:support_request_config).and_return({"invalid" => ""})
      expect { described_class.request_sender }.to raise_error "Unexpected Support Request ticket sender encountered: invalid."
    end

    it "raises an error when no config file is present" do 
      described_class.should_receive(:support_request_config).and_return nil
      expect { described_class.request_sender }.to raise_error "No ticket sender configured."
    end
  end
end