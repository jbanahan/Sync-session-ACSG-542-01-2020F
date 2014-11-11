class IntacctCheck < ActiveRecord::Base
  belongs_to :intacct_alliance_export, inverse_of: :intacct_checks
  belongs_to :intacct_check, inverse_of: :intacct_checks
end
