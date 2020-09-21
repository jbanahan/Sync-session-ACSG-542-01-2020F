# == Schema Information
#
# Table name: inbound_file_identifiers
#
#  id              :integer          not null, primary key
#  identifier_type :string(255)
#  inbound_file_id :integer
#  module_id       :integer
#  module_type     :string(255)
#  value           :string(255)
#
# Indexes
#
#  index_inbound_file_identifiers_on_identifier_type_and_value  (identifier_type,value)
#  index_inbound_file_identifiers_on_inbound_file_id            (inbound_file_id)
#  index_inbound_file_identifiers_on_module_id                  (module_id)
#  index_inbound_file_identifiers_on_module_type_and_module_id  (module_type,module_id)
#  index_inbound_file_identifiers_on_value                      (value)
#

class InboundFileIdentifier < ActiveRecord::Base
  attr_accessible :identifier_type, :inbound_file_id, :module_id, :module_type, :value

  belongs_to :inbound_file, inverse_of: :identifiers

  TYPE_ARTICLE_NUMBER = "Article Number".freeze
  TYPE_PART_NUMBER = "Part Number".freeze
  TYPE_PO_NUMBER = "PO Number".freeze
  TYPE_SHIPMENT_NUMBER = "Shipment Reference Number".freeze
  TYPE_HOUSE_BILL = "House Bill Of Lading".freeze
  TYPE_MASTER_BILL = "Master Bill Of Lading".freeze
  TYPE_CONTAINER_NUMBER = "Container Number".freeze
  TYPE_INVOICE_NUMBER = "Invoice Number".freeze
  TYPE_SAP_NUMBER = "SAP Number".freeze
  TYPE_ISF_NUMBER = "ISF Host System File Number".freeze
  TYPE_DAILY_STATEMENT_NUMBER = "Daily Statement Number".freeze
  TYPE_MONTHLY_STATEMENT_NUMBER = "Monthly Statement Number".freeze
  TYPE_BROKER_REFERENCE = "Broker Reference".freeze
  TYPE_ENTRY_NUMBER = "Entry Number".freeze
  TYPE_IMPORT_COUNTRY = "Import Country".freeze
  TYPE_EVENT_TYPE = "Event Type".freeze
  TYPE_PARS_NUMBER = "PARS Number".freeze
  TYPE_ATTACHMENT_NAME = "Attachment Name".freeze
  TYPE_PAYMENT_REFERENCE_NUMBER = "Payment Reference Number".freeze
  TYPE_FILE_NUMBER = "File Number".freeze

  def self.translate_identifier id
    if id.is_a?(Symbol)
      id_name = "TYPE_#{id.to_s.upcase}"
      begin
        id = const_get(id_name)
      rescue NameError
        # This is raised by const_get if the constant doesn't exist...we're going to raise it out as an argument error
        raise ArgumentError, "InboundFileIdentifier::#{id_name} constant does not exist."
      end
    end

    id
  end
end
