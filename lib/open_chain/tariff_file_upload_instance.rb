class TariffFileUploadInstance < ActiveRecord::Base
  belongs_to :tariff_file_upload_definition, inverse_of: :tariff_file_upload_instances
  has_many :tariff_file_upload_receipts, dependent: :destroy, autosave: true, inverse_of: :tariff_file_upload_instance
end