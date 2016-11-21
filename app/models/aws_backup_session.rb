class AwsBackupSession < ActiveRecord::Base
  has_many :aws_snapshots, inverse_of: :aws_backup_session, dependent: :destroy, autosave: true

  def self.find_can_view(user)
    if user.sys_admin?
      AwsBackupSession.where("1=1")
    end
  end

end