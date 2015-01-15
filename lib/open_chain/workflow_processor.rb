require 'open_chain/stat_client'

module OpenChain; class WorkflowProcessor
  def initialize opts = {}
    inner_opts = {stat_client:OpenChain::StatClient}.merge(opts)
    @stat_client = inner_opts[:stat_client]
  end

  def process! base_object, user
    deciders = prep_decider_hash[base_object.class]
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

  private
  def update_workflow_processor_run base_object
    wpr = base_object.workflow_processor_run
    wpr ||= base_object.build_workflow_processor_run
    wpr.finished_at = 0.seconds.ago
    wpr.save!
  end
  def prep_decider_hash
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
end; end