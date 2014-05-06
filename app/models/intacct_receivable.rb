class IntacctReceivable < ActiveRecord::Base
  belongs_to :intacct_alliance_export, :inverse_of => :intacct_receivables
  has_many :intacct_receivable_lines, :dependent => :destroy

  SALES_INVOICE_TYPE ||= "Sales Invoice"
  CREDIT_INVOICE_TYPE ||= "Sales Credit Memo"
end