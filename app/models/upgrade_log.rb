# == Schema Information
#
# Table name: upgrade_logs
#
#  created_at              :datetime         not null
#  finished_at             :datetime
#  from_version            :string(255)
#  id                      :integer          not null, primary key
#  instance_information_id :integer
#  log                     :text(65535)
#  started_at              :datetime
#  to_version              :string(255)
#  updated_at              :datetime         not null
#

class UpgradeLog < ActiveRecord::Base
  attr_accessible :created_at, :finished_at, :from_version,
    :instance_information_id, :log, :started_at, :to_version,
    :updated_at

  belongs_to :instance_information
end
