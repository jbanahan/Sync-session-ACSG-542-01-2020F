require 'spec_helper'

describe Api::V1::Admin::SearchSetupsController do
  describe :create_from_setup do
    it "should create a new template based on search setup id" do
      allow_api_access Factory(:admin_user)
      ss = Factory(:search_setup)
      SearchTemplate.should_receive(:create_from_search_setup!).with(instance_of(SearchSetup)).and_return double('x')
      post :create_template, id: ss.id
      expect(response).to be_success
      # we don't care what message comes back on success
    end
  end
end