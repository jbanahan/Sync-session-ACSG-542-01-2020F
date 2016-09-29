class AwsBackupSession < ActiveRecord::Base
  has_many :aws_snapshots, inverse_of: :aws_backup_session, dependent: :destroy, autosave: true
end