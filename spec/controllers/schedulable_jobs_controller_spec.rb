require 'spec_helper'

describe SchedulableJobsController do
  def login u
    activate_authlogic
    UserSession.create! u
  end
  describe :index do
    it "should only allow sys_admins" do
      login Factory(:user)
      get :index
      response.should be_redirect
      flash[:errors].first.should match /Only system admins/
    end
    it "should load all jobs" do
      login Factory(:sys_admin_user)
      2.times {Factory(:schedulable_job)}
      get :index
      response.should be_success
      assigns(:schedulable_jobs).should have(2).jobs
    end
  end

  describe :edit do
    before :each do
      @sj = Factory(:schedulable_job)
    end
    it "should only allow sys_admins" do
      login Factory(:user)
      get :edit, id: @sj.id
      response.should be_redirect
      flash[:errors].first.should match /Only system admins/
    end
    it "should load job" do
      login Factory(:sys_admin_user)
      get :edit, id: @sj.id
      response.should be_success
      assigns(:sj).should == @sj
    end
  end
  describe :update do
    before :each do
      @sj = Factory(:schedulable_job,opts:'abc')
    end
    it "should only allow sys_admins" do
      login Factory(:user)
      put :update, id: @sj.id, schedulable_job:{opts:'12345'}
      response.should be_redirect
      flash[:errors].first.should match /Only system admins/
      @sj.reload
      @sj.opts.should == 'abc'
    end
    it "should update job" do
      login Factory(:sys_admin_user)
      put :update, id: @sj.id, schedulable_job:{opts:'12345'}
      response.should redirect_to schedulable_jobs_path
      @sj.reload
      @sj.opts.should == '12345'
    end
  end
  
  describe :new do
    it "should only allow sys_admins" do
      login Factory(:user)
      get :new
      response.should be_redirect
      flash[:errors].first.should match /Only system admins/
    end
    it "should load empty job" do
      login Factory(:sys_admin_user)
      get :new
      response.should be_success
      assigns(:sj).should be_instance_of(SchedulableJob)
    end
  end
  describe :create do
    it "should only allow sys_admins" do
      login Factory(:user)
      post :create, schedulable_job:{opts:'12345'}
      response.should be_redirect
      flash[:errors].first.should match /Only system admins/
      SchedulableJob.all.should be_empty
    end
    it "shoud make job" do
      login Factory(:sys_admin_user)
      post :create, schedulable_job:{opts:'12345'}
      response.should redirect_to schedulable_jobs_path
      SchedulableJob.first.opts.should == '12345'
    end
  end

  describe :destroy do
    before :each do
      @sj = Factory(:schedulable_job)
    end
    it "should only allow sys_admins" do
      login Factory(:user)
      delete :destroy, id:@sj.id
      response.should be_redirect
      flash[:errors].first.should match /Only system admins/
      SchedulableJob.first.should == @sj
    end
    it "should destroy job" do
      login Factory(:sys_admin_user)
      delete :destroy, id:@sj.id
      response.should redirect_to schedulable_jobs_path
      SchedulableJob.all.should be_empty
    end
  end

end
