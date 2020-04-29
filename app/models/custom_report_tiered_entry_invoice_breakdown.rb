# -*- SkipSchemaAnnotations

require 'custom_report_entry_invoice_breakdown_support'

class CustomReportTieredEntryInvoiceBreakdown < CustomReport
  include CustomReportEntryInvoiceBreakdownSupport

  attr_accessible :include_links, :name, :no_time, :type, :user_id

  # display name for report
  def self.template_name
    "Tiered Entry Summary Billing Breakdown"
  end

  # long description of report purpose / structure
  def self.description
    "Shows Broker Invoices with non-repeating entry header information and each charge in its own column."
  end

  # ModelFields available to be included on report as columns
  def self.column_fields_available user
    CoreModule::BROKER_INVOICE.model_fields(user).values
  end


  # ModelFields available to be used as SearchCriterions
  def self.criterion_fields_available user
    column_fields_available user
  end

  # can this user run the report
  def self.can_view? user
    user.view_broker_invoices?
  end

  def run run_by, row_limit = nil
    process run_by, row_limit, true
  end

end
