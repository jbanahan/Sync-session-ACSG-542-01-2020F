class OpenChain::FeedMonitor
  #only override current_time for unit testing purposes
  def self.monitor current_time = Time.now 
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
    if current_time.day.between?(1,5) && current_time.hour.between?(8,20)
      if timestamp && (current_time - timestamp) > 2.hours
        begin
          raise "#{monitor_name} not updating. Last updated at: #{timestamp}"
        rescue
          $!.log_me
        end
      end
    end
  end
  def self.monitor_entries source_system, current_time
    if MasterSetup.get.custom_feature?(source_system.downcase) 
      last_entry = Entry.select("updated_at").where(:source_system=>source_system).order("updated_at DESC").limit(1).first
      monitor_business_hours source_system, current_time, (last_entry ? last_entry.updated_at : nil) 
    end
  end
end
