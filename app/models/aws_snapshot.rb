# == Schema Information
#
# Table name: aws_snapshots
#
#  id                    :integer          not null, primary key
#  snapshot_id           :string(255)
#  description           :string(255)
#  instance_id           :string(255)
#  volume_id             :string(255)
#  tags_json             :text
#  start_time            :datetime
#  end_time              :datetime
#  errored               :boolean
#  purged_at             :datetime
#  aws_backup_session_id :integer          not null
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#
# Indexes
#
#  index_aws_snapshots_on_aws_backup_session_id  (aws_backup_session_id)
#  index_aws_snapshots_on_instance_id            (instance_id)
#  index_aws_snapshots_on_snapshot_id            (snapshot_id)
#

class AwsSnapshot < ActiveRecord::Base
  belongs_to :aws_backup_session, inverse_of: :aws_snapshots

  def tags
    j = self.tags_json
    j.blank? ? {} : ActiveSupport::JSON.decode(j)
  end

  def tags= tags
    if tags.nil?
      self.tags_json = nil
    else
      self.tags_json = ActiveSupport::JSON.encode(tags)  
    end
  end
end
