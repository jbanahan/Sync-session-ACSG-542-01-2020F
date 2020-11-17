# == Schema Information
#
# Table name: debug_records
#
#  created_at     :datetime         not null
#  id             :integer          not null, primary key
#  request_method :string(255)
#  request_params :text(65535)
#  request_path   :string(255)
#  updated_at     :datetime         not null
#  user_id        :integer
#

class DebugRecord < ActiveRecord::Base
  belongs_to :user

  validates :user, :presence => true

  def self.purge reference_date
    DebugRecord.where("created_at < ?", reference_date).delete_all
  end
end
