class TariffFileUploadReceipt < ActiveRecord::Base
  belongs_to :tariff_file_upload_instance, inverse_of: :tariff_file_upload_receipts
end