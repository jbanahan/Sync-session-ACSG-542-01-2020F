# == Schema Information
#
# Table name: debug_records
#
#  id             :integer          not null, primary key
#  user_id        :integer
#  request_method :string(255)
#  request_params :text
#  request_path   :string(255)
#  created_at     :datetime
#  updated_at     :datetime
#

class DebugRecord < ActiveRecord::Base
  belongs_to :user

  validates :user, :presence => true

  def self.purge reference_date
    DebugRecord.where("created_at < ?", reference_date).delete_all
  end
end
