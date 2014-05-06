require 'spec_helper'
require 'open_chain/sql_proxy_client'
require 'open_chain/custom_handler/intacct/intacct_invoice_details_parser'
require 'open_chain/custom_handler/intacct/intacct_client'

describe Api::V1::IntacctDataController do

  before :each do
    @user = Factory(:admin_user, api_auth_token: "Token", time_zone: "Hawaii")
    allow_api_access @user
  end

  describe "receive_alliance_invoice_numbers" do

    it "receives posted file numbers and requests detail information for those not already requested" do
      alliance_query_info = [{:f => "123", :s => " "}, {:f => "123", :s => "A"}, {:f => "456", :s => "Y", :ff => "987"}, {:f => "456", :s => "Z"}]

      IntacctAllianceExport.create! file_number: "123", data_requested_date: Time.zone.now, data_received_date: Time.zone.now
      IntacctAllianceExport.create! file_number: "123", suffix: "A", data_requested_date: Time.zone.now
      IntacctAllianceExport.create! file_number: "456", suffix: "Y", data_requested_date: (Time.zone.now - 31.minutes)

      OpenChain::SqlProxyClient.should_receive(:delay).twice.and_return OpenChain::SqlProxyClient
      # Should receive calls for 456-Z since there's no export record for it, and 456-Y because it was requested more than 30 minutes ago
      OpenChain::SqlProxyClient.should_receive(:request_alliance_invoice_details).with "456", "Y"
      OpenChain::SqlProxyClient.should_receive(:request_alliance_invoice_details).with "456", "Z"

      post "receive_alliance_invoice_numbers", results: alliance_query_info
      expect(response.body).to eq ({"OK" => ""}.to_json)
    end

    it "errors if user is not an admin" do
      @user.admin = false
      @user.save!

      post "receive_alliance_invoice_numbers", results: []
      expect(response.status).to eq 401
      expect(response.body).to eq ({"errors" => ["Access denied."]}.to_json)
    end

    it "errors if there is no results param" do
      post "receive_alliance_invoice_numbers"

      expect(response.status).to eq 400
      expect(response.body).to eq ({"errors" => ["Bad Request"]}.to_json)
    end

    it "errors if results does not respond to 'each'" do
      post "receive_alliance_invoice_numbers", results: "Test"

      expect(response.status).to eq 400
      expect(response.body).to eq ({"errors" => ["Bad Request"]}.to_json)
    end
  end

  describe "receive_alliance_invoice_details" do
    
    it "forwards results to intacct invoice details parser" do
      post "receive_alliance_invoice_details", results: [{:a => "b"}]
      expect(response.body).to eq ({"OK" => ""}.to_json)
    end

    it "errors if user is not an admin" do
      @user.admin = false
      @user.save!

      post "receive_alliance_invoice_details", results: []
      expect(response.status).to eq 401
      expect(response.body).to eq ({"errors" => ["Access denied."]}.to_json)
    end

    it "errors if there is no results param" do
      post "receive_alliance_invoice_details"

      expect(response.status).to eq 400
      expect(response.body).to eq ({"errors" => ["Bad Request"]}.to_json)
    end

    it "errors if results does not respond to 'each'" do
      post "receive_alliance_invoice_details", results: "Test"

      expect(response.status).to eq 400
      expect(response.body).to eq ({"errors" => ["Bad Request"]}.to_json)
    end
  end
end