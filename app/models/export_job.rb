class ExportJob < ActiveRecord::Base
  has_many :export_job_links, :dependent=>:destroy
  has_many :attachments, :as => :attachable, :dependent=>:destroy
  
  EXPORT_TYPE_RL_CA_MM_INVOICE ||= "POLO CA MM INVOICE"
  EXPORT_TYPE_RL_CA_FFI_INVOICE ||= "POLO CA FFI INVOICE"
end