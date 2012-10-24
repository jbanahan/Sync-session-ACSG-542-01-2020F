require 'spec_helper'

describe EntriesController do
  describe 'get_images' do
    before :each do
      @u = Factory(:user)
      activate_authlogic
      UserSession.create! @u
    end
    it "should request images" do
      entry = Factory(:entry,:source_system=>'Alliance',:broker_reference=>'123456')
      OpenChain::AllianceImagingClient.should_receive(:request_images).with('123456')
      get :get_images, 'id'=>entry.id
      response.should be_redirect
      flash[:errors].should be_blank
      flash[:notices].first.should == "Updated images for file 123456 have been requested.  Please allow 10 minutes for them to appear."
    end
    it "should not request images for non-alliance entries" do
      entry = Factory(:entry,:source_system=>'Fenix',:broker_reference=>'123456')
      OpenChain::AllianceImagingClient.should_not_receive(:request_images)
      get :get_images, 'id'=>entry.id
      response.should be_redirect
      flash[:errors].first.should == "Images cannot be requested for entries that are not from Alliance."
    end
  end
end
