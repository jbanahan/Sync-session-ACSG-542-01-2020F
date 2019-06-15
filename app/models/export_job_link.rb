# == Schema Information
#
# Table name: export_job_links
#
#  export_job_id   :integer          not null
#  exportable_id   :integer          not null
#  exportable_type :string(255)      not null
#  id              :integer          not null, primary key
#
# Indexes
#
#  index_export_job_links_on_export_job_id                      (export_job_id)
#  index_export_job_links_on_exportable_id_and_exportable_type  (exportable_id,exportable_type)
#

class ExportJobLink < ActiveRecord::Base
  attr_accessible :export_job_id, :exportable_id, :exportable_type
  
  belongs_to :exportable, :polymorphic => true
  belongs_to :export_job
end
