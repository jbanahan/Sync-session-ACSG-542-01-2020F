require 'open_chain/stat_client'

module OpenChain; class WorkflowProcessor

  #compatibility method for schedulable job engine
  def self.run_schedulable
    process_all! User.integration
  end

  def self.process_all! user, opts={}
    prep_decider_hash.keys.each do |k|
      process_class! k, user, opts
    end
  end
  def self.process_class! base_object_class, user, opts = {}
    p = self.new(opts)
    self.objects_need_processing(base_object_class).each do |obj|
      p.process!(obj,user)
    end
  end
  def self.objects_need_processing base_object_class
    table_name = base_object_class.table_name
    class_name = base_object_class.name
    join =<<-JOIN
INNER JOIN (
SELECT 
  obj.id,
  obj.updated_at,
  max(cv.updated_at),
  max(wt.updated_at),
  wpr.finished_at
FROM 
  #{table_name} obj
  LEFT OUTER JOIN custom_values cv ON cv.customizable_type = '#{class_name}' and cv.customizable_id = obj.id
  LEFT OUTER JOIN workflow_processor_runs wpr ON wpr.base_object_type = '#{class_name}' and wpr.base_object_id = obj.id
  LEFT OUTER JOIN workflow_instances wi on wi.base_object_type = '#{class_name}' and wi.base_object_id = obj.id
  LEFT OUTER JOIN workflow_tasks wt on wt.workflow_instance_id = wi.id 
GROUP BY obj.id
HAVING ifnull(wpr.finished_at,DATE('1970-01-01')) < GREATEST(obj.updated_at,ifnull(max(cv.updated_at),DATE('1969-01-01')),ifnull(max(wt.updated_at),DATE('1969-01-01')))) x on x.id = #{table_name}.id
    JOIN

    return base_object_class.select("#{table_name}.*").joins(join)
  end

  def self.async_process base_object, user=User.integration
    j = Class.new do
      include SuckerPunch::Job

      def perform obj, u
        # The connection pool stuff is needed since SuckerPunch / Celluloid ends up runnign the following
        # code in a seperate thread which will not have a sql connection established yet, so we get a new one
        # and run in that.
        ActiveRecord::Base.connection_pool.with_connection do
          OpenChain::WorkflowProcessor.new.process!(obj,u)
        end
      end
    end
    j.new.async.perform(base_object,user)
  end

  def initialize opts = {}
    inner_opts = {stat_client:OpenChain::StatClient}.merge(opts)
    @stat_client = inner_opts[:stat_client]
  end

  def process! base_object, user
    deciders = self.class.prep_decider_hash[base_object.class]
    return if deciders.blank?
    #not going to report wall time for instances where no deciders are found
    @stat_client.wall_time 'wf_processor' do
      deciders.each do |d|
        d.update_workflow! base_object, user
      end
      update_workflow_processor_run base_object
    end
    nil
  end

  def self.prep_decider_hash
    cache_prep_try_count = 0
    @@cache_rebuilding ||= false
    while @@cache_rebuilding
      raise "Cache rebuild timeout because @@cache_rebuilding still true." if cache_prep_try_count > 5
      cache_prep_try_count += 1
      sleep 1
    end
    @@cached_master_setup_time ||= 100.years.ago
    master_setup_time = MasterSetup.pluck(:updated_at).first
    if master_setup_time > @@cached_master_setup_time
      begin
        @@cache_rebuilding = true
        @@workflow_class_hash = {}
        
        workflow_classes_str = MasterSetup.pluck(:workflow_classes).first
        if !workflow_classes_str.blank?
          workflow_classes_str.lines.each do |cname|
            cname.strip!
            next if cname.blank?
            require cname.underscore
            k = cname.constantize
            base_object_class = k.base_object_class
            @@workflow_class_hash[base_object_class] ||= []
            @@workflow_class_hash[base_object_class] << k
          end
        end
      ensure
        @@cache_rebuilding = false
      end
    end
    @@workflow_class_hash
  end

  private
  def update_workflow_processor_run base_object
    wpr = base_object.workflow_processor_run
    wpr ||= base_object.build_workflow_processor_run
    wpr.finished_at = 0.seconds.ago
    wpr.save!
  end
end; end