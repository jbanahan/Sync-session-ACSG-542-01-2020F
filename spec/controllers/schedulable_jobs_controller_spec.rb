describe SchedulableJobsController do

  describe "index" do
    it "onlies allow sys_admins" do
      sign_in_as FactoryBot(:user)
      get :index
      expect(response).to be_redirect
      expect(flash[:errors].first).to match(/Only system admins/)
    end

    it "loads all jobs" do
      sign_in_as FactoryBot(:sys_admin_user)
      # The sorting of the classes should be based on their class name (sans module)
      FactoryBot(:schedulable_job, run_class: "A::Fully::Qualified::Module::FirstClassName")
      FactoryBot(:schedulable_job, run_class: "Seoncd::Fully::Qualified::Module::ClassName")

      get :index
      expect(response).to be_success
      expect(assigns(:schedulable_jobs).map(&:run_class_name)).to eq ["ClassName", "FirstClassName"]
    end
  end

  describe "edit" do
    let(:schedulable_job) { FactoryBot(:schedulable_job) }

    it "only allows sys_admins" do
      sign_in_as FactoryBot(:user)
      get :edit, id: schedulable_job.id
      expect(response).to be_redirect
      expect(flash[:errors].first).to match(/Only system admins/)
    end

    it "loads job" do
      sign_in_as FactoryBot(:sys_admin_user)
      get :edit, id: schedulable_job.id
      expect(response).to be_success
      expect(assigns(:sj)).to eq(schedulable_job)
    end
  end

  describe "update" do
    let (:schedulable_job) { FactoryBot(:schedulable_job, opts: '{"abc": 123}') }

    it "only allows sys_admins" do
      sign_in_as FactoryBot(:user)
      put :update, id: schedulable_job.id, schedulable_job: {opts: '12345'}
      expect(response).to be_redirect
      expect(flash[:errors].first).to match(/Only system admins/)
      schedulable_job.reload
      expect(schedulable_job.opts).to eq('{"abc": 123}')
    end

    context "with sys admin login" do

      before do
        sign_in_as FactoryBot(:sys_admin_user)
      end

      it "updates job" do
        put :update, id: schedulable_job.id, schedulable_job: {opts: '{"abc": 987}'}
        expect(response).to redirect_to schedulable_jobs_path
        schedulable_job.reload
        expect(schedulable_job.opts).to eq('{"abc": 987}')
      end

      it "fails to update if ops are an invalid json string" do
        put :update, id: schedulable_job.id, schedulable_job: {opts: 'invalid'}
        expect(assigns(:sj)).to eq schedulable_job
        expect(flash[:errors].length).to eq 1
        expect(flash[:errors].first).to include "unexpected token at 'invalid'"
      end
    end
  end

  describe "new" do
    it "onlies allow sys_admins" do
      sign_in_as FactoryBot(:user)
      get :new
      expect(response).to be_redirect
      expect(flash[:errors].first).to match(/Only system admins/)
    end

    it "loads empty job" do
      sign_in_as FactoryBot(:sys_admin_user)
      get :new
      expect(response).to be_success
      expect(assigns(:sj)).to be_instance_of(SchedulableJob)
    end
  end

  describe "create" do
    it "onlies allow sys_admins" do
      sign_in_as FactoryBot(:user)
      post :create, schedulable_job: {opts: '{"opt":12345}'}
      expect(response).to be_redirect
      expect(flash[:errors].first).to match(/Only system admins/)
      expect(SchedulableJob.all).to be_empty
    end

    it "shoud make job" do
      sign_in_as FactoryBot(:sys_admin_user)
      post :create, schedulable_job: {opts: '{"opt":12345}'}
      expect(response).to redirect_to schedulable_jobs_path
      expect(SchedulableJob.first.opts).to eq('{"opt":12345}')
    end
  end

  describe "destroy" do
    let(:schedulable_job) { FactoryBot(:schedulable_job) }

    it "only allows sys_admins" do
      sign_in_as FactoryBot(:user)
      delete :destroy, id: schedulable_job.id
      expect(response).to be_redirect
      expect(flash[:errors].first).to match(/Only system admins/)
      expect(SchedulableJob.first).to eq(schedulable_job)
    end

    it "destroys job" do
      sign_in_as FactoryBot(:sys_admin_user)
      delete :destroy, id: schedulable_job.id
      expect(response).to redirect_to schedulable_jobs_path
      expect(SchedulableJob.all).to be_empty
    end
  end

  describe "run" do
    let (:scheduled_job) { FactoryBot(:schedulable_job, run_class: "My::RunClass") }

    it "runs a job on demand" do
      sign_in_as FactoryBot(:sys_admin_user)
      expect_any_instance_of(SchedulableJob).to receive(:delay).and_return scheduled_job
      expect(scheduled_job).to receive(:run_if_needed).with(force_run: true)

      post :run, id: scheduled_job.id

      expect(response).to redirect_to schedulable_jobs_path
      expect(flash[:notices].first).to eq "RunClass is running."
    end

    it "runs with adjusted priority" do
      scheduled_job.update! queue_priority: 100
      sign_in_as FactoryBot(:sys_admin_user)
      expect_any_instance_of(SchedulableJob).to receive(:delay).with(priority: 100).and_return scheduled_job
      expect(scheduled_job).to receive(:run_if_needed).with(force_run: true)

      post :run, id: scheduled_job.id
    end

    it "only allows sysadmins" do
      sign_in_as FactoryBot(:user)
      post :run, id: scheduled_job.id
      expect(response).to be_redirect
      expect(flash[:errors].first).to match(/Only system admins/)
    end
  end

  describe "reset_run_flag" do
    let (:schedulable_job) { FactoryBot(:schedulable_job, run_class: "My::RunClass", running: true)}

    it "unsets the runing flag" do
      sign_in_as FactoryBot(:sys_admin_user)
      post :reset_run_flag, id: schedulable_job.id

      expect(response).to redirect_to schedulable_jobs_path
      expect(flash[:notices].first).to eq "RunClass has been marked as not running."
      expect(schedulable_job.reload).not_to be_running
    end

    it "only allows sysadmins" do
      sign_in_as FactoryBot(:user)
      post :reset_run_flag, id: schedulable_job.id
      expect(response).to be_redirect
      expect(flash[:errors].first).to match(/Only system admins/)
    end
  end
end
