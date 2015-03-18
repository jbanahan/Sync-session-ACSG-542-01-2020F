require 'open_chain/model_field_definition/broker_invoice_field_definition'
require 'open_chain/model_field_definition/broker_invoice_line_field_definition'
require 'open_chain/model_field_definition/carton_set_field_definition'
require 'open_chain/model_field_definition/classification_field_definition'
require 'open_chain/model_field_definition/commercial_invoice_field_definition'
require 'open_chain/model_field_definition/commercial_invoice_line_field_definition'
require 'open_chain/model_field_definition/commercial_invoice_tariff_field_definition'
require 'open_chain/model_field_definition/company_field_definition'
require 'open_chain/model_field_definition/container_field_definition'
require 'open_chain/model_field_definition/delivery_field_definition'
require 'open_chain/model_field_definition/delivery_line_field_definition'
require 'open_chain/model_field_definition/entry_field_definition'
require 'open_chain/model_field_definition/official_tariff_field_definition'
require 'open_chain/model_field_definition/order_field_definition'
require 'open_chain/model_field_definition/order_line_field_definition'
require 'open_chain/model_field_definition/product_field_definition'
require 'open_chain/model_field_definition/sale_field_definition'
require 'open_chain/model_field_definition/sale_line_field_definition'
require 'open_chain/model_field_definition/security_filing_field_definition'
require 'open_chain/model_field_definition/security_filing_line_field_definition'
require 'open_chain/model_field_definition/shipment_field_definition'
require 'open_chain/model_field_definition/shipment_line_field_definition'
require 'open_chain/model_field_definition/tariff_field_definition'
require 'open_chain/model_field_definition/vendor_product_group_assignment_definition'

module OpenChain; module ModelFieldDefinition; module FullModelFieldDefinition
  include OpenChain::ModelFieldDefinition::BrokerInvoiceFieldDefinition
  include OpenChain::ModelFieldDefinition::BrokerInvoiceLineFieldDefinition
  include OpenChain::ModelFieldDefinition::CartonSetFieldDefinition
  include OpenChain::ModelFieldDefinition::ClassificationFieldDefinition
  include OpenChain::ModelFieldDefinition::CommercialInvoiceFieldDefinition
  include OpenChain::ModelFieldDefinition::CommercialInvoiceLineFieldDefinition
  include OpenChain::ModelFieldDefinition::CommercialInvoiceTariffFieldDefinition
  include OpenChain::ModelFieldDefinition::CompanyFieldDefinition
  include OpenChain::ModelFieldDefinition::ContainerFieldDefinition
  include OpenChain::ModelFieldDefinition::DeliveryFieldDefinition
  include OpenChain::ModelFieldDefinition::DeliveryLineFieldDefinition
  include OpenChain::ModelFieldDefinition::EntryFieldDefinition
  include OpenChain::ModelFieldDefinition::OfficialTariffFieldDefinition
  include OpenChain::ModelFieldDefinition::OrderFieldDefinition
  include OpenChain::ModelFieldDefinition::OrderLineFieldDefinition
  include OpenChain::ModelFieldDefinition::ProductFieldDefinition
  include OpenChain::ModelFieldDefinition::SaleFieldDefinition
  include OpenChain::ModelFieldDefinition::SaleLineFieldDefinition
  include OpenChain::ModelFieldDefinition::SecurityFilingFieldDefinition
  include OpenChain::ModelFieldDefinition::SecurityFilingLineFieldDefinition
  include OpenChain::ModelFieldDefinition::ShipmentFieldDefinition
  include OpenChain::ModelFieldDefinition::ShipmentLineFieldDefinition
  include OpenChain::ModelFieldDefinition::TariffFieldDefinition
  include OpenChain::ModelFieldDefinition::VendorProductGroupAssignmentDefinition

  def add_field_definitions
    add_company_fields
    add_entry_fields
    add_security_filing_line_fields
    add_security_filing_fields
    add_official_tariff_fields
    add_commercial_invoice_fields
    add_commercial_invoice_line_fields
    add_commercial_invoice_tariff_fields
    add_broker_invoice_fields
    add_broker_invoice_line_fields
    add_product_fields
    add_classification_fields
    add_tariff_fields
    add_order_fields
    add_order_line_fields
    add_shipment_fields
    add_shipment_line_fields
    add_container_fields
    add_carton_set_fields
    add_sale_fields
    add_sale_line_fields
    add_delivery_fields
    add_delivery_line_fields
    add_vendor_product_group_assignment_fields
  end
end; end; end
