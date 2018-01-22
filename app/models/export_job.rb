# == Schema Information
#
# Table name: export_jobs
#
#  id          :integer          not null, primary key
#  start_time  :datetime
#  end_time    :datetime
#  successful  :boolean
#  export_type :string(255)
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#

class ExportJob < ActiveRecord::Base
  has_many :export_job_links, :dependent=>:destroy
  has_many :attachments, :as => :attachable, :dependent=>:destroy
  
  EXPORT_TYPE_RL_CA_MM_INVOICE ||= "POLO CA MM INVOICE"
  EXPORT_TYPE_RL_CA_FFI_INVOICE ||= "POLO CA FFI INVOICE"
end
