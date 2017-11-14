require 'spec_helper'

describe SchedulableJobsController do
  
  describe "index" do
    it "should only allow sys_admins" do
      sign_in_as Factory(:user)
      get :index
      expect(response).to be_redirect
      expect(flash[:errors].first).to match /Only system admins/
    end
    it "should load all jobs" do
      sign_in_as Factory(:sys_admin_user)
      # The sorting of the classes should be based on their class name (sans module)
      sj1 = Factory(:schedulable_job, run_class: "A::Fully::Qualified::Module::FirstClassName")
      sj2 = Factory(:schedulable_job, run_class: "Seoncd::Fully::Qualified::Module::ClassName")

      get :index
      expect(response).to be_success
      expect(assigns(:schedulable_jobs).map(&:run_class_name)).to eq ["ClassName", "FirstClassName"]
    end
  end

  describe "edit" do
    before :each do
      @sj = Factory(:schedulable_job)
    end
    it "should only allow sys_admins" do
      sign_in_as Factory(:user)
      get :edit, id: @sj.id
      expect(response).to be_redirect
      expect(flash[:errors].first).to match /Only system admins/
    end
    it "should load job" do
      sign_in_as Factory(:sys_admin_user)
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
      sign_in_as Factory(:user)
      put :update, id: @sj.id, schedulable_job:{opts:'12345'}
      expect(response).to be_redirect
      expect(flash[:errors].first).to match /Only system admins/
      @sj.reload
      expect(@sj.opts).to eq('abc')
    end
    it "should update job" do
      sign_in_as Factory(:sys_admin_user)
      put :update, id: @sj.id, schedulable_job:{opts:'12345'}
      expect(response).to redirect_to schedulable_jobs_path
      @sj.reload
      expect(@sj.opts).to eq('12345')
    end
  end
  
  describe "new" do
    it "should only allow sys_admins" do
      sign_in_as Factory(:user)
      get :new
      expect(response).to be_redirect
      expect(flash[:errors].first).to match /Only system admins/
    end
    it "should load empty job" do
      sign_in_as Factory(:sys_admin_user)
      get :new
      expect(response).to be_success
      expect(assigns(:sj)).to be_instance_of(SchedulableJob)
    end
  end
  describe "create" do
    it "should only allow sys_admins" do
      sign_in_as Factory(:user)
      post :create, schedulable_job:{opts:'12345'}
      expect(response).to be_redirect
      expect(flash[:errors].first).to match /Only system admins/
      expect(SchedulableJob.all).to be_empty
    end
    it "shoud make job" do
      sign_in_as Factory(:sys_admin_user)
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
      sign_in_as Factory(:user)
      delete :destroy, id:@sj.id
      expect(response).to be_redirect
      expect(flash[:errors].first).to match /Only system admins/
      expect(SchedulableJob.first).to eq(@sj)
    end
    it "should destroy job" do
      sign_in_as Factory(:sys_admin_user)
      delete :destroy, id:@sj.id
      expect(response).to redirect_to schedulable_jobs_path
      expect(SchedulableJob.all).to be_empty
    end
  end

  describe "run" do
    let (:scheduled_job) { Factory(:schedulable_job, run_class: "My::RunClass") }

    it "runs a job on demand" do
      sign_in_as Factory(:sys_admin_user)
      expect_any_instance_of(SchedulableJob).to receive(:delay).and_return scheduled_job
      expect(scheduled_job).to receive(:run_if_needed).with(force_run: true)

      post :run, id: scheduled_job.id

      expect(response).to redirect_to schedulable_jobs_path
      expect(flash[:notices].first).to eq "RunClass is running."
    end

    it "runs with adjusted priority" do
      scheduled_job.update_attributes! queue_priority: 100
      sign_in_as Factory(:sys_admin_user)
      expect_any_instance_of(SchedulableJob).to receive(:delay).with(priority: 100).and_return scheduled_job
      expect(scheduled_job).to receive(:run_if_needed).with(force_run: true)

      post :run, id: scheduled_job.id
    end

    it "only allows sysadmins" do
      sign_in_as Factory(:user)
      post :run, id: scheduled_job.id
      expect(response).to be_redirect
      expect(flash[:errors].first).to match /Only system admins/
    end
  end

  describe "reset_run_flag" do
    let (:schedulable_job) { Factory(:schedulable_job, run_class: "My::RunClass", running: true)}

    it "unsets the runing flag" do
      sign_in_as Factory(:sys_admin_user)
      post :reset_run_flag, id: schedulable_job.id

      expect(response).to redirect_to schedulable_jobs_path
      expect(flash[:notices].first).to eq "RunClass has been marked as not running."
      expect(schedulable_job.reload).not_to be_running
    end

    it "only allows sysadmins" do
      sign_in_as Factory(:user)
      post :reset_run_flag, id: schedulable_job.id
      expect(response).to be_redirect
      expect(flash[:errors].first).to match /Only system admins/
    end
  end
end
