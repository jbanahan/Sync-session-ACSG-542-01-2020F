require 'spec_helper'

describe SchedulableJobsController do
  def login u

    sign_in_as u
  end
  describe "index" do
    it "should only allow sys_admins" do
      login Factory(:user)
      get :index
      expect(response).to be_redirect
      expect(flash[:errors].first).to match /Only system admins/
    end
    it "should load all jobs" do
      login Factory(:sys_admin_user)
      2.times {Factory(:schedulable_job)}
      get :index
      expect(response).to be_success
      expect(assigns(:schedulable_jobs).size).to eq(2)
    end
  end

  describe "edit" do
    before :each do
      @sj = Factory(:schedulable_job)
    end
    it "should only allow sys_admins" do
      login Factory(:user)
      get :edit, id: @sj.id
      expect(response).to be_redirect
      expect(flash[:errors].first).to match /Only system admins/
    end
    it "should load job" do
      login Factory(:sys_admin_user)
      get :edit, id: @sj.id
      expect(response).to be_success
      expect(assigns(:sj)).to eq(@sj)
    end
  end
  describe "update" do
    before :each do
      @sj = Factory(:schedulable_job,opts:'abc')
    end
    it "should only allow sys_admins" do
      login Factory(:user)
      put :update, id: @sj.id, schedulable_job:{opts:'12345'}
      expect(response).to be_redirect
      expect(flash[:errors].first).to match /Only system admins/
      @sj.reload
      expect(@sj.opts).to eq('abc')
    end
    it "should update job" do
      login Factory(:sys_admin_user)
      put :update, id: @sj.id, schedulable_job:{opts:'12345'}
      expect(response).to redirect_to schedulable_jobs_path
      @sj.reload
      expect(@sj.opts).to eq('12345')
    end
  end
  
  describe "new" do
    it "should only allow sys_admins" do
      login Factory(:user)
      get :new
      expect(response).to be_redirect
      expect(flash[:errors].first).to match /Only system admins/
    end
    it "should load empty job" do
      login Factory(:sys_admin_user)
      get :new
      expect(response).to be_success
      expect(assigns(:sj)).to be_instance_of(SchedulableJob)
    end
  end
  describe "create" do
    it "should only allow sys_admins" do
      login Factory(:user)
      post :create, schedulable_job:{opts:'12345'}
      expect(response).to be_redirect
      expect(flash[:errors].first).to match /Only system admins/
      expect(SchedulableJob.all).to be_empty
    end
    it "shoud make job" do
      login Factory(:sys_admin_user)
      post :create, schedulable_job:{opts:'12345'}
      expect(response).to redirect_to schedulable_jobs_path
      expect(SchedulableJob.first.opts).to eq('12345')
    end
  end

  describe "destroy" do
    before :each do
      @sj = Factory(:schedulable_job)
    end
    it "should only allow sys_admins" do
      login Factory(:user)
      delete :destroy, id:@sj.id
      expect(response).to be_redirect
      expect(flash[:errors].first).to match /Only system admins/
      expect(SchedulableJob.first).to eq(@sj)
    end
    it "should destroy job" do
      login Factory(:sys_admin_user)
      delete :destroy, id:@sj.id
      expect(response).to redirect_to schedulable_jobs_path
      expect(SchedulableJob.all).to be_empty
    end
  end

  describe "run" do
    before :each do
      @sj = Factory(:schedulable_job, run_class: "My::RunClass")
    end

    it "runs a job on demand" do
      login Factory(:sys_admin_user)
      sj = double
      expect_any_instance_of(SchedulableJob).to receive(:delay).and_return @sj
      expect(@sj).to receive(:run_if_needed).with(force_run: true)

      post :run, id: @sj.id

      expect(response).to redirect_to schedulable_jobs_path
      expect(flash[:notices].first).to eq "RunClass is running."
    end

    it "only allows sysadmins" do
      login Factory(:user)
      post :run, id: @sj.id
      expect(response).to be_redirect
      expect(flash[:errors].first).to match /Only system admins/
    end
  end

end
