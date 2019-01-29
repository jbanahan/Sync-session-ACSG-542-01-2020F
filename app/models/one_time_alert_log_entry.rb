# == Schema Information
#
# Table name: one_time_alert_log_entries
#
#  alertable_id      :integer
#  alertable_type    :string(255)
#  created_at        :datetime         not null
#  id                :integer          not null, primary key
#  logged_at         :datetime
#  one_time_alert_id :integer
#  reference_fields  :string(255)
#  updated_at        :datetime         not null
#

class OneTimeAlertLogEntry < ActiveRecord::Base
  belongs_to :alertable, polymorphic: true, inverse_of: :alert_log_entries
  belongs_to :one_time_alert
end
