class EntryPurge < ActiveRecord::Base
  attr_accessible :broker_reference, :country, :date_purged, :iso, :source_system
end
