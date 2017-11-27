class SchedulableJobsController < ApplicationController
  def set_page_title
    @page_title = 'Tools'
  end
  def index
    sys_admin_secure do
      jobs = SchedulableJob.all
      @schedulable_jobs  = jobs.sort_by {|a| a.run_class_name.to_s.upcase }
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
      @sj = SchedulableJob.new(params[:schedulable_job])
      if @sj.save
        add_flash :notices, "Created"
      else
        add_flash :errors, "Job could not be created due to invalid parameters."
      end
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

  def run
    sys_admin_secure do
      sj = SchedulableJob.find(params[:id])
      if !sj.queue_priority.nil?
        sj = sj.delay(priority: sj.queue_priority)
      else
        sj = sj.delay()
      end

      sj.run_if_needed force_run: true
      add_flash :notices, "#{sj.run_class_name} is running."
      
      redirect_to schedulable_jobs_path
    end
  end

  def reset_run_flag
    sys_admin_secure do
      sj = SchedulableJob.find(params[:id])
      sj.running = false
      sj.save!

      add_flash :notices, "#{sj.run_class_name} has been marked as not running."
      
      redirect_to schedulable_jobs_path
    end
  end
end
