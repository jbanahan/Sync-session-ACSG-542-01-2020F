class IntacctReceivableLine < ActiveRecord::Base
  belongs_to :intacct_receivable, :inverse_of => :intacct_receivable_lines
end