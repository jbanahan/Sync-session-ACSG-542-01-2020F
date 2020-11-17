# == Schema Information
#
# Table name: entry_pga_summaries
#
#  agency_code                :string(255)      not null
#  created_at                 :datetime
#  entry_id                   :integer          not null
#  id                         :integer          not null, primary key
#  total_claimed_pga_lines    :integer
#  total_disclaimed_pga_lines :integer
#  total_pga_lines            :integer
#  updated_at                 :datetime
#
# Indexes
#
#  index_entry_pga_summaries_on_entry_id  (entry_id)
#

class EntryPgaSummary < ActiveRecord::Base
  belongs_to :entry, inverse_of: :entry_pga_summaries
end
