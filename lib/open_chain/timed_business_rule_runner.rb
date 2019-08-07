module OpenChain; class TimedBusinessRuleRunner
  def self.run_schedulable opts = {}
    run_list = BusinessValidationScheduledJob.where("run_date <= ?", Time.zone.now)
    run_list.each do |job|
      obj = job.validatable
      Lock.db_lock(obj) do 
        BusinessValidationTemplate.create_results_for_object! obj
        job.destroy
      end
    end
  end
end; end
