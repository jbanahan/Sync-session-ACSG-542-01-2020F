require 'spec_helper'
require 'open_chain/alliance_parser'

describe Api::V1::AllianceDataController do

  let! (:user) {
    u = Factory(:admin_user, api_auth_token: "Token")
    allow_api_access u
    u
  }

  describe "receive_alliance_entry_details" do
    it "receives posted file info and forwards to alliance parser" do
      query_info = [{"file number"=>"1"}]
      r_context = {"context"=>"1"}

      expect(OpenChain::AllianceParser).to receive(:delay).and_return OpenChain::AllianceParser
      expect(OpenChain::AllianceParser).to receive(:process_alliance_query_details).with query_info.to_json, r_context.to_json
      post "receive_alliance_entry_details", results: query_info, context: r_context
      expect(response.body).to eq ({"ok" => "ok"}.to_json)
    end

    it "errors if user is not an admin" do
      user.admin = false
      user.save!

      post "receive_alliance_entry_details", results: []
      expect(response.status).to eq 403
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
      expect(OpenChain::Report::AllianceWebtrackingMonitorReport).to receive(:delay).and_return OpenChain::Report::AllianceWebtrackingMonitorReport
      expect(OpenChain::Report::AllianceWebtrackingMonitorReport).to receive(:process_alliance_query_details).with results.to_json

      post "receive_alliance_entry_tracking_details", results: results, context: {}
      expect(response.body).to eq ({"ok" => "ok"}.to_json)
    end

    it "errors if user is not an admin" do
      user.admin = false
      user.save!

      post "receive_alliance_entry_tracking_details", results: []
      expect(response.status).to eq 403
      expect(response.body).to eq ({"errors" => ["Access denied."]}.to_json)
    end
  end

  describe "receive_updated_entry_numbers" do
    it "receives data" do
      results = {"1"=>201503010000, "2"=>201503020000, "3"=>201503030000, "4"=>201503040000}
      allow(OpenChain::CustomHandler::KewillDataRequester).to receive(:delay).and_return OpenChain::CustomHandler::KewillDataRequester
      expect(OpenChain::CustomHandler::KewillDataRequester).to receive(:request_entry_batch_data).with({"1"=>"201503010000", "2"=>"201503020000"})
      expect(OpenChain::CustomHandler::KewillDataRequester).to receive(:request_entry_batch_data).with({"3"=>"201503030000", "4"=>"201503040000"})
      expect(subject).to receive(:batch_size).and_return 2

      post "receive_updated_entry_numbers", results: results, context: {}
      expect(response.body).to eq ({"ok" => "ok"}.to_json)
    end

    it "errors if user is not an admin" do
      user.admin = false
      user.save!

      post "receive_updated_entry_numbers", results: []
      expect(response.status).to eq 403
      expect(response.body).to eq ({"errors" => ["Access denied."]}.to_json)
    end
  end

  describe "receive_entry_data" do
    it "receives entry data" do
      results = {"entry" => {"file_no" => "1234"}}

      expect(OpenChain::CustomHandler::KewillEntryParser).to receive(:save_to_s3).with(results).and_return bucket: "bucket", key: "key"
      expect(OpenChain::CustomHandler::KewillEntryParser).to receive(:delay).and_return OpenChain::CustomHandler::KewillEntryParser
      expect(OpenChain::CustomHandler::KewillEntryParser).to receive(:process_from_s3).with("bucket", "key")

      post "receive_entry_data", results: results, context: {}
      expect(response.body).to eq ({"ok" => "ok"}.to_json)
    end

    it "puts file # in error message if s3 load fails" do
      results = {"entry" => {"file_no" => "1234"}}
      expect(OpenChain::CustomHandler::KewillEntryParser).to receive(:save_to_s3).with(results).and_raise "Error!"

      expect{post "receive_entry_data", results: results, context: {}}.to change(ErrorLogEntry,:count).by(1)
      expect(response.body).to eq ({"ok" => "ok"}.to_json)
    end

    it "errors if user is not an admin" do
      user.admin = false
      user.save!

      post "receive_entry_data", results: []
      expect(response.status).to eq 403
      expect(response.body).to eq ({"errors" => ["Access denied."]}.to_json)
    end
  end

  describe "receive_mid_updates" do
    it "handles mid update arrays" do
      results = [['mid'], ['mid2']]
      expect(ManufacturerId).to receive(:delay).and_return ManufacturerId
      expect(ManufacturerId).to receive(:load_mid_records).with results

      post "receive_mid_updates", results: results
    end

    it "splits results into groups of 100" do
      results = []
      101.times {|x| results << x.to_s}

      expect(ManufacturerId).to receive(:delay).exactly(2).times.and_return ManufacturerId
      expect(ManufacturerId).to receive(:load_mid_records).with results[0..-2]
      expect(ManufacturerId).to receive(:load_mid_records).with [results[-1]]

      post "receive_mid_updates", results: results
    end

    it "errors if user is not an admin" do
      user.admin = false
      user.save!

      post "receive_mid_updates", results: []
      expect(response.status).to eq 403
      expect(response.body).to eq ({"errors" => ["Access denied."]}.to_json)
    end
  end

  describe "receive_address_updates" do
    it "handles address update arrays" do
      results = [['addr'], ['addr2']]
      expect(Address).to receive(:delay).and_return Address
      expect(Address).to receive(:update_kewill_addresses).with results

      post "receive_address_updates", results: results
    end

    it "splits results into groups of 100" do
      results = []
      101.times {|x| results << x.to_s}

      expect(Address).to receive(:delay).exactly(2).times.and_return Address
      expect(Address).to receive(:update_kewill_addresses).with results[0..-2]
      expect(Address).to receive(:update_kewill_addresses).with [results[-1]]

      post "receive_address_updates", results: results
    end

    it "errors if user is not an admin" do
      user.admin = false
      user.save!

      post "receive_address_updates", results: []
      expect(response.status).to eq 403
      expect(response.body).to eq ({"errors" => ["Access denied."]}.to_json)
    end
  end
end
