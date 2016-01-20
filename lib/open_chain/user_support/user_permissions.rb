# permissions logic for User class
module OpenChain; module UserSupport; module UserPermissions
  def can_view?(user)
    return user.admin? || self==user
  end

  def can_edit?(user)
    return user.admin? || self==user
  end


  # Can the given user view items for the given module
  def view_module? core_module
    case core_module
    when CoreModule::ORDER
      return self.view_orders?
    when CoreModule::SHIPMENT
      return self.view_shipments?
    when CoreModule::PRODUCT
      return self.view_products?
    when CoreModule::SALE
      return self.view_sales_orders?
    when CoreModule::DELIVERY
      return self.view_deliveries?
    when CoreModule::ORDER_LINE
      return self.view_orders?
    when CoreModule::SHIPMENT_LINE
      return self.view_shipments?
    when CoreModule::DELIVERY_LINE
      return self.view_deliveries?
    when CoreModule::SALE_LINE
      return self.view_sales_orders?
    when CoreModule::TARIFF
      return self.view_products?
    when CoreModule::CLASSIFICATION
      return self.view_products?
    when CoreModule::OFFICIAL_TARIFF
      return self.view_official_tariffs?
    when CoreModule::ENTRY
      return self.view_entries?
    when CoreModule::BROKER_INVOICE
      return self.view_broker_invoices?
    when CoreModule::BROKER_INVOICE_LINE
      return self.view_broker_invoices?
    when CoreModule::COMMERCIAL_INVOICE
      return self.view_commercial_invoices?
    when CoreModule::COMMERCIAL_INVOICE_LINE
      return self.view_commercial_invoices?
    when CoreModule::COMMERCIAL_INVOICE_TARIFF
      return self.view_commercial_invoices?
    when CoreModule::SECURITY_FILING
      return self.view_security_filings?
    when CoreModule::COMPANY
      return self.view_vendors? || self.admin?
    when CoreModule::PLANT
      return self.view_module?(CoreModule::COMPANY)
    when CoreModule::PLANT_PRODUCT_GROUP_ASSIGNMENT
      return self.view_module?(CoreModule::PLANT)
    when CoreModule::DRAWBACK_CLAIM
      return self.view_drawback?
    when CoreModule::VARIANT
      return self.view_variants?
    end
    return false
  end

  #permissions
  def view_business_validation_results?
    self.company.master? || (self.company.importer? && self.company.show_business_rules?)
  end
  def edit_business_validation_results?
    self.view_business_validation_results?
  end
  def view_business_validation_rule_results?
    self.view_business_validation_results?
  end
  def edit_business_validation_rule_results?
    self.view_business_validation_results?
  end
  def view_official_tariffs?
    self.view_products? || self.company.master?
  end
  def view_attachment_archives?
    self.company.master? && self.view_entries?
  end
  def edit_attachment_archives?
    self.view_attachment_archives?
  end
  def view_security_filings?
    self.security_filing_view? && self.company.view_security_filings?
  end
  def edit_security_filings?
    self.security_filing_edit? && self.company.edit_security_filings?
  end
  def attach_security_filings?
    self.security_filing_attach? && self.company.attach_security_filings?
  end
  def comment_security_filings?
    self.security_filing_comment? && self.company.comment_security_filings?
  end
  def view_drawback?
    self.drawback_view? && MasterSetup.get.drawback_enabled?
  end
  def edit_drawback?
    self.drawback_edit? && MasterSetup.get.drawback_enabled?
  end
  def upload_drawback?
    self.edit_drawback? &&  self.company.master?
  end
  def view_commercial_invoices?
    self.commercial_invoice_view? && MasterSetup.get.entry_enabled?
  end
  def edit_commercial_invoices?
    self.commercial_invoice_edit? && MasterSetup.get.entry_enabled?
  end
  def view_surveys?
    self.survey_view?
  end
  def edit_surveys?
    self.survey_edit?
  end
  def view_broker_invoices?
    self.broker_invoice_view && self.company.view_broker_invoices?
  end
  def edit_broker_invoices?
    self.broker_invoice_edit && self.company.edit_broker_invoices?
  end
  def view_summary_statements?
    view_broker_invoices?
  end
  def edit_summary_statements?
    edit_broker_invoices?
  end
  def view_entries?
    self.entry_view? && self.company.view_entries?
  end
  def comment_entries?
    self.entry_comment? && self.company.view_entries?
  end
  def attach_entries?
    self.entry_attach? && self.company.view_entries?
  end
  def edit_entries?
    self.entry_edit? && self.company.broker?
  end
  def view_orders?
    self.order_view? && self.company.view_orders?
  end
  def add_orders?
    self.order_edit? && self.company.add_orders?
  end
  def edit_orders?
    self.order_edit? && self.company.edit_orders?
  end
  def delete_orders?
    self.order_delete? && self.company.delete_orders?
  end
  def attach_orders?
    self.order_attach? && self.company.attach_orders?
  end
  def comment_orders?
    self.order_comment? && self.company.comment_orders?
  end

  def view_products?
    self.product_view? && self.company.view_products?
  end
  def add_products?
    self.product_edit? && self.company.add_products?
  end
  def edit_products?
    self.product_edit? && self.company.edit_products?
  end
  def create_products?
    add_products?
  end
  def delete_products?
    self.product_delete? && self.company.delete_products?
  end
  def attach_products?
    self.product_attach? && self.company.attach_products?
  end
  def comment_products?
    self.product_comment? && self.company.comment_products?
  end

  def view_sales_orders?
    self.sales_order_view? && self.company.view_sales_orders?
  end
  def add_sales_orders?
    self.sales_order_edit? && self.company.add_sales_orders?
  end
  def edit_sales_orders?
    self.sales_order_edit? && self.company.edit_sales_orders?
  end
  def delete_sales_orders?
    self.sales_order_delete? && self.company.delete_sales_orders?
  end
  def attach_sales_orders?
    self.sales_order_attach? && self.company.attach_sales_orders?
  end
  def comment_sales_orders?
    self.sales_order_comment? && self.company.comment_sales_orders?
  end


  def view_shipments?
    self.shipment_view && self.company.view_shipments?
  end
  def add_shipments?
    self.shipment_edit? && self.company.add_shipments?
  end
  def edit_shipments?
    self.shipment_edit? && self.company.edit_shipments?
  end
  def delete_shipments?
    self.shipment_delete? && self.company.delete_shipments?
  end
  def comment_shipments?
    self.shipment_comment? && self.company.comment_shipments?
  end
  def attach_shipments?
    self.shipment_attach? && self.company.attach_shipments?
  end

  def view_deliveries?
    self.delivery_view? && self.company.view_deliveries?
  end
  def add_deliveries?
    self.delivery_edit? && self.company.add_deliveries?
  end
  def edit_deliveries?
    self.delivery_edit? && self.company.edit_deliveries?
  end
  def delete_deliveries?
    self.delivery_delete? && self.company.delete_deliveries?
  end
  def comment_deliveries?
    self.delivery_comment? && self.company.comment_deliveries?
  end
  def attach_deliveries?
    self.delivery_attach? && self.company.attach_deliveries?
  end

  def add_classifications?
    self.classification_edit? && self.company.add_classifications?
  end
  def edit_classifications?
    add_classifications?
  end

  def view_variants?
    self.view_products?
  end
  def add_variants?
    self.variant_edit? && self.company.add_variants?
  end
  def edit_variants?
    add_variants?
  end

  def view_projects?
    self.project_view && self.master_company?
  end
  def edit_projects?
    self.project_edit && self.master_company?
  end

  def view_vendors?
    self.vendor_view && master_setup.vendor_management_enabled?
  end
  def edit_vendors?
    self.vendor_edit && master_setup.vendor_management_enabled?
  end
  def create_vendors?
    self.edit_vendors?
  end
  def attach_vendors?
    self.vendor_attach && master_setup.vendor_management_enabled?
  end
  def comment_vendors?
    self.vendor_comment && master_setup.vendor_management_enabled?
  end

  def edit_milestone_plans?
    self.admin?
  end

  def edit_status_rules?
    self.admin?
  end

  def view_vendor_portal?
    self.order_view? && !User.where(portal_mode:'vendor').empty?
  end

end; end; end