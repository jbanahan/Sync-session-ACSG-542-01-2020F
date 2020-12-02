describe Api::V1::AllianceDataController do

  let! (:user) {
    u = create(:admin_user, api_auth_token: "Token")
    allow_api_access u
    u
  }

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
end
