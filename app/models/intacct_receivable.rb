class IntacctReceivable < ActiveRecord::Base
  belongs_to :intacct_alliance_export, :inverse_of => :intacct_receivables
  has_many :intacct_receivable_lines, :dependent => :destroy

  SALES_INVOICE_TYPE ||= "Sales Invoice"
  CREDIT_INVOICE_TYPE ||= "Credit Note"

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
end