require 'spec_helper'

describe AttachmentArchivesController do
  before :each do
    allow_any_instance_of(User).to receive(:edit_attachment_archives?).and_return true
    @u = Factory(:user)

    sign_in_as @u
  end
  describe :create do
    context :good_processing do
      before :each do
        arch = double('attachment_archive')
        expect(arch).to receive(:attachment_list_json).and_return('y')
        aas = double("attachment archive setup")
        allow(aas).to receive(:entry_attachments_available?).and_return(true)
        expect(aas).to receive(:create_entry_archive!).with("XYZ-1",100).and_return(arch)
        allow_any_instance_of(Company).to receive(:attachment_archive_setup).and_return(aas)
      end
      it "should make new archive if files are available" do
        c = Factory(:company,:name=>'XYZ')
        post :create, :company_id=>c.id.to_s, :max_bytes=>'100'
        expect(response).to be_success
        expect(response.body).to eq('y') 
      end
    end
    context "should error if" do
      def response_should_have_error_message message
        post :create, :company_id=>@c.id.to_s, :max_bytes=>'100'
        expect(response).to be_success
        expect(JSON.parse(response.body)).to eq({'errors'=>[message]})
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
        allow_any_instance_of(User).to receive(:edit_attachment_archives?).and_return false
        response_should_have_error_message 'You do not have permission to create archives.'
      end
      it "it raises error" do
        allow(Company).to receive(:find).and_raise "Random Error Here"
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
      allow_any_instance_of(User).to receive(:edit_attachment_archives?).and_return true
      post :complete, :company_id=>@c.id, :id=>@arch.id
      expect(response).to be_success
      @arch.reload
      expect(@arch.finish_at.to_i).to be > 10.second.ago.to_i
    end
    it "should 404 if user does not have permission" do
      allow_any_instance_of(User).to receive(:edit_attachment_archives?).and_return false
      expect {post :complete, :company_id=>@c.id, :id=>@arch.id}.to raise_error ActionController::RoutingError
      @arch.reload
      expect(@arch.finish_at).to be_nil
    end
  end

  describe :show do
    before :each do
      @c = Factory(:company)
      @arch = @c.attachment_archives.create!(:name=>'xyz',:start_at=>Time.now)  
    end

    it "should return json archive listing" do
      allow_any_instance_of(User).to receive(:edit_attachment_archives?).and_return true
      allow_any_instance_of(AttachmentArchive).to receive(:attachment_list_json).and_return("json")
      get :show, :company_id=>@c.id, :id=>@arch.id
      expect(response).to be_success
      expect(response.body).to eq('json') 
    end

    it "should return errors if user doesn't have permission" do
      allow_any_instance_of(User).to receive(:edit_attachment_archives?).and_return false
      
      get :show, :company_id=>@c.id, :id=>@arch.id
      expect(response).to be_success
      expect(response.body).to eq({'errors'=>['You do not have permission to view archives.']}.to_json)
    end

    it "should return error if archive isn't found" do
      allow_any_instance_of(User).to receive(:edit_attachment_archives?).and_return true
      
      get :show, :company_id=>@c.id, :id=>-1
      expect(response).to be_success
      expect(response.body).to eq({'errors'=>['Archive not found.']}.to_json)
    end

    it "should return error if company isn't found" do
      allow_any_instance_of(User).to receive(:edit_attachment_archives?).and_return true
      
      get :show, :company_id=>-1, :id=>@arch.id
      expect(response).to be_success
      expect(response.body).to eq({'errors'=>['Archive not found.']}.to_json)

    end
  end
end
