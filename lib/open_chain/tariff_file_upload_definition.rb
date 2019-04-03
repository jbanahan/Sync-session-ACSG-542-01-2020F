class TariffFileUploadDefinition < ActiveRecord::Base
  has_many :tariff_file_upload_instances, dependent: :destroy, autosave: true, inverse_of: :tariff_file_upload_definition
end