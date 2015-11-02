require 'spec_helper'

describe Api::V1::FenixPostbacksController do
  before :each do
    @user = Factory(:admin_user, api_auth_token: "Token")
    allow_api_access @user
  end

  describe :receive_lvs_results do
    it "delays and passes query results to fenix parser" do
      query_results = [{"summary" => "12345", "child" => "98765"}]

      OpenChain::FenixParser.should_receive(:delay).and_return OpenChain::FenixParser
      OpenChain::FenixParser.should_receive(:parse_lvs_query_results).with query_results.to_json

      post :receive_lvs_results, results: query_results, context: {}
      expect(response.body).to eq({"OK"=>""}.to_json)
    end

    it "fails if user is not admin" do
      @user = Factory(:user, api_auth_token: "Token")
      allow_api_access @user

      post :receive_lvs_results, results: [{"summary" => "12345"}], context: {}
      expect(response.status).to eq 403
    end
  end
end