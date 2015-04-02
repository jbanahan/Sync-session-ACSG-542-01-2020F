class OpenChain::FeedMonitor

  def self.run_schedulable
    monitor
  end

  #only override current_time for unit testing purposes
  def self.monitor current_time = Time.zone.now 
    current_time = current_time.in_time_zone "Eastern Time (US & Canada)"

    monitor_entries 'Alliance', current_time
    monitor_entries 'Fenix', current_time
    if MasterSetup.get.custom_feature?('alliance')
      last_image = Attachment.select("attachments.updated_at").joins("INNER JOIN entries on attachments.attachable_type = \"Entry\" and attachments.attachable_id = entries.id").
        where("entries.source_system = \"Alliance\"").order("attachments.updated_at DESC").limit(1).first
      monitor_business_hours 'Alliance Imaging', current_time, (last_image ? last_image.updated_at : nil)
    end
  end

  private 
  def self.monitor_business_hours monitor_name, current_time, timestamp
    if current_time.wday.between?(1,5) && current_time.hour.between?(8,20)
      if timestamp && (current_time - timestamp) > 2.hours
        StandardError.new("#{monitor_name} not updating. Last recorded data exported: #{timestamp.in_time_zone("Eastern Time (US & Canada)").strftime('%Y-%m-%d %H:%M %Z')}").log_me
      end
    end
  end
  def self.monitor_entries source_system, current_time
    if MasterSetup.get.custom_feature?(source_system.downcase) 
      last_entry = Entry.select("last_exported_from_source").where(:source_system=>source_system).order("last_exported_from_source DESC").limit(1).first
      monitor_business_hours source_system, current_time, (last_entry ? last_entry.last_exported_from_source : nil) 
    end
  end
end
