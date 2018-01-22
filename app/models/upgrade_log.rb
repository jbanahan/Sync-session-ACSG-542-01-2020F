# == Schema Information
#
# Table name: upgrade_logs
#
#  id                      :integer          not null, primary key
#  from_version            :string(255)
#  to_version              :string(255)
#  started_at              :datetime
#  finished_at             :datetime
#  log                     :text
#  instance_information_id :integer
#  created_at              :datetime
#  updated_at              :datetime
#

class UpgradeLog < ActiveRecord::Base
  belongs_to :instance_information
end
