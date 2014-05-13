class IntacctPayableLine < ActiveRecord::Base
  belongs_to :intacct_payable, :inverse_of => :intacct_payable_lines
end