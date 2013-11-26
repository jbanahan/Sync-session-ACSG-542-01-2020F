class SchedulableJobsController < ApplicationController
  def index
    sys_admin_secure do
      @schedulable_jobs = SchedulableJob.order(:run_class)  
    end
  end

  def edit
    sys_admin_secure do
      @sj = SchedulableJob.find params[:id]
    end
  end

  def update
    sys_admin_secure do
      sj = SchedulableJob.find params[:id]
      sj.update_attributes(params[:schedulable_job])
      add_flash :notices, 'Saved'
      redirect_to schedulable_jobs_path
    end
  end

  def new
    sys_admin_secure do
      @sj = SchedulableJob.new
    end
  end

  def create
    sys_admin_secure do
      SchedulableJob.create! params[:schedulable_job]
      add_flash :notices, 'Created'
      redirect_to schedulable_jobs_path
    end
  end

  def destroy
    sys_admin_secure do
      SchedulableJob.find(params[:id]).destroy
      add_flash :notices, 'Deleted'
      redirect_to schedulable_jobs_path
    end
  end
end
