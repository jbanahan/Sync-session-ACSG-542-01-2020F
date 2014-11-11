class IntacctAllianceExport < ActiveRecord::Base
  has_many :intacct_receivables, :dependent => :destroy
  has_many :intacct_payables, :dependent => :destroy
  has_many :intacct_checks, :dependent => :destroy

  EXPORT_TYPE_CHECK = 'check'
  EXPORT_TYPE_INVOICE = 'invoice'
end