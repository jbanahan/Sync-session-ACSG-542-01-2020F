require 'spec_helper'

# The product api client is a super-thin shell around the api_client, as such
# there's very little to test in here.  Just that it's calling the right 
# parent class methods.
describe OpenChain::Api::ProductApiClient do
  before :each do
    @c = OpenChain::Api::ProductApiClient.new 'test', 'user', 'token'
  end

  describe "find_by_id" do
    it "uses send request with the correct path for find_by_id" do
      @c.should_receive(:mf_uid_list_to_param).with([:uid]).and_return({'param'=>'value'})
      @c.should_receive(:send_request).with("/products/by_id/1", {'param'=>'value'}).and_return "json"
      expect(@c.find_by_id(1, [:uid])).to eq "json"
    end
  end

  describe "find_by_uid" do
    it "uses send request with the correct path for find_by_uid" do
      @c.should_receive(:mf_uid_list_to_param).with([:uid]).and_return({'param'=>'value'})
      @c.should_receive(:send_request).with("/products/by_uid/style", {'param'=>'value'}).and_return "json"
      expect(@c.find_by_uid("style", [:uid])).to eq "json"
    end
  end

  describe "find_model_fields" do
    it "uses send request with the correct path for find_by_uid" do
      @c.should_receive(:send_request).with("/products/model_fields").and_return "json"
      expect(@c.find_model_fields).to eq "json"
    end
  end
end