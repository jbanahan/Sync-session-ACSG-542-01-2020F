# == Schema Information
#
# Table name: entity_comparator_logs
#
#  created_at      :datetime         not null
#  id              :integer          not null, primary key
#  new_bucket      :string(255)
#  new_path        :string(255)
#  new_version     :string(255)
#  old_bucket      :string(255)
#  old_path        :string(255)
#  old_version     :string(255)
#  recordable_id   :integer
#  recordable_type :string(255)
#  updated_at      :datetime         not null
#
# Indexes
#
#  index_entity_comparator_logs_rec_id_and_rec_type  (recordable_id,recordable_type)
#

class EntityComparatorLog < ActiveRecord::Base

  belongs_to :recordable, polymorphic: true

  # By default, only keep these records for six months
  def self.purge reference_date: (Time.zone.now - 6.months)
    EntityComparatorLog.where("created_at < ?", reference_date).delete_all
  end
end
