require 'spec_helper'

describe DrawbackUploadFilesController do
  before :each do
    @user = Factory(:user)
    activate_authlogic
    UserSession.create! @user
    DrawbackUploadFile.any_instance.stub(:validate_layout).and_return([])
  end
  describe :index do
    it "should redirect if user cannot view drawback" do
      User.any_instance.stub(:view_drawback?).and_return(false)
      get :index
      response.should be_redirect
      flash[:errors].first.should == "You cannot view this page because you do not have permission to view Drawback."
    end
    it "should be good if permissions ok" do
      User.any_instance.stub(:view_drawback?).and_return(true)
      get :index
      response.should be_success
    end
  end
  describe :create do
    before :each do
      @tmp = Tempfile.new(['x','.txt'])
      @file = fixture_file_upload(@tmp.path, 'text/plain')
      @dj = Delayed::Worker.delay_jobs
      Delayed::Worker.delay_jobs = false
    end
    after :each do
      @tmp.unlink
      Delayed::Worker.delay_jobs = @dj
    end
    context "don't process" do
      before :each do
        DrawbackUploadFile.any_instance.stub(:process).and_return(nil)
      end
      it "should fail if user cannot edit drawback" do
        User.any_instance.stub(:edit_drawback?).and_return(false)
        post :create, 'drawback_upload_file'=>{'processor'=>DrawbackUploadFile::PROCESSOR_UA_WM_IMPORTS,'attachment_attributes'=>{'attached'=>@file}}
        response.should be_redirect
        flash[:errors].first.should == "You cannot upload files because you do not have permission to edit Drawback."
      end
      it "should fail if processor is not set" do
        User.any_instance.stub(:edit_drawback?).and_return(true)
        post :create, 'drawback_upload_file'=>{'processor'=>'','attachment_attributes'=>{'attached'=>@file}}
        response.should be_redirect
        flash[:errors].first.should == "You cannot upload this file because the processor is not set.  Please contact support."
      end
      it "should fail if attachment is not sent" do
        User.any_instance.stub(:edit_drawback?).and_return(true)
        post :create, 'drawback_upload_file'=>{'processor'=>DrawbackUploadFile::PROCESSOR_UA_WM_IMPORTS}
        response.should be_redirect
        flash[:errors].first.should == "You must select a file before uploading."
      end
      it "should set start_at" do
        User.any_instance.stub(:edit_drawback?).and_return(true)
        post :create, 'drawback_upload_file'=>{'processor'=>DrawbackUploadFile::PROCESSOR_UA_WM_IMPORTS,'attachment_attributes'=>{'attached'=>@file}}
        response.should be_redirect
        flash[:errors].should be_nil
        flash[:notices].should have(1).message
        DrawbackUploadFile.first.start_at.should > 3.seconds.ago
      end
    end
    it "should delay process job" do
      DrawbackUploadFile.any_instance.should_receive(:process).with(@user)
      DrawbackUploadFile.any_instance.should_receive(:delay).and_return(DrawbackUploadFile.new)
      User.any_instance.stub(:edit_drawback?).and_return(true)
      post :create, 'drawback_upload_file'=>{'processor'=>DrawbackUploadFile::PROCESSOR_UA_WM_IMPORTS,'attachment_attributes'=>{'attached'=>@file}}
      response.should be_redirect
      flash[:errors].should be_nil
      flash[:notices].should have(1).message
    end
    it "should call process job" do
      DrawbackUploadFile.any_instance.should_receive(:process)
      User.any_instance.stub(:edit_drawback?).and_return(true)
      post :create, 'drawback_upload_file'=>{'processor'=>DrawbackUploadFile::PROCESSOR_UA_WM_IMPORTS,'attachment_attributes'=>{'attached'=>@file}}
      response.should be_redirect
      flash[:errors].should be_nil
      flash[:notices].should have(1).message
      DrawbackUploadFile.first.processor.should == DrawbackUploadFile::PROCESSOR_UA_WM_IMPORTS
    end
  end
end
