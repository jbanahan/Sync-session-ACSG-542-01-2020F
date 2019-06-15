# == Schema Information
#
# Table name: bulk_process_logs
#
#  bulk_type            :string(255)
#  changed_object_count :integer
#  created_at           :datetime         not null
#  finished_at          :datetime
#  id                   :integer          not null, primary key
#  started_at           :datetime
#  total_object_count   :integer
#  updated_at           :datetime         not null
#  user_id              :integer
#

class BulkProcessLog < ActiveRecord::Base

  attr_accessible :bulk_type, :changed_object_count, :finished_at, 
    :started_at, :total_object_count, :user_id, :user
  
  BULK_TYPES ||= {update: "Bulk Update", classify: "Bulk Classify"}
  belongs_to :user
  has_many :change_records, -> { order([{failed: :desc}, :record_sequence_number]) }
  has_many :entity_snapshots

  def self.with_log user, bulk_type
    log = BulkProcessLog.create!(user:user,bulk_type:bulk_type,started_at:Time.now)
    yield log
    log.update_attributes(finished_at:Time.now,changed_object_count:log.change_records.count)
    log.notify_user!
  end

  def can_view? user
    user.sys_admin? || user.admin? || self.user_id == user.id
  end

  def notify_user!
    m = self.user.messages.new
    m.subject = "#{self.bulk_type} Job Complete"
    error_count = self.change_records.where(failed:true).count
    m.subject << " (#{error_count} #{"error".pluralize(error_count)})" if error_count > 0
    url = "https://#{MasterSetup.get.request_host}/bulk_process_logs/#{self.id}"
    m.body = "<p>Your #{self.bulk_type} job is complete.</p><p>#{self.changed_object_count} records were updated.</p><p>The full update log is available <a href=\"#{url}\">here</a>.</p>"
    m.save!
    m
  end
end
