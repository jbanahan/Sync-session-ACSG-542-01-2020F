# == Schema Information
#
# Table name: sync_records
#
#  confirmation_file_name :string(255)
#  confirmed_at           :datetime
#  created_at             :datetime         not null
#  failure_message        :string(255)
#  fingerprint            :string(255)
#  ftp_session_id         :integer
#  id                     :integer          not null, primary key
#  ignore_updates_before  :datetime
#  sent_at                :datetime
#  syncable_id            :integer
#  syncable_type          :string(255)
#  trading_partner        :string(255)
#  updated_at             :datetime         not null
#
# Indexes
#
#  index_sync_records_id_type_trading_partner_fingerprint  (syncable_id,syncable_type,trading_partner,fingerprint) UNIQUE
#  index_sync_records_on_ftp_session_id                    (ftp_session_id)
#  index_sync_records_on_trading_partner                   (trading_partner)
#

class SyncRecord < ActiveRecord::Base
  attr_accessible :confirmation_file_name, :confirmed_at, :failure_message, 
    :fingerprint, :ftp_session_id, :ignore_updates_before, :sent_at, 
    :syncable_id, :syncable_type, :trading_partner, :syncable, :created_at
  
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
