class SyncRecord < ActiveRecord::Base
  belongs_to :syncable, :polymorphic => true
  validates :trading_partner, :presence=>true
  validates :syncable_id, :presence=>true
  validates :syncable_type, :presence=>true

  scope :problems, where("LENGTH(IFNULL(failure_message,\"\")) > 0 OR (sent_at < NOW() - INTERVAL 1 HOUR AND sent_at > IFNULL(confirmed_at,NOW() - INTERVAL 100 YEAR) )") 

  def problem?
    return true unless self.failure_message.blank?
    return false unless self.sent_at
    return true if self.sent_at < 1.hour.ago && (!self.confirmed_at || self.confirmed_at < self.sent_at)
    return false
  end
end
