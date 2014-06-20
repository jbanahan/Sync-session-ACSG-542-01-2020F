class IntacctPayable < ActiveRecord::Base
  belongs_to :intacct_alliance_export, :inverse_of => :intacct_payables
  has_many :intacct_payable_lines, :dependent => :destroy

  PAYABLE_TYPE_BILL ||= 'bill'
  PAYABLE_TYPE_ADVANCED ||= 'advanced'
  PAYABLE_TYPE_CHECK ||= 'invoiced check'
end