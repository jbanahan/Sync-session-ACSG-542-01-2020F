require 'spec_helper'

describe EntriesController do

  before :each do 
    MasterSetup.get.update_attributes(:entry_enabled=>true)
    c = Factory(:company,:master=>true)
    @u = Factory(:user,:entry_view=>true,:company=>c)
    activate_authlogic
    UserSession.create! @u
  end

  describe 'get_images' do
    it "should request images" do
      #make sure we're not relying on the referrer
      request.env["HTTP_REFERER"] = nil
      entry = Factory(:entry,:source_system=>'Alliance',:broker_reference=>'123456')
      OpenChain::AllianceImagingClient.should_receive(:request_images).with('123456')
      get :get_images, 'id'=>entry.id
      expect(response).to redirect_to(entry)
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

  describe 'bulk_get_images' do

    it "should handle bulk image requests with a referer" do
      request.env["HTTP_REFERER"] = "blah"
      entry = Factory(:entry,:source_system=>'Alliance',:broker_reference=>'123456')
      OpenChain::AllianceImagingClient.stub(:delay).and_return(OpenChain::AllianceImagingClient)
      OpenChain::AllianceImagingClient.should_receive(:bulk_request_images).with('1234', '123')
      get :bulk_get_images, {'sr_id'=>'1234', 'pk'=>'123'}
      
      response.should redirect_to("blah")
      flash[:errors].should be_blank
      flash[:notices].first.should == "Updated images have been requested.  Please allow 10 minutes for them to appear."
    end

    it "should handle bulk image requests without a referer" do
      request.env["HTTP_REFERER"] = nil
      entry = Factory(:entry,:source_system=>'Alliance',:broker_reference=>'123456')
      OpenChain::AllianceImagingClient.stub(:delay).and_return(OpenChain::AllianceImagingClient)
      OpenChain::AllianceImagingClient.should_receive(:bulk_request_images).with('1234', '123')
      get :bulk_get_images, {'sr_id'=>'1234', 'pk'=>'123'}
      
      response.should redirect_to("/")
      flash[:errors].should be_blank
      flash[:notices].first.should == "Updated images have been requested.  Please allow 10 minutes for them to appear."
    end

  end

  describe "show" do
    it "should raise a 404 if not found" do
      get :show, :id => -20
      response.should redirect_to("/")
      flash[:errors].should eq ["Entry with id -20 not found."]
    end

    it "should show a US entry" do
      entry = Factory(:entry)
      get :show, :id => entry.id

      response.status.should == 200
      assigns(:entry).id.should eq entry.id
      response.should render_template("show_us")
    end

    it "should show a US simple entry" do
      @u.update_attributes! :simple_entry_mode => true
      entry = Factory(:entry)
      get :show, :id => entry.id

      response.status.should == 200
      assigns(:entry).id.should eq entry.id
      response.should render_template("show_us_simple")
    end

    it "should show a CA entry" do
      country = Factory(:country, :iso_code => 'CA')
      entry = Factory(:entry, :import_country => country)

      get :show, :id => entry.id

      response.status.should == 200
      assigns(:entry).id.should eq entry.id
      response.should render_template("show_ca")
    end

    it "should redirect if user can't view" do
      Entry.any_instance.should_receive(:can_view?).and_return false

      entry = Factory(:entry)
      get :show, :id => entry.id
      response.should redirect_to("/")
      flash[:errors].should eq ["You do not have permission to view this entry."]

    end
  end
end
