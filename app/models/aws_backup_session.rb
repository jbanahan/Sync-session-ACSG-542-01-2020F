# == Schema Information
#
# Table name: aws_backup_sessions
#
#  created_at :datetime         not null
#  end_time   :datetime
#  id         :integer          not null, primary key
#  log        :text(65535)
#  name       :string(255)
#  start_time :datetime
#  updated_at :datetime         not null
#

class AwsBackupSession < ActiveRecord::Base
  attr_accessible :end_time, :log, :name, :start_time

  has_many :aws_snapshots, inverse_of: :aws_backup_session, dependent: :destroy, autosave: true

  def self.find_can_view(user)
    if user.sys_admin?
      AwsBackupSession.where("1=1")
    end
  end

end
