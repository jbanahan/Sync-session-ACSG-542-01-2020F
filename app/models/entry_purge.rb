# == Schema Information
#
# Table name: entry_purges
#
#  id               :integer          not null, primary key
#  broker_reference :string(255)
#  country_iso      :string(255)
#  source_system    :string(255)
#  date_purged      :datetime
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#

class EntryPurge < ActiveRecord::Base
  attr_accessible :broker_reference, :country_iso, :date_purged, :source_system
end
