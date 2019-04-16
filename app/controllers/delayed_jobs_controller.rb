require 'open_chain/delayed_job_extensions'

class DelayedJobsController < ApplicationController
  include OpenChain::DelayedJobExtensions

  def run_now
    dj = Delayed::Job.find params[:id]
    if !dj.locked_at?
      dj.update_attributes!(priority: -1000, run_at: Time.zone.now)
      add_flash :notices, "Delayed Job #{dj.id} will run next."
      redirect_to request.referrer
    else
      error_redirect "Delayed Job #{dj.id} can't be scheduled because it is locked."
    end
  end

  def destroy
    @delayed_job = Delayed::Job.find(params[:id])
    sys_admin_secure {
      @delayed_job.destroy
      errors_to_flash @delayed_job
      respond_to do |format|
        format.html { redirect_to(request.referrer) }
        format.xml  { head :ok }
      end
    }
  end

  def bulk_destroy
    ids_to_destroy = group_jobs[params[:id].to_i]
    sys_admin_secure {
      Delayed::Job.transaction do
        djs_to_destroy = Delayed::Job.where(id: ids_to_destroy, locked_at: nil)
        djs_to_destroy.each do |dj|
          dj.destroy
          errors_to_flash dj
        end
      end
      redirect_to(request.referrer)
    }
  end
end
