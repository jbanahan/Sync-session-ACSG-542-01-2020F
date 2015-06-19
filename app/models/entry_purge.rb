class EntryPurge < ActiveRecord::Base
  attr_accessible :broker_reference, :country_iso, :date_purged, :source_system
end
