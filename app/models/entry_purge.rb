class EntryPurge < ActiveRecord::Base
  attr_accessible :broker_reference, :country_iso, :date_purged, :source_system
  after_create do
    self.date_purged = created_at
    save
  end 
end
