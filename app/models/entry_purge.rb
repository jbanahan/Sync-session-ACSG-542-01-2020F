# == Schema Information
#
# Table name: entry_purges
#
#  broker_reference :string(255)
#  country_iso      :string(255)
#  created_at       :datetime         not null
#  date_purged      :datetime
#  id               :integer          not null, primary key
#  source_system    :string(255)
#  updated_at       :datetime         not null
#

class EntryPurge < ActiveRecord::Base
end
