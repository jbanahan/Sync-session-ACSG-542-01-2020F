# == Schema Information
#
# Table name: history_details
#
#  created_at :datetime         not null
#  history_id :integer
#  id         :integer          not null, primary key
#  source_key :string(255)
#  updated_at :datetime         not null
#  value      :string(255)
#

class HistoryDetail < ActiveRecord::Base
  attr_accessible :history_id, :source_key, :value

  belongs_to :history
end
