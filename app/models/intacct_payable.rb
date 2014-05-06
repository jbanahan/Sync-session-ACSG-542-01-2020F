class IntacctPayable < ActiveRecord::Base
  belongs_to :intacct_alliance_export, :inverse_of => :intacct_payables
  has_many :intacct_payable_lines, :dependent => :destroy
end