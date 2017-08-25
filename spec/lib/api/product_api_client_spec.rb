require 'spec_helper'

# The product api client is a super-thin shell around the api_client, as such
# there's very little to test in here.  Just that it's calling the right 
# parent class methods.
describe OpenChain::Api::ProductApiClient do
  subject { OpenChain::Api::ProductApiClient.new 'test', 'user', 'token' }

  describe "find_by_uid" do
    it "uses get with the correct path for find_by_uid" do
      expect(subject).to receive(:get).with("/products/by_uid", {'fields'=>'uid', :uid => "style"}).and_return "json"
      expect(subject.find_by_uid("style", [:uid])).to eq "json"
    end
  end

  describe "core_module" do
    it "uses correct core module" do
      expect(subject.core_module).to eq CoreModule::PRODUCT
    end
  end
end