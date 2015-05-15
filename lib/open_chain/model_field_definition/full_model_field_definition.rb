Dir[__dir__ + '/*'].each {|file| require file } #Require all files in this directory

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
  include OpenChain::ModelFieldDefinition::PlantFieldDefinition
  include OpenChain::ModelFieldDefinition::PlantProductGroupAssignmentFieldDefinition
  include OpenChain::ModelFieldDefinition::ProductFieldDefinition
  include OpenChain::ModelFieldDefinition::SaleFieldDefinition
  include OpenChain::ModelFieldDefinition::SaleLineFieldDefinition
  include OpenChain::ModelFieldDefinition::SecurityFilingFieldDefinition
  include OpenChain::ModelFieldDefinition::SecurityFilingLineFieldDefinition
  include OpenChain::ModelFieldDefinition::ShipmentFieldDefinition
  include OpenChain::ModelFieldDefinition::ShipmentLineFieldDefinition
  include OpenChain::ModelFieldDefinition::TariffFieldDefinition
  include OpenChain::ModelFieldDefinition::DrawbackClaimFieldDefinition

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
    add_plant_fields
    add_plant_product_group_assignment_fields
    add_drawback_claim_fields
  end
end; end; end
