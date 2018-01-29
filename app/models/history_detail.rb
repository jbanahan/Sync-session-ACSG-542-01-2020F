# == Schema Information
#
# Table name: history_details
#
#  id         :integer          not null, primary key
#  history_id :integer
#  source_key :string(255)
#  value      :string(255)
#  created_at :datetime         not null
#  updated_at :datetime         not null
#

class HistoryDetail < ActiveRecord::Base
  belongs_to :history
end
