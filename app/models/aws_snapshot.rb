# == Schema Information
#
# Table name: aws_snapshots
#
#  aws_backup_session_id :integer          not null
#  created_at            :datetime         not null
#  description           :string(255)
#  end_time              :datetime
#  errored               :boolean
#  id                    :integer          not null, primary key
#  instance_id           :string(255)
#  purged_at             :datetime
#  snapshot_id           :string(255)
#  start_time            :datetime
#  tags_json             :text(65535)
#  updated_at            :datetime         not null
#  volume_id             :string(255)
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
