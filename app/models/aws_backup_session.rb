# == Schema Information
#
# Table name: aws_backup_sessions
#
#  id         :integer          not null, primary key
#  name       :string(255)
#  start_time :datetime
#  end_time   :datetime
#  log        :text
#  created_at :datetime         not null
#  updated_at :datetime         not null
#

class AwsBackupSession < ActiveRecord::Base
  has_many :aws_snapshots, inverse_of: :aws_backup_session, dependent: :destroy, autosave: true

  def self.find_can_view(user)
    if user.sys_admin?
      AwsBackupSession.where("1=1")
    end
  end

end
