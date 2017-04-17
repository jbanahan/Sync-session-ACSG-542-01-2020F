class SyncRecord < ActiveRecord::Base
  belongs_to :syncable, polymorphic: true, inverse_of: :sync_records
  validates :trading_partner, :presence=>true
  belongs_to :ftp_session

  scope :problems, lambda { where(self.problems_clause()) }

  def problem?
    return true unless self.failure_message.blank?
    return false unless self.sent_at
    return true if self.sent_at < 1.hour.ago && (!self.confirmed_at || self.confirmed_at < self.sent_at)
    return false
  end

  def self.problems_clause clause_alias = ""
    "LENGTH(IFNULL(#{clause_alias}failure_message,\"\")) > 0 OR (#{clause_alias}sent_at < NOW() - INTERVAL 1 HOUR AND #{clause_alias}sent_at > IFNULL(#{clause_alias}confirmed_at,NOW() - INTERVAL 100 YEAR) )"
  end

  def copy_attributes_to sr
    copy_attrs = self.attributes.keys - ['id', 'syncable_id', 'syncable_type', 'created_at', 'updated_at']
    attrs = {}
    copy_attrs.each do |k|
      attrs[k] = self[k]
    end
    sr.assign_attributes attrs
    nil
  end
end
