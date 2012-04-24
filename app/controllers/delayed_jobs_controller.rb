class DelayedJobsController < ApplicationController
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
end
