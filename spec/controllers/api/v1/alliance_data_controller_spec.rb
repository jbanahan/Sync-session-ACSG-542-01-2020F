require 'spec_helper'
require 'open_chain/alliance_parser'

describe Api::V1::AllianceDataController do

  before :each do
    @user = Factory(:admin_user, api_auth_token: "Token")
    allow_api_access @user
  end

  describe "receive_alliance_entry_details" do
    it "receives posted file info and forwards to alliance parser" do
      query_info = [{"file number"=>"1"}]
      r_context = {"context"=>"1"}

      OpenChain::AllianceParser.should_receive(:delay).and_return OpenChain::AllianceParser
      OpenChain::AllianceParser.should_receive(:process_alliance_query_details).with query_info.to_json, r_context.to_json
      post "receive_alliance_entry_details", results: query_info, context: r_context
      expect(response.body).to eq ({"OK" => ""}.to_json)
    end

    it "errors if user is not an admin" do
      @user.admin = false
      @user.save!

      post "receive_alliance_entry_details", results: []
      expect(response.status).to eq 401
      expect(response.body).to eq ({"errors" => ["Access denied."]}.to_json)
    end

    it "errors if there is no results param" do
      post "receive_alliance_entry_details"

      expect(response.status).to eq 400
      expect(response.body).to eq ({"errors" => ["Bad Request"]}.to_json)
    end

    it "errors if results does not respond to 'each'" do
      post "receive_alliance_entry_details", results: "Test"

      expect(response.status).to eq 400
      expect(response.body).to eq ({"errors" => ["Bad Request"]}.to_json)
    end
  end

  describe "receive_alliance_entry_tracking_details" do
    it "receives entry / invoice number array results and creates a delayed job" do
      results = [['file1', ''], ['', 'invoice1']]
      OpenChain::Report::AllianceWebtrackingMonitorReport.should_receive(:delay).and_return OpenChain::Report::AllianceWebtrackingMonitorReport
      OpenChain::Report::AllianceWebtrackingMonitorReport.should_receive(:process_alliance_query_details).with results.to_json

      post "receive_alliance_entry_tracking_details", results: results, context: {}
      expect(response.body).to eq ({"OK" => ""}.to_json)
    end

    it "errors if user is not an admin" do
      @user.admin = false
      @user.save!

      post "receive_alliance_entry_tracking_details", results: []
      expect(response.status).to eq 401
      expect(response.body).to eq ({"errors" => ["Access denied."]}.to_json)
    end
  end

  describe "receive_updated_entry_numbers" do
    it "receives data" do
      results = {"1"=>201503010000, "2"=>201503020000}
      OpenChain::CustomHandler::KewillDataRequester.stub(:delay).and_return OpenChain::CustomHandler::KewillDataRequester
      OpenChain::CustomHandler::KewillDataRequester.should_receive(:request_entry_data).with("1", "201503010000")
      OpenChain::CustomHandler::KewillDataRequester.should_receive(:request_entry_data).with("2", "201503020000")

      post "receive_updated_entry_numbers", results: results, context: {}
      expect(response.body).to eq ({"OK" => ""}.to_json)
    end

    it "errors if user is not an admin" do
      @user.admin = false
      @user.save!

      post "receive_updated_entry_numbers", results: []
      expect(response.status).to eq 401
      expect(response.body).to eq ({"errors" => ["Access denied."]}.to_json)
    end
  end

  describe "receive_entry_data" do
    it "receives entry data" do
      results = {"entry" => {"data" => "data"}}

      OpenChain::CustomHandler::KewillEntryParser.should_receive(:delay).and_return OpenChain::CustomHandler::KewillEntryParser
      OpenChain::CustomHandler::KewillEntryParser.should_receive(:parse_json).with(results.to_json)

      post "receive_entry_data", results: results, context: {}
      expect(response.body).to eq ({"OK" => ""}.to_json)
    end

    it "errors if user is not an admin" do
      @user.admin = false
      @user.save!

      post "receive_entry_data", results: []
      expect(response.status).to eq 401
      expect(response.body).to eq ({"errors" => ["Access denied."]}.to_json)
    end
  end
end