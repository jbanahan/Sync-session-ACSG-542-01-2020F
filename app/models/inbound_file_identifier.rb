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

class InboundFileIdentifier < ActiveRecord::Base
  belongs_to :inbound_file

  TYPE_ARTICLE_NUMBER = "Article Number"
  TYPE_PO_NUMBER = "PO Number"
  TYPE_SHIPMENT_NUMBER = "Shipment Reference Number"
  TYPE_INVOICE_NUMBER = "Invoice Number"
  TYPE_SAP_NUMBER = "SAP Number"
  TYPE_ISF_NUMBER = "ISF Host System File Number"
  TYPE_DAILY_STATEMENT_NUMBER = "Daily Statement Number"
  TYPE_MONTHLY_STATEMENT_NUMBER = "Monthly Statement Number"
end
