require 'open_chain/entity_compare/multi_class_comparator'

module OpenChain; module EntityCompare; class TimedBusinessRuleComparator
  CORE_MODULES = ["Entry", "Order", "Product"]

  extend OpenChain::EntityCompare::MultiClassComparator.includes(*CORE_MODULES)

  def self.compare type, id, old_bucket, old_path, old_version, new_bucket, new_path, new_version
    obj = type.constantize.where(id: id).first
    return unless obj

    Lock.db_lock(obj) do
      BusinessValidationSchedule.all.each do |sched|
        return if sched.search_criterions.empty? || sched.model_field_uid.blank? || sched.num_days.blank? || sched.operator.blank?
        schedule_applies = false
        sched.search_criterions.each do |sc|
          schedule_applies = sc.test?(obj)
          break unless schedule_applies
        end
        schedule_entity obj, sched if schedule_applies
      end
    end
  end

  def self.schedule_entity obj, schedule
    mf = ModelField.find_by_uid schedule.model_field_uid
    base_date = mf.process_export(obj, nil)
    return unless base_date
    
    if schedule.operator == "Before"
      offset = date?(mf) ? 1.day : 1.second
      run_date = base_date - (schedule.num_days.days + offset)
    else
      run_date = base_date + schedule.num_days.days
    end

    assign = false
    if date? mf
      assign = run_date > Time.zone.now.to_date
    else
      assign = run_date >= Time.zone.now
    end

    assign_job(schedule, obj, run_date) if assign
  end

  def self.date? mf
    mf.data_type == :date
  end

  def self.assign_job schedule, obj, run_date
    run_date_str = run_date.strftime("%Y-%m-%d %H:%M:%S")
    job_settings = { validatable_id: obj.id, validatable_type: obj.class.to_s, run_date: Time.zone.parse(run_date_str) }
    job = schedule.business_validation_scheduled_jobs.find{ |j| j.validatable == obj }
    if job
      job.update_attributes! job_settings unless job.run_date == run_date
    else
      schedule.business_validation_scheduled_jobs.create! job_settings
    end
  end

end; end; end  
