class BulkProcessLog < ActiveRecord::Base
  BULK_TYPES ||= {update: "Bulk Update", classify: "Bulk Classify"}
  belongs_to :user
  has_many :change_records, :order => "failed DESC, record_sequence_number ASC"
  has_many :entity_snapshots

  def can_view? user
    user.sys_admin? || user.admin? || self.user_id == user.id
  end
end