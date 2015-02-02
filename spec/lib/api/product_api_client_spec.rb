require 'spec_helper'

# The product api client is a super-thin shell around the api_client, as such
# there's very little to test in here.  Just that it's calling the right 
# parent class methods.
describe OpenChain::Api::ProductApiClient do
  before :each do
    @c = OpenChain::Api::ProductApiClient.new 'test', 'user', 'token'
  end

  describe "find_by_uid" do
    it "uses get with the correct path for find_by_uid" do
      @c.should_receive(:mf_uid_list_to_param).with([:uid]).and_return({'param'=>'value'})
      @c.should_receive(:get).with("/products/by_uid/style", {'param'=>'value'}).and_return "json"
      expect(@c.find_by_uid("style", [:uid])).to eq "json"
    end
  end

  describe "show" do
    it "uses get to find by a specific id" do
      @c.should_receive(:mf_uid_list_to_param).with([:uid]).and_return({'param'=>'value'})
      @c.should_receive(:get).with("/products/1", {'param'=>'value'}).and_return "json"
      expect(@c.show(1, [:uid])).to eq "json"
    end
  end

  describe "create" do
    it "uses post to create" do
      @c.should_receive(:post).with("/products", hash).and_return "json"
      create_hash = {id: 1, prod_uid: 'uid'}
      expect(@c.create(hash)).to eq "json"
    end
  end

  describe "update" do
    it "uses put to update" do
      create_hash = {product: {id: 1, prod_uid: 'uid'}}
      @c.should_receive(:put).with("/products/1", create_hash).and_return "json"
      expect(@c.update(create_hash)).to eq "json"
    end

    it "uses handles non-symbols for finding id to update" do
      create_hash = {'product' => {'id' => 2, 'prod_uid' => 'uid'}}
      @c.should_receive(:put).with("/products/2", create_hash).and_return "json"
      expect(@c.update(create_hash)).to eq "json"
    end

    it "errors if no id attribute is found" do
      create_hash = {}
      expect{@c.update(create_hash)}.to raise_error "All product update calls require an 'id' in the attribute hash."
    end
  end
end