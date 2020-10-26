# == Schema Information
#
# Table name: intacct_receivables
#
#  company                    :string(255)
#  created_at                 :datetime         not null
#  currency                   :string(255)
#  customer_number            :string(255)
#  customer_reference         :string(255)
#  id                         :integer          not null, primary key
#  intacct_alliance_export_id :integer
#  intacct_errors             :text(65535)
#  intacct_key                :string(255)
#  intacct_upload_date        :datetime
#  invoice_date               :date
#  invoice_number             :string(255)
#  lmd_identifier             :string(255)
#  receivable_type            :string(255)
#  shipment_customer_number   :string(255)
#  updated_at                 :datetime         not null
#
# Indexes
#
#  index_intacct_receivables_on_intacct_alliance_export_id         (intacct_alliance_export_id)
#  index_intacct_receivables_on_lmd_identifier                     (lmd_identifier)
#  intacct_recveivables_by_company_customer_number_invoice_number  (company,customer_number,invoice_number)
#

class IntacctReceivable < ActiveRecord::Base

  belongs_to :intacct_alliance_export, inverse_of: :intacct_receivables
  has_many :intacct_receivable_lines, dependent: :destroy

  SALES_INVOICE_TYPE ||= "Sales Invoice".freeze
  CREDIT_INVOICE_TYPE ||= "Credit Note".freeze

  def canada?
    ['als', 'vcu'].include? company
  end

  def self.credit_invoice? receivable
    receivable.receivable_type.to_s.include? CREDIT_INVOICE_TYPE
  end

  def self.create_receivable_type company, credit_invoice
    r_type = credit_invoice ? CREDIT_INVOICE_TYPE : SALES_INVOICE_TYPE

    case company.upcase
    when 'ALS'
      "ALS #{r_type}"
    when 'VCU'
      # Not a typo...the consultants doing work on Intacct transactions for us used VFC for VCU
      # rather than for the actual VFC company.
      "VFC #{r_type}"
    when 'VFC'
      "VFI #{r_type}"
    when "LMD"
      "LMD #{r_type}"
    else
      raise "Unknown Intacct company received: #{company}."
    end
  end

  def self.suggested_fix error
    return "" if error.blank?

    case error
    when /Description 2: Invalid Customer/i, /Description 2: Required field Date Due is missing/i
      "Create Customer account in Intacct and/or ensure account has payment Terms set."
    when /Description 2: Invalid Vendor '(.+)' specified./i
      "Create Vendor account #{Regexp.last_match(1)} in Intacct and/or ensure account has payment Terms set."
    when /The Date Due field is missing a value./i
      "Ensure the Vendor account in Intacct has valid payment Terms set."
    else
      # If there's only a single BL01001973 error with a "Description 2: Could not create Document record", then have the user attempt to clear and retry
      # otherwise, return an unknown error.
      # The missing end tag error occurs when there's some sort of Cloudflare issue and we get an HTML page back from Cloudflare,
      # rather than the expected XML.
      if (error.scan("BL01001973").size == 1 && error.scan("XL03000009").size == 1) || error =~ /Missing end tag for 'meta'/i
        "Temporary Upload Error. Click 'Clear This Error' link to try again."
      else
        "Unknown Error. Contact support@vandegriftinc.com to resolve error."
      end
    end
  end
end
