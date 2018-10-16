Dir[__dir__ + '/*'].each {|file| require file } #Require all files in this directory

module OpenChain; module ModelFieldDefinition; module FullModelFieldDefinition
  include OpenChain::ModelFieldDefinition::AddressFieldDefinition
  include OpenChain::ModelFieldDefinition::AttachmentFieldDefinition
  include OpenChain::ModelFieldDefinition::BookingLineFieldDefinition
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
  include OpenChain::ModelFieldDefinition::DrawbackClaimFieldDefinition
  include OpenChain::ModelFieldDefinition::EntryCommentFieldDefinition
  include OpenChain::ModelFieldDefinition::EntryFieldDefinition
  include OpenChain::ModelFieldDefinition::OfficialTariffFieldDefinition
  include OpenChain::ModelFieldDefinition::OrderFieldDefinition
  include OpenChain::ModelFieldDefinition::OrderLineFieldDefinition
  include OpenChain::ModelFieldDefinition::PlantFieldDefinition
  include OpenChain::ModelFieldDefinition::PlantProductGroupAssignmentFieldDefinition
  include OpenChain::ModelFieldDefinition::PlantVariantAssignmentFieldDefinition
  include OpenChain::ModelFieldDefinition::ProductFieldDefinition
  include OpenChain::ModelFieldDefinition::ProductRateOverrideFieldDefinition
  include OpenChain::ModelFieldDefinition::ProductVendorAssignmentFieldDefinition
  include OpenChain::ModelFieldDefinition::SaleFieldDefinition
  include OpenChain::ModelFieldDefinition::SaleLineFieldDefinition
  include OpenChain::ModelFieldDefinition::SecurityFilingFieldDefinition
  include OpenChain::ModelFieldDefinition::SecurityFilingLineFieldDefinition
  include OpenChain::ModelFieldDefinition::ShipmentFieldDefinition
  include OpenChain::ModelFieldDefinition::ShipmentLineFieldDefinition
  include OpenChain::ModelFieldDefinition::SummaryStatementFieldDefinition
  include OpenChain::ModelFieldDefinition::TariffFieldDefinition
  include OpenChain::ModelFieldDefinition::TppHtsOverrideFieldDefinition
  include OpenChain::ModelFieldDefinition::TradeLaneFieldDefinition
  include OpenChain::ModelFieldDefinition::TradePreferenceProgramFieldDefinition
  include OpenChain::ModelFieldDefinition::VariantFieldDefinition
  include OpenChain::ModelFieldDefinition::VfiInvoiceFieldDefinition
  include OpenChain::ModelFieldDefinition::VfiInvoiceLineFieldDefinition
  include OpenChain::ModelFieldDefinition::AttachmentFieldDefinition
  include OpenChain::ModelFieldDefinition::EntryCommentFieldDefinition
  include OpenChain::ModelFieldDefinition::CommercialInvoiceLaceyComponentFieldDefinition
  include OpenChain::ModelFieldDefinition::FolderFieldDefinition
  include OpenChain::ModelFieldDefinition::CommentFieldDefinition
  include OpenChain::ModelFieldDefinition::GroupFieldDefinition
  include OpenChain::ModelFieldDefinition::DailyStatementFieldDefinition
  include OpenChain::ModelFieldDefinition::DailyStatementEntryFieldDefinition
  include OpenChain::ModelFieldDefinition::DailyStatementEntryFeeFieldDefinition
  include OpenChain::ModelFieldDefinition::MonthlyStatementFieldDefinition
  include OpenChain::ModelFieldDefinition::RunAsSessionFieldDefinition
  include OpenChain::ModelFieldDefinition::InvoiceFieldDefinition
  include OpenChain::ModelFieldDefinition::InvoiceLineFieldDefinition
  include OpenChain::ModelFieldDefinition::UserFieldDefinition
  include OpenChain::ModelFieldDefinition::EventSubscriptionDefinition

  def add_field_definitions
    add_address_fields
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
    add_plant_variant_assignment_fields
    add_product_rate_override_fields
    add_product_vendor_assignment_fields
    add_drawback_claim_fields
    add_booking_line_fields
    add_variant_fields
    add_attachment_fields
    add_summary_statement_fields
    add_entry_comment_fields
    add_commercial_invoice_lacey_fields
    add_trade_lane_fields
    add_trade_preference_program_fields
    add_tpp_hts_override_fields
    add_folder_fields
    add_comment_fields
    add_group_fields
    add_vfi_invoice_fields
    add_vfi_invoice_line_fields
    add_daily_statement_fields
    add_daily_statement_entry_fields
    add_daily_statement_entry_fee_fields
    add_monthly_statement_fields
    add_run_as_session_fields
    add_invoice_fields
    add_invoice_line_fields
    add_user_fields
    add_event_subscription_fields
  end
end; end; end
