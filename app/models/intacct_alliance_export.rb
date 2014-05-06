class IntacctAllianceExport < ActiveRecord::Base
  has_many :intacct_receivables, :dependent => :destroy
  has_many :intacct_payables, :dependent => :destroy
end