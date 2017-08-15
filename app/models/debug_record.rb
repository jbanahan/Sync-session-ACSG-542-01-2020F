class DebugRecord < ActiveRecord::Base
  belongs_to :user

  validates :user, :presence => true

  def self.purge reference_date
    DebugRecord.where("created_at < ?", reference_date).delete_all
  end
end
