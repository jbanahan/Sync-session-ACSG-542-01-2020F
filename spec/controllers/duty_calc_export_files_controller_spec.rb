require 'spec_helper'

describe DutyCalcExportFilesController do
  before :each do
    @user = Factory(:user)

    sign_in_as @user
  end
  describe :create do
    before :each do 
      @c = Factory(:company)
    end
    it "should fail if user cannot edit drawback" do
      User.any_instance.stub(:edit_drawback?).and_return(false)
      post :create, importer_id: @c.id.to_s
      response.response_code.should == 403
    end
    it "should delay creation" do
      f = mock('expfileclass')
      f.should_receive(:generate_for_importer).with(@c.id.to_s,@user)
      User.any_instance.stub(:edit_drawback?).and_return(true)
      DutyCalcExportFile.should_receive(:delay).and_return f 
      post :create, importer_id: @c.id.to_s
      response.should redirect_to drawback_upload_files_path
    end
  end
  describe :download do
    before :each do
      @d = Factory(:duty_calc_export_file)
    end
    it "should get attachment" do
      User.any_instance.stub(:edit_drawback?).and_return(true)
      @d.create_attachment!
      get :download, id: @d.id
      response.should redirect_to download_attachment_path(@d.attachment)
    end
    it "should render failure if no attachment" do
      User.any_instance.stub(:edit_drawback?).and_return(true)
      get :download, id: @d.id
      response.should be_redirect
      flash[:errors].first.should == 'Export file does not have an attachment.'
    end
    it "should not allow users who cannot edit drawback" do
      User.any_instance.stub(:edit_drawback?).and_return(false)
      get :download, id: @d.id
      response.response_code.should == 403
    end
  end
end
