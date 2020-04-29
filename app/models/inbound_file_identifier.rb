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
#  index_inbound_file_identifiers_on_inbound_file_id  (inbound_file_id)
#

class InboundFileIdentifier < ActiveRecord::Base
  attr_accessible :identifier_type, :inbound_file_id, :module_id, :module_type, :value

  belongs_to :inbound_file, inverse_of: :identifiers

  TYPE_ARTICLE_NUMBER = "Article Number"
  TYPE_PO_NUMBER = "PO Number"
  TYPE_SHIPMENT_NUMBER = "Shipment Reference Number"
  TYPE_HOUSE_BILL = "House Bill Of Lading"
  TYPE_MASTER_BILL = "Master Bill Of Lading"
  TYPE_CONTAINER_NUMBER = "Container Number"
  TYPE_INVOICE_NUMBER = "Invoice Number"
  TYPE_SAP_NUMBER = "SAP Number"
  TYPE_ISF_NUMBER = "ISF Host System File Number"
  TYPE_DAILY_STATEMENT_NUMBER = "Daily Statement Number"
  TYPE_MONTHLY_STATEMENT_NUMBER = "Monthly Statement Number"
  TYPE_BROKER_REFERENCE = "Broker Reference"
  TYPE_ENTRY_NUMBER = "Entry Number"
  TYPE_IMPORT_COUNTRY = "Import Country"
  TYPE_EVENT_TYPE = "Event Type"
  TYPE_PARS_NUMBER = "PARS Number"
  TYPE_ATTACHMENT_NAME = "Attachment Name"

  def self.translate_identifier id
    if id.is_a?(Symbol)
      id_name = "TYPE_#{id.to_s.upcase}"
      begin
        id = const_get(id_name)
      rescue NameError => e
        # This is raised by const_get if the constant doesn't exist...we're going to raise it out as an argument error
        raise ArgumentError, "InboundFileIdentifier::#{id_name} constant does not exist."
      end
    end

    return id
  end
end
