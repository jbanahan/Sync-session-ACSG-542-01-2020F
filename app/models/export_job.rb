# == Schema Information
#
# Table name: export_jobs
#
#  created_at  :datetime         not null
#  end_time    :datetime
#  export_type :string(255)
#  id          :integer          not null, primary key
#  start_time  :datetime
#  successful  :boolean
#  updated_at  :datetime         not null
#

class ExportJob < ActiveRecord::Base
  attr_accessible :end_time, :export_type, :start_time, :successful

  has_many :export_job_links, :dependent=>:destroy
  has_many :attachments, :as => :attachable, :dependent=>:destroy

  EXPORT_TYPE_RL_CA_MM_INVOICE ||= "POLO CA MM INVOICE"
  EXPORT_TYPE_RL_CA_FFI_INVOICE ||= "POLO CA FFI INVOICE"
end
