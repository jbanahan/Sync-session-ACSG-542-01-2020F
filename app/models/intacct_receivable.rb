class IntacctReceivable < ActiveRecord::Base
  belongs_to :intacct_alliance_export, :inverse_of => :intacct_receivables
  has_many :intacct_receivable_lines, :dependent => :destroy

  SALES_INVOICE_TYPE ||= "Sales Invoice"
  CREDIT_INVOICE_TYPE ||= "Credit Note"

  def canada?
    ['als', 'vcu'].include? company
  end

  def self.create_receivable_type company, credit_invoice
    r_type = credit_invoice ? CREDIT_INVOICE_TYPE : SALES_INVOICE_TYPE

    case company.upcase
    when 'ALS'
      return "ALS #{r_type}"
    when 'VCU'
      # Not a typo...the consultants doing work on Intacct transactions for us used VFC for VCU 
      # rather than for the actual VFC company.  
      return "VFC #{r_type}"
    when 'VFC'
      return "VFI #{r_type}"
    when "LMD"
      return "LMD #{r_type}"
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
      "Create Vendor account #{$1} in Intacct and/or ensure account has payment Terms set."
    else
      # If there's only a single BL01001973 error with a "Description 2: Could not create Document record", then have the user attempt to clear and retry
      # otherwise, return an unknown error.
      if error.scan("BL01001973").size == 1 && error.scan("XL03000009").size == 1
        "Temporary Upload Error. Click 'Clear This Error' link to try again."
      else
        "Unknown Error. Contact support@vandegriftinc.com to resolve error."
      end
    end

  end
end