# == Schema Information
#
# Table name: custom_reports
#
#  id            :integer          not null, primary key
#  name          :string(255)
#  user_id       :integer
#  type          :string(255)
#  include_links :boolean
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  no_time       :boolean
#
# Indexes
#
#  index_custom_reports_on_type     (type)
#  index_custom_reports_on_user_id  (user_id)
#

require 'custom_report_entry_invoice_breakdown_support'

class CustomReportTieredEntryInvoiceBreakdown < CustomReport
  include CustomReportEntryInvoiceBreakdownSupport
  #display name for report
  def self.template_name
    "Tiered Entry Summary Billing Breakdown"
  end

  #long description of report purpose / structure
  def self.description
    "Shows Broker Invoices with non-repeating entry header information and each charge in its own column."
  end

  #ModelFields available to be included on report as columns
  def self.column_fields_available user
    CoreModule::BROKER_INVOICE.model_fields(user).values
  end


  #ModelFields available to be used as SearchCriterions
  def self.criterion_fields_available user
    column_fields_available user
  end

  #can this user run the report
  def self.can_view? user
    user.view_broker_invoices? 
  end

  def run run_by, row_limit = nil
    process run_by, row_limit, true
  end

end
