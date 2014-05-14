require 'spec_helper'

describe AttachmentArchivesController do
  before :each do
    User.any_instance.stub(:edit_attachment_archives?).and_return true
    @u = Factory(:user)

    sign_in_as @u
  end
  describe :create do
    context :good_processing do
      before :each do
        arch = mock('attachment_archive')
        arch.should_receive(:attachment_list_json).and_return('y')
        aas = mock("attachment archive setup")
        aas.stub(:entry_attachments_available?).and_return(true)
        aas.should_receive(:create_entry_archive!).with("XYZ-1",100).and_return(arch)
        Company.any_instance.stub(:attachment_archive_setup).and_return(aas)
      end
      it "should make new archive if files are available" do
        c = Factory(:company,:name=>'XYZ')
        post :create, :company_id=>c.id.to_s, :max_bytes=>'100'
        response.should be_success
        response.body.should == 'y' 
      end
    end
    context "should error if" do
      def response_should_have_error_message message
        post :create, :company_id=>@c.id.to_s, :max_bytes=>'100'
        response.should be_success
        JSON.parse(response.body).should == {'errors'=>[message]}
      end
      before :each do 
        @c = Factory(:company)
      end
      it "no files are available" do
        @c.create_attachment_archive_setup(:start_date=>Time.now)
        response_should_have_error_message 'No files are available to be archived.'
      end
      it "no attachment_archive_setup for company" do
        response_should_have_error_message "#{@c.name} does not have an archive setup." 
      end
      it "user cannot edit archives" do
        User.any_instance.stub(:edit_attachment_archives?).and_return false
        response_should_have_error_message 'You do not have permission to create archives.'
      end
      it "it raises error" do
        Company.stub(:find).and_raise "Random Error Here"
        response_should_have_error_message 'Random Error Here'
      end
    end
  end

  describe :complete do
    before :each do
      @c = Factory(:company)
      @arch = @c.attachment_archives.create!(:name=>'xyz',:start_at=>Time.now)
    end
    it "should mark finished date" do
      User.any_instance.stub(:edit_attachment_archives?).and_return true
      post :complete, :company_id=>@c.id, :id=>@arch.id
      response.should be_success
      @arch.reload
      @arch.finish_at.should > 1.second.ago
    end
    it "should 404 if user does not have permission" do
      User.any_instance.stub(:edit_attachment_archives?).and_return false
      lambda {post :complete, :company_id=>@c.id, :id=>@arch.id}.should raise_error ActionController::RoutingError
      @arch.reload
      @arch.finish_at.should be_nil
    end
  end

  describe :show do
    before :each do
      @c = Factory(:company)
      @arch = @c.attachment_archives.create!(:name=>'xyz',:start_at=>Time.now)  
    end

    it "should return json archive listing" do
      User.any_instance.stub(:edit_attachment_archives?).and_return true
      AttachmentArchive.any_instance.stub(:attachment_list_json).and_return("json")
      get :show, :company_id=>@c.id, :id=>@arch.id
      response.should be_success
      response.body.should == 'json' 
    end

    it "should return errors if user doesn't have permission" do
      User.any_instance.stub(:edit_attachment_archives?).and_return false
      
      get :show, :company_id=>@c.id, :id=>@arch.id
      response.should be_success
      response.body.should == {'errors'=>['You do not have permission to view archives.']}.to_json
    end

    it "should return error if archive isn't found" do
      User.any_instance.stub(:edit_attachment_archives?).and_return true
      
      get :show, :company_id=>@c.id, :id=>-1
      response.should be_success
      response.body.should == {'errors'=>['Archive not found.']}.to_json
    end

    it "should return error if company isn't found" do
      User.any_instance.stub(:edit_attachment_archives?).and_return true
      
      get :show, :company_id=>-1, :id=>@arch.id
      response.should be_success
      response.body.should == {'errors'=>['Archive not found.']}.to_json

    end
  end
end
