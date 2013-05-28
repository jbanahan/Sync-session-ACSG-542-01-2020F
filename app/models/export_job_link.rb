class ExportJobLink < ActiveRecord::Base
  belongs_to :exportable, :polymorphic => true
  belongs_to :export_job
end