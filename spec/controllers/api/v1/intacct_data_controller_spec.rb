require 'spec_helper'
require 'open_chain/sql_proxy_client'
require 'open_chain/custom_handler/intacct/intacct_invoice_details_parser'
require 'open_chain/custom_handler/intacct/intacct_client'

describe Api::V1::IntacctDataController do

  before :each do
    @user = Factory(:admin_user, api_auth_token: "Token", time_zone: "Hawaii")
    allow_api_access @user
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

  describe "receive_check_result" do
    it "forwards results to intacct invoice details parser" do
      results = [{:a => "b"}]
      OpenChain::CustomHandler::Intacct::IntacctInvoiceDetailsParser.should_receive(:delay).and_return OpenChain::CustomHandler::Intacct::IntacctInvoiceDetailsParser
      OpenChain::CustomHandler::Intacct::IntacctInvoiceDetailsParser.should_receive(:parse_check_result).with results.to_json
      post "receive_check_result", results: results
      expect(response.body).to eq ({"OK" => ""}.to_json)
    end
  end
end